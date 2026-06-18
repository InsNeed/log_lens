import 'dart:async';

import 'package:loglens/loglens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsLoggerStore implements LoggerStore {
  static const String cfgKey = 'my_logger_config_v1';
  static const String logKey = 'my_logger_logs_v1';

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
    final list = _prefs?.getStringList(logKey) ?? <String>[];
    _cache
      ..clear()
      ..addAll(list);
    _cacheLoaded = true;
  }

  @override
  Future<void> saveConfig(LoggerConfig config) async {
    await _prefs?.setString(cfgKey, encodeLoggerConfig(config));
  }

  @override
  Future<LoggerConfig?> loadConfig() async {
    final jsonStr = _prefs?.getString(cfgKey);
    if (jsonStr == null) return null;
    return decodeLoggerConfig(jsonStr);
  }

  @override
  Future<void> append(LogEntry entry) async {
    if (!_cacheLoaded) {
      final list = _prefs?.getStringList(logKey) ?? <String>[];
      _cache
        ..clear()
        ..addAll(list);
      _cacheLoaded = true;
    }
    _cache.add(encodeLogEntry(entry));
    _scheduleFlush();
    return _pendingFlushCompleter?.future ?? Future.value();
  }

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async {
    if (!_cacheLoaded) {
      final list = _prefs?.getStringList(logKey) ?? <String>[];
      _cache
        ..clear()
        ..addAll(list);
      _cacheLoaded = true;
    }
    if (limit == null || _cache.length <= limit) {
      return _cache.map(decodeLogEntry).toList();
    }
    final start = _cache.length - limit;
    final tail = _cache.sublist(start);
    return tail.map(decodeLogEntry).toList();
  }

  @override
  Future<void> clear() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _cache.clear();
    _cacheLoaded = true;
    final c = _pendingFlushCompleter ??= Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      await _prefs?.remove(logKey);
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
      await _prefs?.setStringList(logKey, List<String>.unmodifiable(_cache));
      if (c != null && !c.isCompleted) c.complete();
    });
  }
}
