import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:loglens/loglens.dart';

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
  final bool compact;

  const LogConsolePanel({
    super.key,
    this.controller,
    this.compact = false,
  });

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
    final compact = widget.compact;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 4 : 8, 0, compact ? 4 : 8),
          child: SizedBox(
            height: compact ? 32 : null,
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: compact ? 16 : 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_query.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _query = '';
                            _searchController.clear();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.clear, size: compact ? 12 : 14),
                        ),
                      ),
                    InkWell(
                      onTap: () =>
                          setState(() => _caseSensitive = !_caseSensitive),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.text_fields,
                          size: compact ? 12 : 14,
                          color: _caseSensitive
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                hintText: 'Filter...',
                hintStyle: TextStyle(
                  fontSize: compact ? 12 : 14,
                  fontFamily: 'monospace',
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: compact ? 6 : 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(compact ? 4 : 8),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(compact ? 4 : 8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 4 : 8),
                  child: FutureBuilder<void>(
                    future: _initialLoadFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final entries = _applyFilter(_buffer);
                      return LogList(
                        entries: entries,
                        controller: _scrollController,
                        compact: compact,
                      );
                    },
                  ),
                ),
              ),
              if (_showScrollFab)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: FloatingActionButton.small(
                    heroTag: 'log_scroll_fab',
                    backgroundColor: const Color(0xFF404040),
                    foregroundColor: Colors.white70,
                    onPressed: () {
                      if (!_scrollController.hasClients) return;
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    },
                    child: const Icon(Icons.arrow_downward, size: 16),
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
  final bool compact;

  const LogList({
    super.key,
    required this.entries,
    this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No logs',
          style: TextStyle(
            color: Colors.white38,
            fontFamily: 'monospace',
            fontSize: compact ? 11 : 12,
          ),
        ),
      );
    }
    return RepaintBoundary(
      key: const ValueKey('log_list_boundary'),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[entries.length - 1 - index];
          return LogListItem(entry: entry, compact: compact);
        },
      ),
    );
  }
}

class LogListItem extends StatelessWidget {
  final LogEntry entry;
  final bool compact;

  const LogListItem({super.key, required this.entry, this.compact = false});

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    height: 1.35,
  );

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const Color(0xFF9E9E9E);
      case LogLevel.info:
        return const Color(0xFF4FC3F7);
      case LogLevel.warning:
        return const Color(0xFFFFB74D);
      case LogLevel.error:
        return const Color(0xFFEF5350);
    }
  }

  String _levelLabel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DBG';
      case LogLevel.info:
        return 'INF';
      case LogLevel.warning:
        return 'WRN';
      case LogLevel.error:
        return 'ERR';
    }
  }

  String _fullText() {
    final time = entry.timestamp.toIso8601String().substring(11, 19);
    final level = _levelLabel(entry.level);
    final header =
        '[$time] $level ${entry.moduleId}/${entry.layerId} ${entry.fileName}: ${entry.message}';
    if (entry.error == null && entry.stackTrace == null) return header;
    return '$header\n  Error: ${entry.error ?? ''}\n  ${entry.stackTrace ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final time = entry.timestamp.toIso8601String().substring(11, 19);
    final levelColor = _levelColor(entry.level);
    final levelLabel = _levelLabel(entry.level);
    final hasExtra = entry.error != null || entry.stackTrace != null;
    final fontSize = compact ? 10.5 : 11.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Clipboard.setData(ClipboardData(text: _fullText())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText.rich(
                TextSpan(
                  style: _mono.copyWith(color: const Color(0xFFB0BEC5), fontSize: fontSize),
                  children: [
                    TextSpan(text: '[$time] '),
                    TextSpan(
                      text: '$levelLabel ',
                      style: TextStyle(color: levelColor, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '${entry.moduleId}/${entry.layerId} ',
                      style: const TextStyle(color: Color(0xFF81C784)),
                    ),
                    TextSpan(
                      text: '${entry.fileName}: ',
                      style: const TextStyle(color: Color(0xFF78909C)),
                    ),
                    TextSpan(
                      text: '${entry.message}',
                      style: const TextStyle(color: Color(0xFFECEFF1)),
                    ),
                  ],
                ),
              ),
              if (hasExtra) ...[
                if (entry.error != null)
                  SelectableText(
                    '  ! ${entry.error}',
                    style: _mono.copyWith(
                      color: const Color(0xFFEF9A9A),
                      fontSize: fontSize,
                    ),
                  ),
                if (entry.stackTrace != null)
                  SelectableText(
                    '  ${entry.stackTrace}',
                    style: _mono.copyWith(
                      color: const Color(0xFF90A4AE),
                      fontSize: fontSize - 0.5,
                    ),
                    maxLines: compact ? 3 : 6,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
