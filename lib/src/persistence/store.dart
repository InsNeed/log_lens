import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../logger.dart';

abstract class LoggerStore {
  Future<void> init();
  Future<void> saveConfig(LoggerConfig config);
  Future<LoggerConfig?> loadConfig();

  Future<void> append(LogEntry entry);
  Future<List<LogEntry>> loadEntries({int? limit});
  Future<void> clear();
}

class SharedPrefsLoggerStore implements LoggerStore {
  static const String _cfgKey = 'my_logger_config_v1';
  static const String _logKey = 'my_logger_logs_v1';

  SharedPreferences? _prefs;
  Future<void> _writeQueue = Future.value();
  final List<String> _cache = <String>[];
  bool _cacheLoaded = false;
  Timer? _flushTimer;
  Completer<void>? _pendingFlushCompleter;
  static const Duration _flushDelay = Duration(milliseconds: 500);

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final list = _prefs?.getStringList(_logKey) ?? <String>[];
    _cache
      ..clear()
      ..addAll(list);
    _cacheLoaded = true;
  }

  @override
  Future<void> saveConfig(LoggerConfig config) async {
    await _prefs?.setString(_cfgKey, jsonEncode(config.toJson()));
  }

  @override
  Future<LoggerConfig?> loadConfig() async {
    final jsonStr = _prefs?.getString(_cfgKey);
    if (jsonStr == null) return null;
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return LoggerConfig.fromJson(map);
  }

  @override
  Future<void> append(LogEntry entry) async {
    if (!_cacheLoaded) {
      final list = _prefs?.getStringList(_logKey) ?? <String>[];
      _cache
        ..clear()
        ..addAll(list);
      _cacheLoaded = true;
    }
    _cache.add(_encodeEntry(entry));
    _scheduleFlush();
    return _pendingFlushCompleter?.future ?? Future.value();
  }

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async {
    if (!_cacheLoaded) {
      final list = _prefs?.getStringList(_logKey) ?? <String>[];
      _cache
        ..clear()
        ..addAll(list);
      _cacheLoaded = true;
    }
    if (limit == null || _cache.length <= limit) {
      return _cache.map(_decodeEntry).toList();
    }
    final start = _cache.length - limit;
    final tail = _cache.sublist(start);
    return tail.map(_decodeEntry).toList();
  }

  @override
  Future<void> clear() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _cache.clear();
    _cacheLoaded = true;
    final c = _pendingFlushCompleter ??= Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      await _prefs?.remove(_logKey);
      if (!c.isCompleted) c.complete();
      _pendingFlushCompleter = null;
    });
    return _writeQueue;
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, _flushNow);
    _pendingFlushCompleter ??= Completer<void>();
  }

  void _flushNow() {
    final c = _pendingFlushCompleter;
    _pendingFlushCompleter = null;
    _flushTimer = null;
    _writeQueue = _writeQueue.then((_) async {
      await _prefs?.setStringList(_logKey, List<String>.unmodifiable(_cache));
      if (c != null && !c.isCompleted) c.complete();
    });
  }

  String _encodeEntry(LogEntry e) => jsonEncode({
        'ts': e.timestamp.millisecondsSinceEpoch,
        'lvl': e.level.name,
        'mod': e.moduleId,
        'lay': e.layerId,
        'file': e.fileName,
        'msg': e.message?.toString(),
        'err': e.error?.toString(),
        'st': e.stackTrace?.toString(),
      });

  LogEntry _decodeEntry(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
      level: LogLevel.values.firstWhere((e) => e.name == (m['lvl'] as String)),
      moduleId: m['mod'] as String,
      layerId: m['lay'] as String,
      fileName: m['file'] as String,
      message: m['msg'],
      error: m['err'],
      stackTrace:
          m['st'] != null ? StackTrace.fromString(m['st'] as String) : null,
    );
  }
}

/// Function-based adapter for `LoggerStore`.
/// If a callback is not provided, the call falls back to the [fallback] store.
class FunctionLoggerStore implements LoggerStore {
  final Future<void> Function()? _onInit;
  final Future<void> Function(LoggerConfig config)? _onSaveConfig;
  final Future<LoggerConfig?> Function()? _onLoadConfig;
  final Future<void> Function(LogEntry entry)? _onAppend;
  final Future<List<LogEntry>> Function({int? limit})? _onLoadEntries;
  final Future<void> Function()? _onClear;

  final LoggerStore fallback;

  FunctionLoggerStore({
    Future<void> Function()? onInit,
    Future<void> Function(LoggerConfig config)? onSaveConfig,
    Future<LoggerConfig?> Function()? onLoadConfig,
    Future<void> Function(LogEntry entry)? onAppend,
    Future<List<LogEntry>> Function({int? limit})? onLoadEntries,
    Future<void> Function()? onClear,
    LoggerStore? fallback,
  })  : _onInit = onInit,
        _onSaveConfig = onSaveConfig,
        _onLoadConfig = onLoadConfig,
        _onAppend = onAppend,
        _onLoadEntries = onLoadEntries,
        _onClear = onClear,
        fallback = fallback ?? SharedPrefsLoggerStore();

  @override
  Future<void> init() async {
    await fallback.init();
    if (_onInit != null) {
      await _onInit!.call();
    }
  }

  @override
  Future<void> saveConfig(LoggerConfig config) async {
    if (_onSaveConfig != null) {
      return _onSaveConfig!(config);
    }
    return fallback.saveConfig(config);
  }

  @override
  Future<LoggerConfig?> loadConfig() async {
    if (_onLoadConfig != null) {
      return _onLoadConfig!.call();
    }
    return fallback.loadConfig();
  }

  @override
  Future<void> append(LogEntry entry) async {
    if (_onAppend != null) {
      return _onAppend!(entry);
    }
    return fallback.append(entry);
  }

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async {
    if (_onLoadEntries != null) {
      return _onLoadEntries!(limit: limit);
    }
    return fallback.loadEntries(limit: limit);
  }

  @override
  Future<void> clear() async {
    if (_onClear != null) {
      return _onClear!.call();
    }
    return fallback.clear();
  }
}

/// File-based rolling logger store using NDJSON lines.
/// - Config is still stored in SharedPreferences to keep compatibility
/// - Logs are appended to files under app documents directory: loglens/*.log
/// - Rolling by max file size and max files kept
class FileLoggerStore implements LoggerStore {
  static const String _cfgKey = 'my_logger_config_v1';
  static const String _dirName = 'loglens';
  static const String _filePrefix = 'logs_';
  static const String _fileExt = '.log';

  final Directory? _baseDirectory;
  final int _maxFileBytes; // per file size threshold
  final int _maxFiles; // number of files to retain
  final Duration _flushDelay;

  SharedPreferences? _prefs;
  Directory? _dir;
  IOSink? _sink;
  File? _currentFile;
  Timer? _flushTimer;
  Future<void> _writeQueue = Future.value();
  final List<String> _tailCache = <String>[]; // keep recent encodes in memory
  static const int _tailCacheLimit = 1000;

  FileLoggerStore({
    Directory? baseDirectory,
    int maxFileBytes = 1024 * 1024 * 2,
    int maxFiles = 5,
    Duration flushDelay = const Duration(milliseconds: 400),
  })  : _baseDirectory = baseDirectory,
        _maxFileBytes = maxFileBytes,
        _maxFiles = maxFiles,
        _flushDelay = flushDelay;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    await _prefs?.setString(_cfgKey, jsonEncode(config.toJson()));
  }

  @override
  Future<LoggerConfig?> loadConfig() async {
    final jsonStr = _prefs?.getString(_cfgKey);
    if (jsonStr == null) return null;
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return LoggerConfig.fromJson(map);
  }

  @override
  Future<void> append(LogEntry entry) async {
    final encoded = _encodeEntry(entry);
    _tailCache.add(encoded);
    if (_tailCache.length > _tailCacheLimit) {
      _tailCache.removeAt(0);
    }
    _writeQueue = _writeQueue.then((_) async {
      await _rotateIfNeeded(extraBytes: encoded.length + 1);
      _sink ??= _currentFile!.openWrite(mode: FileMode.append);
      _sink!.writeln(encoded);
      _scheduleFlush();
    });
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
      lines.insertAll(0, chunk); // prepend older
      remaining -= chunk.length;
    }
    if (limit != null && lines.length > limit) {
      lines.removeRange(0, lines.length - limit);
    }
    return lines.map(_decodeEntry).toList(growable: false);
  }

  @override
  Future<void> clear() async {
    // Close sink first
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    // Delete all files
    final files = await _listLogFilesSortedNewest();
    for (final f in files) {
      try {
        await f.delete();
      } catch (_) {}
    }
    _currentFile = await _ensureCurrentFile();
    _sink = _currentFile!.openWrite(mode: FileMode.append);
  }

  // Helpers
  String _encodeEntry(LogEntry e) => jsonEncode({
        'ts': e.timestamp.millisecondsSinceEpoch,
        'lvl': e.level.name,
        'mod': e.moduleId,
        'lay': e.layerId,
        'file': e.fileName,
        'msg': e.message?.toString(),
        'err': e.error?.toString(),
        'st': e.stackTrace?.toString(),
      });

  LogEntry _decodeEntry(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
      level: LogLevel.values.firstWhere((e) => e.name == (m['lvl'] as String)),
      moduleId: m['mod'] as String,
      layerId: m['lay'] as String,
      fileName: m['file'] as String,
      message: m['msg'],
      error: m['err'],
      stackTrace:
          m['st'] != null ? StackTrace.fromString(m['st'] as String) : null,
    );
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () async {
      try {
        await _sink?.flush();
      } catch (_) {}
    });
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
    // Fast path: if file is small, read all
    final size = await f.length();
    if (size < 64 * 1024) {
      final content = await f.readAsString();
      final lines = content.split('\n');
      if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
      if (lines.length <= maxLines) return lines;
      return lines.sublist(lines.length - maxLines);
    }
    // Heuristic: read last N bytes and split
    final int readBytes = 64 * 1024; // 64KB tail window
    final int start = (size - readBytes) > 0 ? (size - readBytes) : 0;
    final raf = await f.open();
    try {
      await raf.setPosition(start);
      final data = await raf.read(readBytes);
      final content = utf8.decode(data, allowMalformed: true);
      final lines = content.split('\n');
      if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
      if (lines.length <= maxLines) return lines;
      return lines.sublist(lines.length - maxLines);
    } finally {
      await raf.close();
    }
  }
}
