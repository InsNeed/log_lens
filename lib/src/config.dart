import 'registry.dart';

enum LogLevel { debug, info, warning, error }

class LoggerConfig {
  final Map<String, Map<String, Map<LogLevel, bool>>> _matrix = {};

  LoggerConfig({bool defaultEnabled = true}) {
    for (final m in LoggerRegistry.instance.modules) {
      _matrix[m.id] = {};
      for (final l in LoggerRegistry.instance.layers) {
        _matrix[m.id]![l.id] = {
          LogLevel.debug: defaultEnabled,
          LogLevel.info: defaultEnabled,
          LogLevel.warning: defaultEnabled,
          LogLevel.error: defaultEnabled,
        };
      }
    }
  }

  void set(String moduleId, String layerId, LogLevel level, bool enabled) {
    _matrix[moduleId]?[layerId]?[level] = enabled;
  }

  void setModuleAll(String moduleId, bool enabled) {
    for (final l in LoggerRegistry.instance.layers) {
      for (final level in LogLevel.values) {
        _matrix[moduleId]?[l.id]?[level] = enabled;
      }
    }
  }

  bool shouldShow(String moduleId, String layerId, LogLevel level) {
    return _matrix[moduleId]?[layerId]?[level] ?? false;
  }

  bool isModuleEnabled(String moduleId) {
    final layerMap = _matrix[moduleId];
    if (layerMap == null) return false;
    for (final levelMap in layerMap.values) {
      for (final enabled in levelMap.values) {
        if (enabled == true) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = {};
    _matrix.forEach((m, layers) {
      out[m] = layers.map(
        (l, levels) => MapEntry(l, levels.map((k, v) => MapEntry(k.name, v))),
      );
    });
    return out;
  }

  static LoggerConfig fromJson(Map<String, dynamic> json) {
    final cfg = LoggerConfig(defaultEnabled: false);
    json.forEach((m, layers) {
      (layers as Map).forEach((l, levels) {
        (levels as Map).forEach((lvl, enabled) {
          cfg.set(
            m as String,
            l as String,
            LogLevel.values.firstWhere((e) => e.name == lvl),
            enabled as bool,
          );
        });
      });
    });
    return cfg;
  }
}
