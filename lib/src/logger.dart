import 'dart:async';

import 'package:logger/logger.dart' as ext;

import 'caller.dart';
import 'config.dart';
import 'platform.dart';
import 'registry.dart';
import 'persistence/store.dart';

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String moduleId;
  final String layerId;
  final String fileName;
  final dynamic message;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.moduleId,
    required this.layerId,
    required this.fileName,
    required this.message,
    this.error,
    this.stackTrace,
  });
}

/// Snapshot of persisted log data and optional file-store metadata.
class LogStorageInfo {
  final String? directoryPath;
  final int fileCount;
  final int totalBytes;
  final List<LogEntry> entries;

  const LogStorageInfo({
    required this.directoryPath,
    required this.fileCount,
    required this.totalBytes,
    required this.entries,
  });
}

/// On-disk file counts for [FileLoggerStore].
class LogFileStorageStats {
  final int fileCount;
  final int totalBytes;

  const LogFileStorageStats({
    required this.fileCount,
    required this.totalBytes,
  });
}

class LogLens {
  LogLens._internal();
  static final LogLens _instance = LogLens._internal();
  static LogLens get I => _instance;

  static final ext.Logger _printer = ext.Logger(
    level: ext.Level.debug,
    printer: ext.PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 3,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  static final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();
  static LoggerConfig? _config;
  static LoggerStore? _store;
  static void Function(LogEntry)? _onLog;
  static bool _debugGuard = true;

  static Stream<LogEntry> get stream => _controller.stream;
  static LoggerConfig? get config => _config;
  static bool get debugGuard => _debugGuard;

  static Future<void> init({
    LoggerStore? store,
    LoggerConfig? config,
    List<Enum>? defaultModules,
    List<Enum>? defaultLayers,
    void Function(LogEntry)? onLog,
    /// When `true` (default), [LogLevel.debug] is skipped in release/product builds.
    bool debugGuard = true,
    /// Stack-frame substrings to skip when resolving the caller file name
    /// (e.g. app-level wrappers like `package:my_app/logging/app_logger.dart`).
    Iterable<String> skipCallerContains = const [],
    Future<void> Function()? onStoreInit,
    Future<void> Function(LoggerConfig config)? onStoreSaveConfig,
    Future<LoggerConfig?> Function()? onStoreLoadConfig,
    Future<void> Function(LogEntry entry)? onStoreAppend,
    Future<List<LogEntry>> Function({int? limit})? onStoreLoadEntries,
    Future<void> Function()? onStoreClear,
  }) async {
    _debugGuard = debugGuard;
    configureCallerSkipContains(skipCallerContains);
    final baseStore = store ?? FileLoggerStore();
    final hasCustomStoreFns = onStoreInit != null ||
        onStoreSaveConfig != null ||
        onStoreLoadConfig != null ||
        onStoreAppend != null ||
        onStoreLoadEntries != null ||
        onStoreClear != null;
    _store = hasCustomStoreFns
        ? FunctionLoggerStore(
            onInit: onStoreInit,
            onSaveConfig: onStoreSaveConfig,
            onLoadConfig: onStoreLoadConfig,
            onAppend: onStoreAppend,
            onLoadEntries: onStoreLoadEntries,
            onClear: onStoreClear,
            fallback: baseStore,
          )
        : baseStore;
    await _store!.init();
    _onLog = onLog;

    final reg = LoggerRegistry.instance;
    if (reg.layers.isEmpty) {
      if (defaultLayers != null && defaultLayers.isNotEmpty) {
        for (final e in defaultLayers) {
          reg.registerLayerEnum(e);
        }
      } else {
        for (final e in LoggerDefaultLayer.values) {
          reg.registerLayerEnum(e);
        }
      }
    }
    if (reg.modules.isEmpty) {
      if (defaultModules != null && defaultModules.isNotEmpty) {
        for (final e in defaultModules) {
          reg.registerModuleEnum(e);
        }
      } else {
        for (final e in LoggerDefaultModule.values) {
          reg.registerModuleEnum(e);
        }
      }
    }

    _config = config ??
        await _store!.loadConfig() ??
        LoggerConfig(defaultEnabled: true);
    await _store!.saveConfig(_config!);
  }

  static void updateConfig(LoggerConfig config) {
    _config = config;
    _store?.saveConfig(config);
  }

  static Future<List<LogEntry>> loadEntries({int? limit}) async {
    return await _store?.loadEntries(limit: limit) ?? <LogEntry>[];
  }

  /// Snapshot of persisted logs plus file-store stats when using [FileLoggerStore].
  static Future<LogStorageInfo> loadStorageInfo({int? limit}) async {
    await flush();
    final entries = await loadEntries(limit: limit);
    final fileStore = _resolveFileStore();
    if (fileStore == null) {
      return LogStorageInfo(
        directoryPath: null,
        fileCount: 0,
        totalBytes: 0,
        entries: entries,
      );
    }
    final stats = await fileStore.storageStats();
    return LogStorageInfo(
      directoryPath: fileStore.directoryPath,
      fileCount: stats.fileCount,
      totalBytes: stats.totalBytes,
      entries: entries,
    );
  }

  static FileLoggerStore? _resolveFileStore() {
    final store = _store;
    if (store is FileLoggerStore) return store;
    if (store is FunctionLoggerStore && store.fallback is FileLoggerStore) {
      return store.fallback as FileLoggerStore;
    }
    return null;
  }

  /// Permanently delete all persisted logs via [LoggerStore.clear]
  /// (for [FileLoggerStore], deletes rolling log files on disk).
  static Future<void> clearEntries() async {
    await _store?.clear();
  }

  /// Alias of [clearEntries] — deletes persisted log storage, not just the UI buffer.
  static Future<void> deleteAllLogs() => clearEntries();

  /// Drain pending store writes (e.g. before app pause / kill).
  static Future<void> flush() async {
    await _store?.flush();
  }

  static void registerLayer(String id, {String? displayName}) {
    LoggerRegistry.instance.registerLayer(id, displayName: displayName);
  }

  static void registerModule(String id, {String? displayName}) {
    LoggerRegistry.instance.registerModule(id, displayName: displayName);
  }

  static void d(dynamic message, Enum module, Enum layer) {
    _log(LogLevel.debug, message, module.name, layer.name);
  }

  static void i(dynamic message, Enum module, Enum layer) {
    _log(LogLevel.info, message, module.name, layer.name);
  }

  static void w(dynamic message, Enum module, Enum layer) {
    _log(LogLevel.warning, message, module.name, layer.name);
  }

  static void e(
    dynamic message,
    Enum module,
    Enum layer, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, message, module.name, layer.name, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    dynamic message,
    String moduleId,
    String layerId, [
    dynamic error,
    StackTrace? st,
  ]) {
    if (_debugGuard && kReleaseMode && level == LogLevel.debug) return;
    if (_config?.shouldShow(moduleId, layerId, level) != true) return;

    final file = parseCallerFileName();
    final formatted = '[$file] $message';
    switch (level) {
      case LogLevel.debug:
        _printer.d(formatted);
        break;
      case LogLevel.info:
        _printer.i(formatted);
        break;
      case LogLevel.warning:
        _printer.w(formatted);
        break;
      case LogLevel.error:
        _printer.e(formatted);
        if (error != null) _printer.e('Error: $error');
        if (st != null) _printer.e('StackTrace: $st');
        break;
    }
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      moduleId: moduleId,
      layerId: layerId,
      fileName: file,
      message: message,
      error: error,
      stackTrace: st,
    );
    try {
      _onLog?.call(entry);
    } catch (_) {}
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
    _store?.append(entry);
  }
}
