import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../config.dart';
import '../logger.dart';
import '../registry.dart';

class LogConsolePanelController {
  VoidCallback? _clear;
  void _bindClear(VoidCallback fn) => _clear = fn;
  void clear() => _clear?.call();
}

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
  final LogConsolePanelController? controller;
  const LogConsolePanel({super.key, this.controller});

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

  Icon _levelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const Icon(Icons.bug_report, color: Colors.blueGrey, size: 14);
      case LogLevel.info:
        return const Icon(Icons.info, color: Colors.blue, size: 14);
      case LogLevel.warning:
        return const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 14);
      case LogLevel.error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 14);
    }
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
    // bind controller
    widget.controller?._bindClear(() async {
      await LogLens.clearEntries();
      if (!mounted) return;
      setState(() => _buffer.clear());
    });
    // load persisted
    () async {
      final persisted = await LogLens.loadEntries(limit: _maxBuffer);
      if (!mounted) return;
      setState(() {
        _buffer
          ..clear()
          ..addAll(persisted);
      });
    }();
    // live stream
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
        // Only list. Header moved to overlay top bar.
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
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No logs'),
                  ))
                : ListView.separated(
                    reverse: true,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _buffer.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor.withOpacity(0.2)),
                    itemBuilder: (context, index) {
                      final entry = _buffer[_buffer.length - 1 - index];
                      final textColor = _levelColor(entry.level);
                      final time =
                          entry.timestamp.toIso8601String().substring(11, 19);
                      final levelStr = entry.level.name.toUpperCase();
                      final header = '${entry.moduleId}  ${entry.layerId}';
                      final msg = '${entry.message}';
                      final footer = '${entry.fileName}  $time';
                      final fullText =
                          'Module: ${entry.moduleId}  Layer: ${entry.layerId}\n'
                                  'Level: $levelStr\n'
                                  'Message: ${entry.message}\n'
                                  'File: ${entry.fileName}  Time: $time' +
                              ((entry.error != null || entry.stackTrace != null)
                                  ? '\nError: ${entry.error ?? ''}\nStackTrace: ${entry.stackTrace ?? ''}'
                                  : '');
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _levelIcon(entry.level),
                                    ),
                                    SelectableText(
                                      header,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  msg,
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.insert_drive_file,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    SelectableText(
                                      entry.fileName,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.access_time,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    SelectableText(
                                      time,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                if (entry.error != null ||
                                    entry.stackTrace != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: SelectableText(
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
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: InkWell(
                              onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: fullText));
                              },
                              child: const Icon(Icons.copy, size: 10),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    ));
  }
}
