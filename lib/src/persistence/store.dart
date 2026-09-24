import 'dart:async';

import '../config.dart';
import '../logger.dart';

export 'file_logger_store_stub.dart'
    if (dart.library.io) 'file_logger_store_io.dart';

abstract class LoggerStore {
  Future<void> init();
  Future<void> saveConfig(LoggerConfig config);
  Future<LoggerConfig?> loadConfig();

  Future<void> append(LogEntry entry);
  Future<List<LogEntry>> loadEntries({int? limit});

  /// Permanently delete all persisted log entries (e.g. log files on disk).
  Future<void> clear();

  /// Drain pending writes and persist to durable storage.
  Future<void> flush();
}

/// Default in-memory store (tests / ephemeral use).
class InMemoryLoggerStore implements LoggerStore {
  LoggerConfig? _config;
  final List<LogEntry> _entries = <LogEntry>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> saveConfig(LoggerConfig config) async {
    _config = config;
  }

  @override
  Future<LoggerConfig?> loadConfig() async => _config;

  @override
  Future<void> append(LogEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async {
    if (limit == null || _entries.length <= limit) {
      return List<LogEntry>.unmodifiable(_entries);
    }
    return List<LogEntry>.unmodifiable(_entries.sublist(_entries.length - limit));
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<void> flush() async {}
}

/// Function-based adapter for [LoggerStore].
class FunctionLoggerStore implements LoggerStore {
  final Future<void> Function()? _onInit;
  final Future<void> Function(LoggerConfig config)? _onSaveConfig;
  final Future<LoggerConfig?> Function()? _onLoadConfig;
  final Future<void> Function(LogEntry entry)? _onAppend;
  final Future<List<LogEntry>> Function({int? limit})? _onLoadEntries;
  final Future<void> Function()? _onClear;
  final Future<void> Function()? _onFlush;

  final LoggerStore fallback;

  FunctionLoggerStore({
    Future<void> Function()? onInit,
    Future<void> Function(LoggerConfig config)? onSaveConfig,
    Future<LoggerConfig?> Function()? onLoadConfig,
    Future<void> Function(LogEntry entry)? onAppend,
    Future<List<LogEntry>> Function({int? limit})? onLoadEntries,
    Future<void> Function()? onClear,
    Future<void> Function()? onFlush,
    LoggerStore? fallback,
  })  : _onInit = onInit,
        _onSaveConfig = onSaveConfig,
        _onLoadConfig = onLoadConfig,
        _onAppend = onAppend,
        _onLoadEntries = onLoadEntries,
        _onClear = onClear,
        _onFlush = onFlush,
        fallback = fallback ?? InMemoryLoggerStore();

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

  @override
  Future<void> flush() async {
    if (_onFlush != null) {
      return _onFlush!.call();
    }
    return fallback.flush();
  }
}
