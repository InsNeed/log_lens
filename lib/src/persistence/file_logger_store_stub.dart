import '../config.dart';
import '../logger.dart';
import 'store.dart';

/// Web/unsupported platforms stub.
class FileLoggerStore implements LoggerStore {
  FileLoggerStore({
    Object? baseDirectory,
    String? basePath,
    int maxFileBytes = 1024 * 1024 * 5,
    int maxFiles = 10,
    Duration flushDelay = const Duration(milliseconds: 100),
  });

  Never _unsupported() =>
      throw UnsupportedError('FileLoggerStore requires dart:io');

  /// Always `null` on non-IO platforms.
  String? get directoryPath => null;

  /// Always empty stats on non-IO platforms.
  Future<LogFileStorageStats> storageStats() async =>
      const LogFileStorageStats(fileCount: 0, totalBytes: 0);

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

  @override
  Future<void> flush() async => _unsupported();
}
