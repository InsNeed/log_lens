import 'package:loglens/loglens.dart';
import 'package:path_provider/path_provider.dart';

/// Flutter-friendly bootstrap: persists under the app documents directory.
class LogLensFlutter {
  LogLensFlutter._();

  /// Resolves `documents/loglens` and calls [LogLens.init] with [FileLoggerStore].
  ///
  /// Pass [store] to override the default file store. Other parameters match
  /// [LogLens.init].
  static Future<void> init({
    LoggerStore? store,
    LoggerConfig? config,
    List<Enum>? defaultModules,
    List<Enum>? defaultLayers,
    void Function(LogEntry)? onLog,
    bool debugGuard = true,
    Iterable<String> skipCallerContains = const [],
    Future<void> Function()? onStoreInit,
    Future<void> Function(LoggerConfig config)? onStoreSaveConfig,
    Future<LoggerConfig?> Function()? onStoreLoadConfig,
    Future<void> Function(LogEntry entry)? onStoreAppend,
    Future<List<LogEntry>> Function({int? limit})? onStoreLoadEntries,
    Future<void> Function()? onStoreClear,
  }) async {
    LoggerStore? resolved = store;
    if (resolved == null) {
      final docs = await getApplicationDocumentsDirectory();
      resolved = FileLoggerStore(basePath: docs.path);
    }
    await LogLens.init(
      store: resolved,
      config: config,
      defaultModules: defaultModules,
      defaultLayers: defaultLayers,
      onLog: onLog,
      debugGuard: debugGuard,
      skipCallerContains: skipCallerContains,
      onStoreInit: onStoreInit,
      onStoreSaveConfig: onStoreSaveConfig,
      onStoreLoadConfig: onStoreLoadConfig,
      onStoreAppend: onStoreAppend,
      onStoreLoadEntries: onStoreLoadEntries,
      onStoreClear: onStoreClear,
    );
  }
}
