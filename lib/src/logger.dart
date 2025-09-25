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
      StreamController.broadcast();
  static LoggerConfig? _config;
  static LoggerStore? _store;

  static Stream<LogEntry> get stream => _controller.stream;
  static LoggerConfig? get config => _config;

  static Future<void> init({
    LoggerStore? store,
    LoggerConfig? config,
    List<Enum>? defaultModules,
    List<Enum>? defaultLayers,
  }) async {
    _store = store ?? SharedPrefsLoggerStore();
    await _store!.init();

    // default layers
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

    // default config: all enabled
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

  static Future<void> clearEntries() async {
    await _store?.clear();
  }

  static void registerLayer(String id, {String? displayName}) {
    LoggerRegistry.instance.registerLayer(id, displayName: displayName);
  }

  static void registerModule(String id, {String? displayName}) {
    LoggerRegistry.instance.registerModule(id, displayName: displayName);
  }

  static void d(String file, dynamic message, Enum module, Enum layer) {
    _log(LogLevel.debug, file, message, module.name, layer.name);
  }

  static void i(String file, dynamic message, Enum module, Enum layer) {
    _log(LogLevel.info, file, message, module.name, layer.name);
  }

  static void w(String file, dynamic message, Enum module, Enum layer) {
    _log(LogLevel.warning, file, message, module.name, layer.name);
  }

  static void e(
    String file,
    dynamic message,
    Enum module,
    Enum layer, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, file, message, module.name, layer.name, error,
        stackTrace);
  }

  static void _log(
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
