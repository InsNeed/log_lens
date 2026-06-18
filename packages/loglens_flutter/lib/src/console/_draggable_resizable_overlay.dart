import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:loglens/loglens.dart';

import 'log_console.dart';

// Edges for hit-testing (Windows-like resizing)
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

  static const Size _minSize = Size(240, 160);
  static const double _desktopHitPad = 8;
  static const double _touchHitPad = 24;
  static const double _miniBallSize = 44;
  static const double _headerHeight = 40;

  Set<_Edge>? _activeEdges;
  Offset? _lastGlobalPos;
  bool _isDragging = false;
  SystemMouseCursor _currentCursor = SystemMouseCursors.basic;
  final GlobalKey _hitKey = GlobalKey();
  final GlobalKey _dragHandleKey = GlobalKey();
  final LogConsolePanelController _panelController =
      LogConsolePanelController();

  // (enum moved to top-level)

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect ?? const Rect.fromLTWH(24, 80, 420, 320);
    if (widget.initialRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final Size screen = MediaQuery.of(context).size;
        final double desired = screen.width * 0.8;
        final double width = desired.clamp(0, 500).toDouble();
        final double height = _rect.height;
        final double left = (screen.width - width) / 2;
        final double top = (screen.height - height) / 2;
        setState(() {
          _rect = Rect.fromLTWH(left, top, width, height);
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
    final Set<_Edge> edges = {};
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
    double newLeft = _rect.left;
    double newTop = _rect.top;
    double newWidth = _rect.width;
    double newHeight = _rect.height;

    if (edges.contains(_Edge.left)) {
      final double attemptLeft = _rect.left + delta.dx;
      final double desiredWidth = _rect.right - attemptLeft;
      if (desiredWidth < _minSize.width) {
        newLeft = _rect.right - _minSize.width;
        newWidth = _minSize.width;
      } else {
        newLeft = attemptLeft;
        newWidth = desiredWidth;
      }
    }
    if (edges.contains(_Edge.right)) {
      final double attemptWidth = _rect.width + delta.dx;
      newWidth = attemptWidth < _minSize.width ? _minSize.width : attemptWidth;
    }
    if (edges.contains(_Edge.top)) {
      final double attemptTop = _rect.top + delta.dy;
      final double desiredHeight = _rect.bottom - attemptTop;
      if (desiredHeight < _minSize.height) {
        newTop = _rect.bottom - _minSize.height;
        newHeight = _minSize.height;
      } else {
        newTop = attemptTop;
        newHeight = desiredHeight;
      }
    }
    if (edges.contains(_Edge.bottom)) {
      final double attemptHeight = _rect.height + delta.dy;
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

  bool _isOnDragHandle(Offset globalPosition) {
    final box =
        _dragHandleKey.currentContext?.findRenderObject() as RenderBox?;
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
    final edges = _hitTestEdges(local, _rect.width, _rect.height);
    final cursor = _cursorForEdges(edges);
    if (cursor != _currentCursor) {
      setState(() => _currentCursor = cursor);
    }
  }

  void _handleDown(PointerDownEvent e) {
    if (_isMinimized) return;
    if (_isOnDragHandle(e.position)) {
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
      _onDrag(
        DragUpdateDetails(
          globalPosition: e.position,
          delta: delta,
        ),
        MediaQuery.of(context).size,
      );
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
      if (cursor != _currentCursor) {
        setState(() => _currentCursor = cursor);
      }
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

  void _onDrag(DragUpdateDetails d, Size screen) {
    final double newLeft = _rect.left + d.delta.dx;
    final double newTop = _rect.top + d.delta.dy;
    setState(() =>
        _rect = Rect.fromLTWH(newLeft, newTop, _rect.width, _rect.height));
  }

  void _snapMinimizedToNearestEdgeIfOut(Size screen) {
    if (!_isMinimized) return;
    final double size = _miniBallSize;
    final double left = _rect.left;
    final double top = _rect.top;
    final double right = left + size;
    final double bottom = top + size;
    final bool out =
        left < 0 || top < 0 || right > screen.width || bottom > screen.height;

    double newLeft = left;
    double newTop = top;

    if (out) {
      if (left < 0) newLeft = 0;
      if (right > screen.width) newLeft = screen.width - size;
      if (top < 0) newTop = 0;
      if (bottom > screen.height) newTop = screen.height - size;
    } else {
      final double cx = left + size / 2;
      final double cy = top + size / 2;
      final List<MapEntry<String, double>> dists = [
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

    setState(() =>
        _rect = Rect.fromLTWH(newLeft, newTop, _rect.width, _rect.height));
  }

  Widget _dragHandle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 56.0;
        final hitW = maxW.clamp(28.0, 56.0);
        final barW = (hitW - 12).clamp(20.0, 44.0);
        return MouseRegion(
          key: _dragHandleKey,
          cursor: SystemMouseCursors.move,
          child: SizedBox(
            width: hitW,
            height: _headerHeight,
            child: Center(
              child: Container(
                width: barW,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Size screen) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_showSettings)
            _circleButton(
              tooltip: 'Back',
              icon: Icons.arrow_back,
              onTap: () => setState(() => _showSettings = false),
            )
          else
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Logs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(child: _dragHandle()),
          ),
          _circleButton(
            tooltip: 'Clear',
            icon: Icons.delete_outline,
            onTap: () => _panelController.clear(),
          ),
          const SizedBox(width: 2),
          _circleButton(
            tooltip: _showSettings ? 'Back to Logs' : 'Open Settings',
            icon: _showSettings ? Icons.settings_backup_restore : Icons.settings,
            onTap: () => setState(() => _showSettings = !_showSettings),
          ),
          const SizedBox(width: 2),
          _circleButton(
            tooltip: 'Minimize',
            icon: Icons.horizontal_rule,
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
          const SizedBox(width: 2),
          _circleButton(
            tooltip: 'Close',
            icon: Icons.close,
            onTap: widget.onClose,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMinimizedBall(Size screen) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isMinimized = false),
      onPanUpdate: (d) => _onDrag(d, screen),
      onPanEnd: (_) => _snapMinimizedToNearestEdgeIfOut(screen),
      child: Container(
        width: _miniBallSize,
        height: _miniBallSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF37474F),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.terminal, color: Colors.white, size: 22),
      ),
    );
  }

  // Removed old per-edge GestureDetector resize methods in favor of unified raw-pointer handling

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final Size screen = media.size;

    final double miniSize = _miniBallSize;

    return Positioned(
      left: _rect.left,
      top: _rect.top,
      width: _isMinimized ? miniSize : _rect.width,
      height: _isMinimized ? miniSize : _rect.height,
      child: Material(
        elevation: _isMinimized ? 8 : 12,
        color: Colors.transparent,
        shape: _isMinimized ? const CircleBorder() : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _isMinimized ? Colors.transparent : Colors.white,
            borderRadius: _isMinimized ? null : BorderRadius.circular(12),
            shape: _isMinimized ? BoxShape.circle : BoxShape.rectangle,
            boxShadow: _isMinimized
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: _isMinimized
                ? BorderRadius.zero
                : BorderRadius.circular(12),
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
                            top: _headerHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                              child: _showSettings
                                  ? _SettingsPanel()
                                  : LogConsolePanel(
                                      controller: _panelController,
                                      compact: true,
                                    ),
                            ),
                          ),
                          // Edge/corner resize hit zones (below header)
                          ..._buildResizeHandles(screen),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: _buildHeader(screen),
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
        top: _headerHeight,
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
        top: _headerHeight,
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

class _SettingsPanel extends StatefulWidget {
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
      String moduleId, String layerId, LogLevel level, bool enabled) {
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
      return const Center(child: Text('No modules'));
    }
    return ListView.separated(
      itemBuilder: (context, idx) {
        final m = modules[idx];
        final moduleEnabled = _config?.isModuleEnabled(m.id) ?? false;
        return ExpansionTile(
          shape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(m.displayName),
          leading: Switch(
            value: moduleEnabled,
            onChanged: (v) => _toggleModuleAll(m.id, v),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, i) {
                final layer = LoggerRegistry.instance.layers[i];
                final layerEnabled =
                    _config?.isModuleLayerEnabled(m.id, layer.id) ?? false;
                return ExpansionTile(
                  shape: const Border(),
                  tilePadding: const EdgeInsets.only(left: 32, right: 12),
                  title: Text(layer.displayName),
                  leading: Switch(
                    value: layerEnabled,
                    onChanged: (v) => _toggleModuleLayerAll(m.id, layer.id, v),
                  ),
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, k) {
                        final lvl = LogLevel.values[k];
                        final checked =
                            _config?.shouldShow(m.id, layer.id, lvl) ?? false;
                        return SwitchListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 64, right: 12),
                          title: Text(lvl.name),
                          value: checked,
                          onChanged: (v) =>
                              _toggleModuleLevel(m.id, layer.id, lvl, v),
                        );
                      },
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.08)),
                      itemCount: LogLevel.values.length,
                    ),
                  ],
                );
              },
              separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.12)),
              itemCount: LoggerRegistry.instance.layers.length,
            ),
          ],
        );
      },
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withOpacity(0.12),
      ),
      itemCount: modules.length,
    );
  }
}

Widget _circleButton({
  required String tooltip,
  required IconData icon,
  required VoidCallback? onTap,
}) {
  return Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: Colors.grey.shade700),
        ),
      ),
    ),
  );
}
