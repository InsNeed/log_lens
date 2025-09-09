import 'dart:convert';

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

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    final list = await _readList();
    list.add(_encodeEntry(entry));
    await _prefs?.setStringList(_logKey, list);
  }

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async {
    final list = await _readList();
    final decoded = list.map(_decodeEntry).toList();
    if (limit == null || decoded.length <= limit) return decoded;
    return decoded.sublist(decoded.length - limit);
  }

  @override
  Future<void> clear() async {
    await _prefs?.remove(_logKey);
  }

  Future<List<String>> _readList() async {
    return _prefs?.getStringList(_logKey) ?? <String>[];
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
