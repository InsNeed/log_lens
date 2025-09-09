import 'package:flutter/material.dart';

import '../config.dart';
import '../logger.dart';
import '../registry.dart';

class LogConsolePage extends StatefulWidget {
  const LogConsolePage({super.key});

  @override
  State<LogConsolePage> createState() => _LogConsolePageState();
}

class _LogConsolePageState extends State<LogConsolePage> {
  final List<LogEntry> _buffer = <LogEntry>[];
  static const int _maxBuffer = 500;
  bool _expanded = false;

  LoggerConfig? get _config => MyLogger.I.config;

  void _toggleModule(String moduleId, bool enabled) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() {
      cfg.setModuleAll(moduleId, enabled);
      MyLogger.I.updateConfig(cfg);
    });
  }

  Widget _buildModuleToggles() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        title: const Text('Modules'),
        subtitle: const Text('展开以切换模块激活状态'),
        children: [
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final m in LoggerRegistry.instance.modules)
                SwitchListTile(
                  title: Text(m.displayName),
                  value: _config?.isModuleEnabled(m.id) ?? false,
                  onChanged: (val) => _toggleModule(m.id, val),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEntry(LogEntry e) {
    final time = e.timestamp.toIso8601String().substring(11, 19);
    return '[$time] ${e.level.name.toUpperCase()} ${e.moduleId}/${e.layerId} ${e.fileName}: ${e.message}';
  }

  Color _levelColor(LogLevel level, BuildContext context) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _buffer.clear()),
            tooltip: '清空',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModuleToggles(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<LogEntry>(
              stream: MyLogger.I.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _buffer.add(snapshot.data!);
                  if (_buffer.length > _maxBuffer) {
                    _buffer.removeAt(0);
                  }
                }
                if (_buffer.isEmpty) {
                  return const Center(child: Text('暂无日志'));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: _buffer.length,
                  itemBuilder: (context, index) {
                    final entry = _buffer[_buffer.length - 1 - index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        _formatEntry(entry),
                        style: TextStyle(
                          color: _levelColor(entry.level, context),
                        ),
                      ),
                      subtitle:
                          (entry.error != null || entry.stackTrace != null)
                          ? Text(
                              '${entry.error ?? ''}\n${entry.stackTrace ?? ''}',
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
