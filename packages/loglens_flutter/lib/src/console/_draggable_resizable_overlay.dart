import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loglens/loglens.dart';

import 'console_theme.dart';
import 'log_console.dart';

enum _Edge { left, right, top, bottom }

class DraggableResizableOverlay extends StatefulWidget {
  final Widget child;
  final Rect? initialRect;
  final VoidCallback? onClose;

  const DraggableResizableOverlay({
    required this.child,
    this.initialRect,
    this.onClose,
  });

  @override
  State<DraggableResizableOverlay> createState() =>
      _DraggableResizableOverlayState();
}

class _DraggableResizableOverlayState extends State<DraggableResizableOverlay> {
  late Rect _rect;
  bool _isMinimized = false;
  bool _showSettings = false;

  static const Size _minSize = Size(280, 180);
  static const double _desktopHitPad = 8;
  static const double _touchHitPad = 20;
  static const double _miniBallSize = 46;

  Set<_Edge>? _activeEdges;
  Offset? _lastGlobalPos;
  bool _isDragging = false;
  SystemMouseCursor _currentCursor = SystemMouseCursors.basic;
  final GlobalKey _hitKey = GlobalKey();
  final GlobalKey _dragZoneKey = GlobalKey();
  final LogConsolePanelController _panelController = LogConsolePanelController();

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect ?? const Rect.fromLTWH(24, 80, 440, 340);
    if (widget.initialRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final screen = MediaQuery.of(context).size;
        final width = (screen.width * 0.82).clamp(320.0, 520.0);
        final height = (screen.height * 0.45).clamp(240.0, 420.0);
        setState(() {
          _rect = Rect.fromLTWH(
            (screen.width - width) / 2,
            (screen.height - height) / 2,
            width,
            height,
          );
        });
      });
    }
  }

  bool get _isDesktop {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
  }

  double get _hitPad => _isDesktop ? _desktopHitPad : _touchHitPad;

  Set<_Edge> _hitTestEdges(Offset local, double width, double height) {
    final edges = <_Edge>{};
    if (local.dx <= _hitPad) edges.add(_Edge.left);
    if ((width - local.dx) <= _hitPad) edges.add(_Edge.right);
    if (local.dy <= _hitPad) edges.add(_Edge.top);
    if ((height - local.dy) <= _hitPad) edges.add(_Edge.bottom);
    return edges;
  }

  SystemMouseCursor _cursorForEdges(Set<_Edge> edges) {
    if (edges.contains(_Edge.left) && edges.contains(_Edge.top)) {
      return SystemMouseCursors.resizeUpLeftDownRight;
    }
    if (edges.contains(_Edge.right) && edges.contains(_Edge.top)) {
      return SystemMouseCursors.resizeUpRightDownLeft;
    }
    if (edges.contains(_Edge.left) && edges.contains(_Edge.bottom)) {
      return SystemMouseCursors.resizeUpRightDownLeft;
    }
    if (edges.contains(_Edge.right) && edges.contains(_Edge.bottom)) {
      return SystemMouseCursors.resizeUpLeftDownRight;
    }
    if (edges.contains(_Edge.left) || edges.contains(_Edge.right)) {
      return SystemMouseCursors.resizeLeftRight;
    }
    if (edges.contains(_Edge.top) || edges.contains(_Edge.bottom)) {
      return SystemMouseCursors.resizeUpDown;
    }
    return SystemMouseCursors.basic;
  }

  void _applyResizeDelta(Offset delta, Size screen, Set<_Edge> edges) {
    var newLeft = _rect.left;
    var newTop = _rect.top;
    var newWidth = _rect.width;
    var newHeight = _rect.height;

    if (edges.contains(_Edge.left)) {
      final attemptLeft = _rect.left + delta.dx;
      final desiredWidth = _rect.right - attemptLeft;
      if (desiredWidth < _minSize.width) {
        newLeft = _rect.right - _minSize.width;
        newWidth = _minSize.width;
      } else {
        newLeft = attemptLeft;
        newWidth = desiredWidth;
      }
    }
    if (edges.contains(_Edge.right)) {
      final attemptWidth = _rect.width + delta.dx;
      newWidth = attemptWidth < _minSize.width ? _minSize.width : attemptWidth;
    }
    if (edges.contains(_Edge.top)) {
      final attemptTop = _rect.top + delta.dy;
      final desiredHeight = _rect.bottom - attemptTop;
      if (desiredHeight < _minSize.height) {
        newTop = _rect.bottom - _minSize.height;
        newHeight = _minSize.height;
      } else {
        newTop = attemptTop;
        newHeight = desiredHeight;
      }
    }
    if (edges.contains(_Edge.bottom)) {
      final attemptHeight = _rect.height + delta.dy;
      newHeight =
          attemptHeight < _minSize.height ? _minSize.height : attemptHeight;
    }

    setState(() {
      _rect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    });
  }

  Offset _globalToLocal(Offset globalPosition) {
    final box = _hitKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.globalToLocal(globalPosition);
  }

  bool _isOnDragZone(Offset globalPosition) {
    final box = _dragZoneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
  }

  void _handleHover(PointerHoverEvent e) {
    if (!_isDesktop || _isMinimized) return;
    final local = _globalToLocal(e.position);
    final cursor = _cursorForEdges(_hitTestEdges(local, _rect.width, _rect.height));
    if (cursor != _currentCursor) setState(() => _currentCursor = cursor);
  }

  void _handleDown(PointerDownEvent e) {
    if (_isMinimized) return;
    if (_isOnDragZone(e.position)) {
      _isDragging = true;
      _lastGlobalPos = e.position;
      return;
    }
    final local = _globalToLocal(e.position);
    final edges = _hitTestEdges(local, _rect.width, _rect.height);
    if (edges.isNotEmpty) {
      _activeEdges = edges;
      _lastGlobalPos = e.position;
    }
  }

  void _handleMove(PointerMoveEvent e) {
    if (_isDragging && _lastGlobalPos != null) {
      final delta = e.position - _lastGlobalPos!;
      _lastGlobalPos = e.position;
      _onDrag(DragUpdateDetails(globalPosition: e.position, delta: delta));
      return;
    }
    if (_activeEdges != null && _lastGlobalPos != null) {
      final delta = e.position - _lastGlobalPos!;
      _lastGlobalPos = e.position;
      _applyResizeDelta(delta, MediaQuery.of(context).size, _activeEdges!);
      return;
    }
    if (_isDesktop && !_isMinimized) {
      final local = _globalToLocal(e.position);
      final cursor =
          _cursorForEdges(_hitTestEdges(local, _rect.width, _rect.height));
      if (cursor != _currentCursor) setState(() => _currentCursor = cursor);
    }
  }

  void _handleUp(PointerUpEvent e) {
    _activeEdges = null;
    _lastGlobalPos = null;
    _isDragging = false;
  }

  void _handleCancel(PointerCancelEvent e) {
    _activeEdges = null;
    _lastGlobalPos = null;
    _isDragging = false;
  }

  void _onDrag(DragUpdateDetails d) {
    setState(() {
      _rect = Rect.fromLTWH(
        _rect.left + d.delta.dx,
        _rect.top + d.delta.dy,
        _rect.width,
        _rect.height,
      );
    });
  }

  void _snapMinimizedToNearestEdgeIfOut(Size screen) {
    if (!_isMinimized) return;
    const size = _miniBallSize;
    var newLeft = _rect.left;
    var newTop = _rect.top;
    final right = newLeft + size;
    final bottom = newTop + size;
    final out = newLeft < 0 ||
        newTop < 0 ||
        right > screen.width ||
        bottom > screen.height;

    if (out) {
      if (newLeft < 0) newLeft = 0;
      if (right > screen.width) newLeft = screen.width - size;
      if (newTop < 0) newTop = 0;
      if (bottom > screen.height) newTop = screen.height - size;
    } else {
      final cx = newLeft + size / 2;
      final cy = newTop + size / 2;
      final dists = <MapEntry<String, double>>[
        MapEntry('left', cx),
        MapEntry('right', screen.width - cx),
        MapEntry('top', cy),
        MapEntry('bottom', screen.height - cy),
      ]..sort((a, b) => a.value.compareTo(b.value));

      switch (dists.first.key) {
        case 'left':
          newLeft = 0;
          break;
        case 'right':
          newLeft = screen.width - size;
          break;
        case 'top':
          newTop = 0;
          break;
        case 'bottom':
          newTop = screen.height - size;
          break;
      }
    }

    if (screen.width >= size) {
      newLeft = newLeft.clamp(0.0, screen.width - size);
    }
    if (screen.height >= size) {
      newTop = newTop.clamp(0.0, screen.height - size);
    }

    setState(() {
      _rect = Rect.fromLTWH(newLeft, newTop, _rect.width, _rect.height);
    });
  }

  Widget _titleBar() {
    final page = _showSettings ? 'config' : 'stdout';

    return Container(
      height: ConsoleTheme.headerHeight,
      decoration: const BoxDecoration(
        color: ConsoleTheme.titleBar,
        border: Border(bottom: BorderSide(color: ConsoleTheme.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Text('loglens', style: ConsoleTheme.title),
          Text(' / ', style: ConsoleTheme.subtitle),
          Text(page, style: ConsoleTheme.subtitle),
          Expanded(
            child: MouseRegion(
              key: _dragZoneKey,
              cursor: SystemMouseCursors.grab,
              child: Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ConsoleTheme.borderStrong,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
          ),
          _TitleBarButton(
            tooltip: 'Clear',
            icon: Icons.delete_sweep_outlined,
            onTap: () => _panelController.clear(),
          ),
          _TitleBarButton(
            tooltip: _showSettings ? 'Back to logs' : 'Settings',
            icon: _showSettings ? Icons.terminal : Icons.tune,
            active: _showSettings,
            onTap: () => setState(() => _showSettings = !_showSettings),
          ),
          _TitleBarButton(
            tooltip: 'Minimize',
            icon: Icons.remove,
            onTap: () {
              setState(() => _isMinimized = true);
              final size = MediaQuery.of(context).size;
              _snapMinimizedToNearestEdgeIfOut(size);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _snapMinimizedToNearestEdgeIfOut(size);
                scheduleMicrotask(() => _snapMinimizedToNearestEdgeIfOut(size));
              });
            },
          ),
          _TitleBarButton(
            tooltip: 'Close',
            icon: Icons.close,
            danger: true,
            onTap: widget.onClose,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildMinimizedBall(Size screen) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isMinimized = false),
      onPanUpdate: _onDrag,
      onPanEnd: (_) => _snapMinimizedToNearestEdgeIfOut(screen),
      child: Container(
        width: _miniBallSize,
        height: _miniBallSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ConsoleTheme.surface,
          border: Border.all(color: ConsoleTheme.borderStrong),
          boxShadow: const [
            BoxShadow(
              color: ConsoleTheme.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.terminal,
          size: 20,
          color: ConsoleTheme.prompt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final miniSize = _miniBallSize;

    return Positioned(
      left: _rect.left,
      top: _rect.top,
      width: _isMinimized ? miniSize : _rect.width,
      height: _isMinimized ? miniSize : _rect.height,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _isMinimized ? Colors.transparent : ConsoleTheme.shell,
            borderRadius:
                _isMinimized ? null : BorderRadius.circular(ConsoleTheme.radius),
            border: _isMinimized
                ? null
                : Border.all(color: ConsoleTheme.borderStrong),
            boxShadow: _isMinimized
                ? null
                : const [
                    BoxShadow(
                      color: ConsoleTheme.shadow,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: _isMinimized
                ? BorderRadius.zero
                : BorderRadius.circular(ConsoleTheme.radius),
            child: _isMinimized
                ? _buildMinimizedBall(screen)
                : MouseRegion(
                    cursor: _currentCursor,
                    onHover: _handleHover,
                    child: Listener(
                      onPointerDown: _handleDown,
                      onPointerMove: _handleMove,
                      onPointerUp: _handleUp,
                      onPointerCancel: _handleCancel,
                      child: Stack(
                        key: _hitKey,
                        children: [
                          Positioned.fill(
                            top: ConsoleTheme.headerHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: _showSettings
                                  ? const _SettingsPanel()
                                  : LogConsolePanel(
                                      controller: _panelController,
                                      compact: true,
                                    ),
                            ),
                          ),
                          ..._buildResizeHandles(screen),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: _titleBar(),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles(Size screen) {
    return [
      Positioned(
        left: 0,
        top: ConsoleTheme.headerHeight,
        bottom: 0,
        width: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.left}),
        ),
      ),
      Positioned(
        right: 0,
        top: ConsoleTheme.headerHeight,
        bottom: 0,
        width: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.right}),
        ),
      ),
      Positioned(
        left: _hitPad,
        right: _hitPad,
        top: 0,
        height: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) => _applyResizeDelta(d.delta, screen, {_Edge.top}),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.bottom}),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        width: _hitPad,
        height: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.left, _Edge.top}),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        width: _hitPad,
        height: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.right, _Edge.top}),
        ),
      ),
      Positioned(
        left: 0,
        bottom: 0,
        width: _hitPad,
        height: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.left, _Edge.bottom}),
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        width: _hitPad,
        height: _hitPad,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              _applyResizeDelta(d.delta, screen, {_Edge.right, _Edge.bottom}),
        ),
      ),
    ];
  }
}

class _TitleBarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool danger;

  const _TitleBarButton({
    required this.tooltip,
    required this.icon,
    this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? ConsoleTheme.levelColor(LogLevel.error)
        : active
            ? ConsoleTheme.levelColor(LogLevel.info)
            : ConsoleTheme.textSecondary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
          hoverColor: ConsoleTheme.selection,
          child: SizedBox(
            width: ConsoleTheme.toolbarBtn,
            height: ConsoleTheme.toolbarBtn,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel();

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  LoggerConfig? get _config => LogLens.config;

  void _toggleModuleAll(String moduleId, bool enabled) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() {
      cfg.setModuleAll(moduleId, enabled);
      LogLens.updateConfig(cfg);
    });
  }

  void _toggleModuleLayerAll(String moduleId, String layerId, bool enabled) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() {
      cfg.setModuleLayerAll(moduleId, layerId, enabled);
      LogLens.updateConfig(cfg);
    });
  }

  void _toggleModuleLevel(
    String moduleId,
    String layerId,
    LogLevel level,
    bool enabled,
  ) {
    final cfg = _config;
    if (cfg == null) return;
    setState(() {
      cfg.set(moduleId, layerId, level, enabled);
      LogLens.updateConfig(cfg);
    });
  }

  @override
  Widget build(BuildContext context) {
    final modules = LoggerRegistry.instance.modules;
    if (modules.isEmpty) {
      return Center(
        child: Text(
          '— no modules registered —',
          style: ConsoleTheme.monoSm.copyWith(color: ConsoleTheme.textMuted),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ConsoleTheme.surface,
        borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
        border: Border.all(color: ConsoleTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: modules.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: ConsoleTheme.border,
          ),
          itemBuilder: (context, idx) {
            final module = modules[idx];
            final enabled = _config?.isModuleEnabled(module.id) ?? false;
            return _ModuleSection(
              moduleId: module.id,
              title: module.displayName,
              enabled: enabled,
              onToggleModule: (v) => _toggleModuleAll(module.id, v),
              layers: LoggerRegistry.instance.layers,
              config: _config,
              onToggleLayer: (layerId, v) =>
                  _toggleModuleLayerAll(module.id, layerId, v),
              onToggleLevel: (layerId, level, v) =>
                  _toggleModuleLevel(module.id, layerId, level, v),
            );
          },
        ),
      ),
    );
  }
}

class _ModuleSection extends StatefulWidget {
  final String moduleId;
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggleModule;
  final List<LayerDefinition> layers;
  final LoggerConfig? config;
  final void Function(String layerId, bool enabled) onToggleLayer;
  final void Function(String layerId, LogLevel level, bool enabled)
      onToggleLevel;

  const _ModuleSection({
    required this.moduleId,
    required this.title,
    required this.enabled,
    required this.onToggleModule,
    required this.layers,
    required this.config,
    required this.onToggleLayer,
    required this.onToggleLevel,
  });

  @override
  State<_ModuleSection> createState() => _ModuleSectionState();
}

class _ModuleSectionState extends State<_ModuleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          hoverColor: ConsoleTheme.selection,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: ConsoleTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.title,
                    style: ConsoleTheme.mono.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ConsoleTheme.textPrimary,
                    ),
                  ),
                ),
                _TerminalSwitch(
                  value: widget.enabled,
                  onChanged: widget.onToggleModule,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.layers.map((layer) {
            final layerEnabled =
                widget.config?.isModuleLayerEnabled(widget.moduleId, layer.id) ??
                    false;
            return _LayerRow(
              title: layer.displayName,
              enabled: layerEnabled,
              onToggleLayer: (v) => widget.onToggleLayer(layer.id, v),
              levels: LogLevel.values,
              levelEnabled: (level) =>
                  widget.config?.shouldShow(widget.moduleId, layer.id, level) ??
                  false,
              onToggleLevel: (level, v) =>
                  widget.onToggleLevel(layer.id, level, v),
            );
          }),
      ],
    );
  }
}

class _LayerRow extends StatelessWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggleLayer;
  final List<LogLevel> levels;
  final bool Function(LogLevel level) levelEnabled;
  final void Function(LogLevel level, bool enabled) onToggleLevel;

  const _LayerRow({
    required this.title,
    required this.enabled,
    required this.onToggleLayer,
    required this.levels,
    required this.levelEnabled,
    required this.onToggleLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 18, right: 10, bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: ConsoleTheme.shell,
        borderRadius: BorderRadius.circular(ConsoleTheme.radiusSm),
        border: Border.all(color: ConsoleTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '└',
                style: ConsoleTheme.monoSm.copyWith(color: ConsoleTheme.textMuted),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: ConsoleTheme.monoSm.copyWith(
                    color: ConsoleTheme.prompt,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _TerminalSwitch(value: enabled, onChanged: onToggleLayer),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: levels.map((level) {
              final on = levelEnabled(level);
              return _LevelChip(
                label: ConsoleTheme.levelLabel(level),
                color: ConsoleTheme.levelColor(level),
                selected: on,
                onTap: () => onToggleLevel(level, !on),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? ConsoleTheme.levelBg(_levelFromLabel(label))
                : ConsoleTheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : ConsoleTheme.border,
            ),
          ),
          child: Text(
            label,
            style: ConsoleTheme.monoSm.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? color : ConsoleTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  LogLevel _levelFromLabel(String label) {
    if (label == 'DBG') return LogLevel.debug;
    if (label == 'INF') return LogLevel.info;
    if (label == 'WRN') return LogLevel.warning;
    return LogLevel.error;
  }
}

class _TerminalSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TerminalSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 18,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? ConsoleTheme.prompt : ConsoleTheme.border,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: ConsoleTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: ConsoleTheme.borderStrong),
            ),
          ),
        ),
      ),
    );
  }
}
