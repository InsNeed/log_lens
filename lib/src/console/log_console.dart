import 'package:flutter/material.dart';
import 'dart:async';

import '../config.dart';
import '../logger.dart';
import '../registry.dart';

class LogConsolePage extends StatelessWidget {
  const LogConsolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Console')),
      body: const Padding(
        padding: EdgeInsets.all(8.0),
        child: LogConsolePanel(),
      ),
    );
  }
}

/// Optimized, compact console panel suitable for embedding or overlay
class LogConsolePanel extends StatefulWidget {
  const LogConsolePanel({super.key});

  @override
  State<LogConsolePanel> createState() => _LogConsolePanelState();
}

class _LogConsolePanelState extends State<LogConsolePanel> {
  final List<LogEntry> _buffer = <LogEntry>[];
  static const int _maxBuffer = 500;
  bool _showModules = false;
  StreamSubscription<LogEntry>? _subscription;

  LoggerConfig? get _config => LogLens.config;

  void _toggleModuleAll(String moduleId, bool enabled) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() {
      cfg.setModuleAll(moduleId, enabled);
      LogLens.updateConfig(cfg);
    });
  }

  void _toggleModuleLevel(
      String moduleId, String layerId, LogLevel level, bool enabled) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() {
      cfg.set(moduleId, layerId, level, enabled);
      LogLens.updateConfig(cfg);
    });
  }

  Widget _buildModules() {
    final modules = LoggerRegistry.instance.modules;
    if (modules.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.4),
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        initiallyExpanded: _showModules,
        onExpansionChanged: (v) => setState(() => _showModules = v),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.only(bottom: 2),
        title: const Text('Modules',
            style: TextStyle(fontWeight: FontWeight.w600)),
        children: [
          SizedBox(
            height: 280,
            child: ListView.separated(
              itemBuilder: (context, idx) {
                final m = modules[idx];
                final enabled = _config?.isModuleEnabled(m.id) ?? false;
                return ExpansionTile(
                  shape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(m.displayName),
                  ),
                  leading: Switch(
                    value: enabled,
                    onChanged: (v) => _toggleModuleAll(m.id, v),
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, i) {
                        final layer = LoggerRegistry.instance.layers[i];
                        final layerEnabled =
                            _config?.isModuleLayerEnabled(m.id, layer.id) ??
                                false;
                        return ExpansionTile(
                          shape: const Border(),
                          tilePadding:
                              const EdgeInsets.only(left: 40, right: 8),
                          title: Text(layer.displayName),
                          leading: Switch(
                            value: layerEnabled,
                            onChanged: (v) {
                              final cfg = _config;
                              if (cfg == null) return;
                              setState(() {
                                cfg.setModuleLayerAll(m.id, layer.id, v);
                                LogLens.updateConfig(cfg);
                              });
                            },
                          ),
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, k) {
                                final lvl = LogLevel.values[k];
                                final checked =
                                    _config?.shouldShow(m.id, layer.id, lvl) ??
                                        false;
                                return SwitchListTile(
                                  dense: true,
                                  contentPadding:
                                      const EdgeInsets.only(left: 80, right: 8),
                                  title: Text(lvl.name),
                                  value: checked,
                                  onChanged: (v) => _toggleModuleLevel(
                                      m.id, layer.id, lvl, v),
                                );
                              },
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.08)),
                              itemCount: LogLevel.values.length,
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.12)),
                      itemCount: LoggerRegistry.instance.layers.length,
                    ),
                  ],
                );
              },
              separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.2)),
              itemCount: modules.length,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEntry(LogEntry e) {
    final time = e.timestamp.toIso8601String().substring(11, 19);
    return '[$time] ${e.level.name.toUpperCase()}  ${e.moduleId}/${e.layerId}  ${e.fileName}: ${e.message}';
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blueGrey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  void initState() {
    super.initState();
    _subscription = LogLens.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _buffer.add(e);
        if (_buffer.length > _maxBuffer) {
          _buffer.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(
      children: [
        // Header actions
        Row(
          children: [
            const Text('Logs', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _buffer.clear()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.4)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buffer.isEmpty
                ? const Center(child: Text('No logs'))
                : ListView.separated(
                    reverse: true,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _buffer.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color:
                            Theme.of(context).dividerColor.withOpacity(0.08)),
                    itemBuilder: (context, index) {
                      final entry = _buffer[_buffer.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatEntry(entry),
                              style: TextStyle(
                                color: _levelColor(entry.level),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                            if (entry.error != null || entry.stackTrace != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${entry.error ?? ''}\n${entry.stackTrace ?? ''}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    ));
  }
}
