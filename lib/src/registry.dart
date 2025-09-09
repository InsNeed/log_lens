class LayerDefinition {
  final String id;
  final String displayName;
  const LayerDefinition(this.id, this.displayName);
}

class ModuleDefinition {
  final String id;
  final String displayName;
  const ModuleDefinition(this.id, this.displayName);
}

/// Registry for dynamic modules and layers
class LoggerRegistry {
  LoggerRegistry._();
  static final LoggerRegistry _instance = LoggerRegistry._();
  static LoggerRegistry get instance => _instance;

  final Map<String, LayerDefinition> _layers = {};
  final Map<String, ModuleDefinition> _modules = {};

  List<LayerDefinition> get layers => _layers.values.toList(growable: false);
  List<ModuleDefinition> get modules => _modules.values.toList(growable: false);

  void registerLayer(String id, {String? displayName}) {
    _layers[id] = LayerDefinition(id, displayName ?? id);
  }

  void registerModule(String id, {String? displayName}) {
    _modules[id] = ModuleDefinition(id, displayName ?? id);
  }

  bool hasLayer(String id) => _layers.containsKey(id);
  bool hasModule(String id) => _modules.containsKey(id);
}
