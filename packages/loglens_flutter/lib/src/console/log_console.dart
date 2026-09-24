import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loglens/loglens.dart';

import 'console_theme.dart';

class LogConsolePanelController {
  VoidCallback? _clear;
  void _bindClear(VoidCallback fn) => _clear = fn;

  /// Clears the in-memory console buffer only (does not delete persisted files).
  void clear() => _clear?.call();
}

class LogConsolePage extends StatefulWidget {
  const LogConsolePage({super.key});

  @override
  State<LogConsolePage> createState() => _LogConsolePageState();
}

class _LogConsolePageState extends State<LogConsolePage> {
  final LogConsolePanelController _controller = LogConsolePanelController();
  final FocusNode _filterFocus = FocusNode();

  @override
  void dispose() {
    _filterFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConsoleTheme.shell,
      appBar: AppBar(
        backgroundColor: ConsoleTheme.titleBar,
        foregroundColor: ConsoleTheme.textPrimary,
        elevation: 0,
        title: Text('loglens', style: ConsoleTheme.title),
        actions: [
          IconButton(
            tooltip: 'Focus filter',
            icon: const Icon(Icons.filter_alt_outlined, size: 20),
            onPressed: () => _filterFocus.requestFocus(),
          ),
          IconButton(
            tooltip: 'Clear console',
            icon: const Icon(Icons.clear_all, size: 20),
            onPressed: () => _controller.clear(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LogConsolePanel(
          controller: _controller,
          filterFocusNode: _filterFocus,
        ),
      ),
    );
  }
}

class LogConsolePanel extends StatefulWidget {
  final LogConsolePanelController? controller;
  final bool compact;
  final FocusNode? filterFocusNode;

  const LogConsolePanel({
    super.key,
    this.controller,
    this.compact = false,
    this.filterFocusNode,
  });

  @override
  State<LogConsolePanel> createState() => _LogConsolePanelState();
}

class _LogConsolePanelState extends State<LogConsolePanel> {
  final List<LogEntry> _buffer = <LogEntry>[];
  static const int _maxBuffer = 1000;
  StreamSubscription<LogEntry>? _subscription;
  late final Future<void> _initialLoadFuture;
  bool _hydrating = true;
  final List<LogEntry> _liveDuringLoad = <LogEntry>[];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _showScrollFab = false;
  bool _caseSensitive = false;
  /// UI-only: hide list without stopping LogLens writes / stream.
  bool _displayEnabled = true;

  @override
  void initState() {
    super.initState();
    widget.controller?._bindClear(() {
      setState(() => _buffer.clear());
    });
    _subscription = LogLens.stream.listen((e) {
      if (!mounted) return;
      if (_hydrating) {
        _liveDuringLoad.add(e);
        return;
      }
      setState(() {
        _buffer.add(e);
        if (_buffer.length > _maxBuffer) {
          _buffer.removeAt(0);
        }
      });
    });
    _initialLoadFuture = () async {
      final persisted = await LogLens.loadEntries(limit: _maxBuffer);
      if (!mounted) return;
      setState(() {
        final merged = _mergeHistoryAndLive(persisted, _liveDuringLoad);
        _liveDuringLoad.clear();
        _hydrating = false;
        _buffer
          ..clear()
          ..addAll(merged);
        while (_buffer.length > _maxBuffer) {
          _buffer.removeAt(0);
        }
      });
    }();
    _scrollController.addListener(_onScrollChange);
  }

  /// Prefer persisted history, then append live entries not already present.
  static List<LogEntry> _mergeHistoryAndLive(
    List<LogEntry> persisted,
    List<LogEntry> live,
  ) {
    final out = List<LogEntry>.from(persisted);
    for (final e in live) {
      if (!_containsEntry(out, e)) {
        out.add(e);
      }
    }
    return out;
  }

  static bool _containsEntry(List<LogEntry> list, LogEntry e) {
    for (final p in list) {
      if (p.timestamp == e.timestamp &&
          p.level == e.level &&
          p.moduleId == e.moduleId &&
          p.layerId == e.layerId &&
          p.message?.toString() == e.message?.toString()) {
        return true;
      }
    }
    return false;
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

  void _toggleDisplay() {
    setState(() => _displayEnabled = !_displayEnabled);
  }

  void _copyAllLogs() {
    if (_buffer.isEmpty) {
      Clipboard.setData(const ClipboardData(text: ''));
      return;
    }
    final text = _buffer.map(formatLogEntryText).join('\n');
    Clipboard.setData(ClipboardData(text: text));
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
          focusNode: widget.filterFocusNode,
          caseSensitive: _caseSensitive,
          hasQuery: _query.isNotEmpty,
          displayEnabled: _displayEnabled,
          showClear: !compact,
          onChanged: (v) => setState(() => _query = v),
          onClearFilter: () {
            setState(() {
              _query = '';
              _searchController.clear();
            });
          },
          onToggleCase: () => setState(() => _caseSensitive = !_caseSensitive),
          onToggleDisplay: _toggleDisplay,
          onClearConsole: () => widget.controller?.clear(),
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
                      if (!_displayEnabled) {
                        return Center(
                          child: Text(
                            '— display paused —',
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
              Positioned(
                right: 8,
                top: 8,
                child: _MiniIconButton(
                  tooltip: 'Copy all logs',
                  icon: Icons.copy_outlined,
                  onPressed: _copyAllLogs,
                ),
              ),
              if (_displayEnabled && _showScrollFab)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _MiniIconButton(
                    tooltip: 'Scroll to latest',
                    icon: Icons.south,
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
  final FocusNode? focusNode;
  final bool caseSensitive;
  final bool hasQuery;
  final bool displayEnabled;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearFilter;
  final VoidCallback onToggleCase;
  final VoidCallback onToggleDisplay;
  final VoidCallback? onClearConsole;

  const _FilterBar({
    required this.compact,
    required this.controller,
    this.focusNode,
    required this.caseSensitive,
    required this.hasQuery,
    required this.displayEnabled,
    required this.showClear,
    required this.onChanged,
    required this.onClearFilter,
    required this.onToggleCase,
    required this.onToggleDisplay,
    this.onClearConsole,
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
              focusNode: focusNode,
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
              tooltip: 'Clear filter',
              onTap: onClearFilter,
            ),
          _FilterIconButton(
            icon: Icons.text_fields,
            tooltip: 'Case sensitive',
            active: caseSensitive,
            onTap: onToggleCase,
          ),
          _FilterIconButton(
            icon: displayEnabled
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tooltip: displayEnabled ? 'Hide log list' : 'Show log list',
            active: displayEnabled,
            onTap: onToggleDisplay,
          ),
          if (showClear && onClearConsole != null)
            _FilterIconButton(
              icon: Icons.clear_all,
              tooltip: 'Clear console',
              onTap: onClearConsole!,
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

class _MiniIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

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
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
              border: Border.all(color: ConsoleTheme.border),
            ),
            child: Icon(
              icon,
              size: 14,
              color: ConsoleTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

String formatLogEntryText(LogEntry entry) {
  final time = entry.timestamp.toIso8601String().substring(11, 19);
  final level = ConsoleTheme.levelLabel(entry.level);
  final header =
      '[$time] $level ${entry.moduleId}/${entry.layerId} ${entry.fileName}: ${entry.message}';
  if (entry.error == null && entry.stackTrace == null) return header;
  return '$header\n  Error: ${entry.error ?? ''}\n  ${entry.stackTrace ?? ''}';
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
        onTap: () => Clipboard.setData(ClipboardData(text: formatLogEntryText(entry))),
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
