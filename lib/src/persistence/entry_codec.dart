import 'dart:convert';

import '../config.dart';
import '../logger.dart';

String encodeLogEntry(LogEntry entry) => jsonEncode({
      'ts': entry.timestamp.millisecondsSinceEpoch,
      'lvl': entry.level.name,
      'mod': entry.moduleId,
      'lay': entry.layerId,
      'file': entry.fileName,
      'msg': entry.message?.toString(),
      'err': entry.error?.toString(),
      'st': entry.stackTrace?.toString(),
    });

LogEntry decodeLogEntry(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  return LogEntry(
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
    level: LogLevel.values.firstWhere((e) => e.name == (map['lvl'] as String)),
    moduleId: map['mod'] as String,
    layerId: map['lay'] as String,
    fileName: map['file'] as String,
    message: map['msg'],
    error: map['err'],
    stackTrace:
        map['st'] != null ? StackTrace.fromString(map['st'] as String) : null,
  );
}

String encodeLoggerConfig(LoggerConfig config) => jsonEncode(config.toJson());

LoggerConfig decodeLoggerConfig(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  return LoggerConfig.fromJson(map);
}
