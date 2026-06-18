import '../config.dart';
import '../logger.dart';
import 'store.dart';

/// Web/unsupported platforms stub.
class FileLoggerStore implements LoggerStore {
  FileLoggerStore({
    Object? baseDirectory,
    int maxFileBytes = 1024 * 1024 * 2,
    int maxFiles = 5,
    Duration flushDelay = const Duration(milliseconds: 400),
  });

  Never _unsupported() =>
      throw UnsupportedError('FileLoggerStore requires dart:io');

  @override
  Future<void> init() async => _unsupported();

  @override
  Future<void> saveConfig(LoggerConfig config) async => _unsupported();

  @override
  Future<LoggerConfig?> loadConfig() async => _unsupported();

  @override
  Future<void> append(LogEntry entry) async => _unsupported();

  @override
  Future<List<LogEntry>> loadEntries({int? limit}) async => _unsupported();

  @override
  Future<void> clear() async => _unsupported();
}
