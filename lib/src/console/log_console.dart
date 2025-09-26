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
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: LogConsolePanel(),
      ),
    );
  }
}

class LogConsolePanel extends StatefulWidget {
  final LogConsolePanelController? controller;
  const LogConsolePanel({super.key, this.controller});

  @override
  State<LogConsolePanel> createState() => _LogConsolePanelState();
}

class _LogConsolePanelState extends State<LogConsolePanel> {
  final List<LogEntry> _buffer = <LogEntry>[];
  static const int _maxBuffer = 500;
  StreamSubscription<LogEntry>? _subscription;
  late final Future<void> _initialLoadFuture;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _showScrollFab = false;
  bool _caseSensitive = false;

  LoggerConfig? get _config => LogLens.config;

  @override
  void initState() {
    super.initState();
    widget.controller?._bindClear(() async {
      await LogLens.clearEntries();
      if (!mounted) return;
      setState(() => _buffer.clear());
    });
    _initialLoadFuture = () async {
      final persisted = await LogLens.loadEntries(limit: _maxBuffer);
      _buffer
        ..clear()
        ..addAll(persisted);
    }();
    _subscription = LogLens.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _buffer.add(e);
        if (_buffer.length > _maxBuffer) {
          _buffer.removeAt(0);
        }
      });
    });
    _scrollController.addListener(_onScrollChange);
  }

  void _onScrollChange() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final off = _scrollController.offset;
    final shouldShow = off < (max - 24);
    if (shouldShow != _showScrollFab) {
      setState(() => _showScrollFab = shouldShow);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.removeListener(_onScrollChange);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> _applyFilter(List<LogEntry> list) {
    final raw = _query.trim();
    if (raw.isEmpty) return list;
    final q = _caseSensitive ? raw : raw.toLowerCase();
    bool contains(String src) =>
        _caseSensitive ? src.contains(q) : src.toLowerCase().contains(q);
    return list.where((e) {
      final level = e.level.name;
      return contains(e.moduleId) ||
          contains(e.layerId) ||
          contains(e.fileName) ||
          contains(e.message?.toString() ?? '') ||
          contains(level);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _query = '';
                            _searchController.clear();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.clear, size: 12),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () =>
                        setState(() => _caseSensitive = !_caseSensitive),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _caseSensitive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.text_fields,
                        size: 12,
                        color: _caseSensitive
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              hintText: 'Search logs...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                gapPadding: 2,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                gapPadding: 2,
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                gapPadding: 2,
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.4)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder<void>(
                    future: _initialLoadFuture,
                    builder: (context, snapshot) {
                      final bool loading =
                          snapshot.connectionState != ConnectionState.done;
                      if (loading) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator()));
                      }
                      final entries = _applyFilter(_buffer);
                      return LogList(
                          entries: entries, controller: _scrollController);
                    },
                  ),
                ),
              ),
              if (_showScrollFab)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      if (!_scrollController.hasClients) return;
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    },
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class LogList extends StatelessWidget {
  final List<LogEntry> entries;
  final ScrollController? controller;
  const LogList({super.key, required this.entries, this.controller});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
          child: Padding(padding: EdgeInsets.all(16), child: Text('No logs')));
    }
    final Color dividerColor = Theme.of(context).dividerColor.withOpacity(0.2);
    return RepaintBoundary(
      key: const ValueKey('log_list_boundary'),
      child: ListView.builder(
        controller: controller,
        // reverse: true,
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[entries.length - 1 - index];
          return Column(
            children: [
              LogListItem(entry: entry),
              Container(height: 1, color: dividerColor),
            ],
          );
        },
      ),
    );
  }
}

class LogListItem extends StatelessWidget {
  final LogEntry entry;
  const LogListItem({super.key, required this.entry});

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
  Widget build(BuildContext context) {
    final Color textColor = _levelColor(entry.level);
    final String time = entry.timestamp.toIso8601String().substring(11, 19);
    final String levelStr = entry.level.name.toUpperCase();
    final String header = '${entry.moduleId}  ${entry.layerId}';
    final String msg = '${entry.message}';
    final String fullText =
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
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
              if (entry.error != null || entry.stackTrace != null)
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
              await Clipboard.setData(ClipboardData(text: fullText));
            },
            child: const Icon(Icons.copy, size: 10),
          ),
        ),
      ],
    );
  }
}
