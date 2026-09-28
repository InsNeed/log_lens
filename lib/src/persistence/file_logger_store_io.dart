import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import '../logger.dart';
import 'entry_codec.dart';
import 'store.dart';

/// File-based rolling logger store using NDJSON lines.
class FileLoggerStore implements LoggerStore {
  static const String _dirName = 'loglens';
  static const String _filePrefix = 'logs_';
  static const String _fileExt = '.log';
  static const String _configFileName = 'config.json';

  final Directory? _baseDirectory;
  final int _maxFileBytes;
  final int _maxFiles;
  final Duration _flushDelay;

  Directory? _dir;
  IOSink? _sink;
  File? _currentFile;
  Timer? _flushTimer;
  Future<void> _writeQueue = Future.value();
  final List<String> _tailCache = <String>[];
  static const int _tailCacheLimit = 1000;

  FileLoggerStore({
    Directory? baseDirectory,
    String? basePath,
    int maxFileBytes = 1024 * 1024 * 5,
    int maxFiles = 10,
    Duration flushDelay = const Duration(milliseconds: 100),
  })  : _baseDirectory = baseDirectory ??
            (basePath != null ? Directory(basePath) : null),
        _maxFileBytes = maxFileBytes,
        _maxFiles = maxFiles,
        _flushDelay = flushDelay;

  File get _configFile => File('${_dir!.path}/$_configFileName');

  /// Absolute path of the `loglens` store directory after [init], else `null`.
  String? get directoryPath => _dir?.path;

  /// Counts rolling log files and their total size on disk.
  Future<LogFileStorageStats> storageStats() async {
    final files = await _listLogFilesSortedNewest();
    int total = 0;
    for (final f in files) {
      try {
        total += await f.length();
      } catch (_) {}
    }
    return LogFileStorageStats(fileCount: files.length, totalBytes: total);
  }

  @override
  Future<void> init() async {
    final Directory baseDir = _baseDirectory ?? Directory.systemTemp;
    _dir = Directory('${baseDir.path}/$_dirName');
    if (!(await _dir!.exists())) {
      await _dir!.create(recursive: true);
    }
    await _rotateIfNeeded();
    _sink ??= _currentFile!.openWrite(mode: FileMode.append);
  }

  @override
  Future<void> saveConfig(LoggerConfig config) async {
    await _configFile.writeAsString(encodeLoggerConfig(config));
  }

  @override
  Future<LoggerConfig?> loadConfig() async {
    if (!await _configFile.exists()) return null;
    final raw = await _configFile.readAsString();
    if (raw.isEmpty) return null;
    return decodeLoggerConfig(raw);
  }

  @override
  Future<void> append(LogEntry entry) async {
    final encoded = encodeLogEntry(entry);
    _tailCache.add(encoded);
    if (_tailCache.length > _tailCacheLimit) {
      _tailCache.removeAt(0);
    }
    return _enqueue(() async {
      await _rotateIfNeeded(extraBytes: encoded.length + 1);
      _sink ??= _currentFile!.openWrite(mode: FileMode.append);
      _sink!.writeln(encoded);
      _scheduleFlush();
    });
  }

  /// Serializes all sink access (an [IOSink] rejects writes while flushing).
  /// A failed operation must not wedge the queue for later writes.
  Future<void> _enqueue(Future<void> Function() op) {
    _writeQueue = _writeQueue.then((_) => op()).catchError((Object _) {});
    return _writeQueue;
  }

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async {
    final files = await _listLogFilesSortedNewest();
    final int need = limit ?? 1 << 30;
    final List<String> lines = <String>[];
    int remaining = need;

    for (final f in files) {
      if (remaining <= 0) break;
      final chunk = await _readLastLines(f, remaining);
      lines.insertAll(0, chunk);
      remaining -= chunk.length;
    }
    if (limit != null && lines.length > limit) {
      lines.removeRange(0, lines.length - limit);
    }
    final entries = <LogEntry>[];
    for (final line in lines) {
      // Skip lines torn by a crash or a write still in flight.
      try {
        entries.add(decodeLogEntry(line));
      } catch (_) {}
    }
    return entries;
  }

  @override
  Future<void> clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _tailCache.clear();
    // Queued so earlier appends land first and later ones go to the new file.
    return _enqueue(() async {
      try {
        await _sink?.flush();
      } catch (_) {}
      try {
        await _sink?.close();
      } catch (_) {}
      _sink = null;
      _currentFile = null;

      final files = await _listLogFilesSortedNewest();
      for (final f in files) {
        try {
          await f.delete();
        } catch (_) {}
      }

      _currentFile = await _createNewFile();
      _sink = _currentFile!.openWrite(mode: FileMode.append);
    });
  }

  @override
  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    return _enqueue(_flushSink);
  }

  Future<void> _flushSink() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () => _enqueue(_flushSink));
  }

  Future<void> _rotateIfNeeded({int extraBytes = 0}) async {
    _currentFile ??= await _ensureCurrentFile();
    final len = await _currentFile!.length();
    if (len + extraBytes > _maxFileBytes) {
      await _sink?.flush();
      await _sink?.close();
      _sink = null;
      _currentFile = await _createNewFile();
      await _trimOldFiles();
    }
  }

  Future<File> _ensureCurrentFile() async {
    final files = await _listLogFilesSortedNewest();
    if (files.isNotEmpty) return files.first;
    return _createNewFile();
  }

  Future<File> _createNewFile() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${_dir!.path}/$_filePrefix$ts$_fileExt';
    final f = File(path);
    await f.create(recursive: true);
    return f;
  }

  Future<void> _trimOldFiles() async {
    final files = await _listLogFilesSortedNewest();
    if (files.length <= _maxFiles) return;
    for (int i = _maxFiles; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {}
    }
  }

  Future<List<File>> _listLogFilesSortedNewest() async {
    if (_dir == null) return <File>[];
    final all = await _dir!.list().toList();
    final files = all
        .whereType<File>()
        .where((f) => f.path.endsWith(_fileExt) && f.path.contains(_filePrefix))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<List<String>> _readLastLines(File f, int maxLines) async {
    final size = await f.length();
    if (size == 0 || maxLines <= 0) return <String>[];
    const int chunkSize = 64 * 1024;
    final raf = await f.open();
    try {
      final chunks = <List<int>>[];
      int start = size;
      int newlines = 0;
      while (start > 0 && newlines <= maxLines) {
        final readStart = start > chunkSize ? start - chunkSize : 0;
        await raf.setPosition(readStart);
        final data = await raf.read(start - readStart);
        chunks.insert(0, data);
        for (final b in data) {
          if (b == 0x0A) newlines++;
        }
        start = readStart;
      }
      final bytes = <int>[for (final c in chunks) ...c];
      final lines = utf8.decode(bytes, allowMalformed: true).split('\n');
      // Reading from mid-file: the first line is a partial record.
      if (start > 0 && lines.isNotEmpty) lines.removeAt(0);
      lines.removeWhere((l) => l.isEmpty);
      if (lines.length <= maxLines) return lines;
      return lines.sublist(lines.length - maxLines);
    } finally {
      await raf.close();
    }
  }
}
