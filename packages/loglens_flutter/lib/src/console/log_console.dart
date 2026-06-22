import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loglens/loglens.dart';

import 'console_theme.dart';

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
      backgroundColor: ConsoleTheme.shell,
      appBar: AppBar(
        backgroundColor: ConsoleTheme.titleBar,
        foregroundColor: ConsoleTheme.textPrimary,
        elevation: 0,
        title: Text('loglens', style: ConsoleTheme.title),
      ),
      body: const Padding(
        padding: EdgeInsets.all(12),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          compact: compact,
          controller: _searchController,
          caseSensitive: _caseSensitive,
          hasQuery: _query.isNotEmpty,
          onChanged: (v) => setState(() => _query = v),
          onClear: () {
            setState(() {
              _query = '';
              _searchController.clear();
            });
          },
          onToggleCase: () => setState(() => _caseSensitive = !_caseSensitive),
        ),
        SizedBox(height: compact ? 6 : 8),
        Expanded(
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ConsoleTheme.surface,
                  borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
                  border: Border.all(color: ConsoleTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
                  child: FutureBuilder<void>(
                    future: _initialLoadFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Center(
                          child: Text(
                            'loading…',
                            style: ConsoleTheme.monoSm.copyWith(
                              color: ConsoleTheme.textMuted,
                            ),
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
                  child: _ScrollTailButton(
                    onPressed: () {
                      if (!_scrollController.hasClients) return;
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final bool compact;
  final TextEditingController controller;
  final bool caseSensitive;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onToggleCase;

  const _FilterBar({
    required this.compact,
    required this.controller,
    required this.caseSensitive,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
    required this.onToggleCase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 30 : 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ConsoleTheme.surface,
        borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
        border: Border.all(color: ConsoleTheme.border),
      ),
      child: Row(
        children: [
          Text(
            'grep',
            style: ConsoleTheme.monoSm.copyWith(
              color: ConsoleTheme.prompt,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            ' › ',
            style: ConsoleTheme.monoSm.copyWith(color: ConsoleTheme.textMuted),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: ConsoleTheme.monoSm.copyWith(color: ConsoleTheme.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'filter logs…',
                hintStyle: ConsoleTheme.monoSm.copyWith(
                  color: ConsoleTheme.textMuted,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
          if (hasQuery)
            _FilterIconButton(
              icon: Icons.close,
              tooltip: 'Clear',
              onTap: onClear,
            ),
          _FilterIconButton(
            icon: Icons.text_fields,
            tooltip: 'Case sensitive',
            active: caseSensitive,
            onTap: onToggleCase,
          ),
        ],
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _FilterIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: active ? ConsoleTheme.levelColor(LogLevel.info) : ConsoleTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ScrollTailButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScrollTailButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ConsoleTheme.surface,
      elevation: 2,
      shadowColor: ConsoleTheme.shadow,
      borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
            border: Border.all(color: ConsoleTheme.border),
          ),
          child: const Icon(
            Icons.south,
            size: 14,
            color: ConsoleTheme.textSecondary,
          ),
        ),
      ),
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
          '— no output —',
          style: ConsoleTheme.monoSm.copyWith(color: ConsoleTheme.textMuted),
        ),
      );
    }
    return RepaintBoundary(
      key: const ValueKey('log_list_boundary'),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 4),
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

  String _fullText() {
    final time = entry.timestamp.toIso8601String().substring(11, 19);
    final level = ConsoleTheme.levelLabel(entry.level);
    final header =
        '[$time] $level ${entry.moduleId}/${entry.layerId} ${entry.fileName}: ${entry.message}';
    if (entry.error == null && entry.stackTrace == null) return header;
    return '$header\n  Error: ${entry.error ?? ''}\n  ${entry.stackTrace ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final time = entry.timestamp.toIso8601String().substring(11, 19);
    final levelColor = ConsoleTheme.levelColor(entry.level);
    final levelLabel = ConsoleTheme.levelLabel(entry.level);
    final hasExtra = entry.error != null || entry.stackTrace != null;
    final fontSize = compact ? 10.0 : 11.0;
    final baseStyle = ConsoleTheme.mono.copyWith(
      color: ConsoleTheme.textPrimary,
      fontSize: fontSize,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Clipboard.setData(ClipboardData(text: _fullText())),
        hoverColor: ConsoleTheme.selection,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(
                      text: '$time ',
                      style: baseStyle.copyWith(color: ConsoleTheme.textMuted),
                    ),
                    TextSpan(
                      text: '$levelLabel ',
                      style: baseStyle.copyWith(
                        color: levelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '${entry.moduleId}/${entry.layerId} ',
                      style: baseStyle.copyWith(
                        color: ConsoleTheme.prompt,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '${entry.fileName}: ',
                      style: baseStyle.copyWith(
                        color: ConsoleTheme.textSecondary,
                      ),
                    ),
                    TextSpan(text: '${entry.message}'),
                  ],
                ),
              ),
              if (hasExtra) ...[
                if (entry.error != null)
                  SelectableText(
                    '  ! ${entry.error}',
                    style: baseStyle.copyWith(
                      color: ConsoleTheme.levelColor(LogLevel.error),
                    ),
                  ),
                if (entry.stackTrace != null)
                  SelectableText(
                    '  ${entry.stackTrace}',
                    style: baseStyle.copyWith(
                      color: ConsoleTheme.textSecondary,
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
