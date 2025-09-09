import 'dart:async';

import 'package:logger/logger.dart' as ext;

import 'config.dart';
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

class MyLogger {
  MyLogger._internal();
  static final MyLogger _instance = MyLogger._internal();
  static MyLogger get I => _instance;

  late final ext.Logger _printer = ext.Logger(
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

  final StreamController<LogEntry> _controller = StreamController.broadcast();
  LoggerConfig? _config;
  LoggerStore? _store;

  Stream<LogEntry> get stream => _controller.stream;
  LoggerConfig? get config => _config;

  Future<void> init({LoggerStore? store, LoggerConfig? config}) async {
    _store = store ?? SharedPrefsLoggerStore();
    await _store!.init();

    // default layers
    final reg = LoggerRegistry.instance;
    if (reg.layers.isEmpty) {
      for (final l in const [
        'ui',
        'viewModel',
        'repo',
        'dataSource',
        'service',
        'temp',
        'util',
      ]) {
        reg.registerLayer(l);
      }
    }
    if (reg.modules.isEmpty) {
      reg.registerModule('test');
    }

    // default config: all enabled
    _config =
        config ??
        await _store!.loadConfig() ??
        LoggerConfig(defaultEnabled: true);
    await _store!.saveConfig(_config!);
  }

  void updateConfig(LoggerConfig config) {
    _config = config;
    _store?.saveConfig(config);
  }

  void registerLayer(String id, {String? displayName}) {
    LoggerRegistry.instance.registerLayer(id, displayName: displayName);
    // expand matrix lazily on next new config creation; keep current config as-is
  }

  void registerModule(String id, {String? displayName}) {
    LoggerRegistry.instance.registerModule(id, displayName: displayName);
  }

  void d(String file, dynamic message, String moduleId, String layerId) {
    _log(LogLevel.debug, file, message, moduleId, layerId);
  }

  void i(String file, dynamic message, String moduleId, String layerId) {
    _log(LogLevel.info, file, message, moduleId, layerId);
  }

  void w(String file, dynamic message, String moduleId, String layerId) {
    _log(LogLevel.warning, file, message, moduleId, layerId);
  }

  void e(
    String file,
    dynamic message,
    String moduleId,
    String layerId, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, file, message, moduleId, layerId, error, stackTrace);
  }

  void _log(
    LogLevel level,
    String file,
    dynamic message,
    String moduleId,
    String layerId, [
    dynamic error,
    StackTrace? st,
  ]) {
    if (_config?.shouldShow(moduleId, layerId, level) != true) return;
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
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
    _store?.append(entry);
  }
}
