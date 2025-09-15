import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../logger.dart';
import '../registry.dart';
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
  static const double _miniHeight = 24;
  static const double _miniWidth = 32;

  Set<_Edge>? _activeEdges;
  Offset? _lastGlobalPos;
  SystemMouseCursor _currentCursor = SystemMouseCursors.basic;
  final GlobalKey _hitKey = GlobalKey();

  // (enum moved to top-level)

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect ?? const Rect.fromLTWH(24, 80, 420, 320);
    if (widget.initialRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final Size screen = MediaQuery.of(context).size * 0.8;
        setState(() {
          _rect = Rect.fromLTWH(0, _rect.top, screen.width, _rect.height);
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
      newLeft =
          (_rect.left + delta.dx).clamp(0.0, _rect.right - _minSize.width);
      newWidth =
          (_rect.right - newLeft).clamp(_minSize.width, screen.width - newLeft);
    }
    if (edges.contains(_Edge.right)) {
      final maxWidth = screen.width - _rect.left;
      newWidth = (_rect.width + delta.dx).clamp(_minSize.width,
          maxWidth >= _minSize.width ? maxWidth : _minSize.width);
    }
    if (edges.contains(_Edge.top)) {
      newTop =
          (_rect.top + delta.dy).clamp(0.0, _rect.bottom - _minSize.height);
      newHeight = (_rect.bottom - newTop)
          .clamp(_minSize.height, screen.height - newTop);
    }
    if (edges.contains(_Edge.bottom)) {
      final maxHeight = screen.height - _rect.top;
      newHeight = (_rect.height + delta.dy).clamp(_minSize.height,
          maxHeight >= _minSize.height ? maxHeight : _minSize.height);
    }

    newLeft = newLeft.clamp(0.0, screen.width - _minSize.width);
    newTop = newTop.clamp(0.0, screen.height - _minSize.height);

    setState(() {
      _rect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    });
  }

  Offset _globalToLocal(Offset globalPosition) {
    final box = _hitKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.globalToLocal(globalPosition);
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
    final local = _globalToLocal(e.position);
    final edges = _hitTestEdges(local, _rect.width, _rect.height);
    if (edges.isNotEmpty) {
      _activeEdges = edges;
      _lastGlobalPos = e.position;
    }
  }

  void _handleMove(PointerMoveEvent e) {
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
  }

  void _handleCancel(PointerCancelEvent e) {
    _activeEdges = null;
    _lastGlobalPos = null;
  }

  void _onDrag(DragUpdateDetails d, Size screen) {
    final double visibleWidth = _isMinimized ? _miniWidth : _rect.width;
    final double visibleHeight = _isMinimized ? _miniHeight : _rect.height;
    final double maxLeft = screen.width - visibleWidth;
    final double safeMaxLeft = maxLeft >= 0 ? maxLeft : 0.0;
    final double maxTop = screen.height - visibleHeight;
    final double safeMaxTop = maxTop >= 0 ? maxTop : 0.0;
    final newLeft = (_rect.left + d.delta.dx).clamp(0.0, safeMaxLeft);
    final newTop = (_rect.top + d.delta.dy).clamp(0.0, safeMaxTop);
    setState(() =>
        _rect = Rect.fromLTWH(newLeft, newTop, _rect.width, _rect.height));
  }

  // Removed old per-edge GestureDetector resize methods in favor of unified raw-pointer handling

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final Size screen = media.size;

    return Positioned(
      left: _rect.left,
      top: _rect.top,
      width: _isMinimized ? _miniWidth : _rect.width,
      height: _isMinimized ? _miniHeight : _rect.height,
      child: Material(
        elevation: 12,
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MouseRegion(
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
                    // Drag strip at top
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 44,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          if (_activeEdges != null)
                            return; // Don't drag while resizing
                          _onDrag(d, screen);
                        },
                        child: const SizedBox.shrink(),
                      ),
                    ),

                    // Top-right round buttons
                    if (!_isMinimized)
                      Positioned(
                        right: 8,
                        top: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _circleButton(
                              tooltip: _showSettings
                                  ? 'Back to Logs'
                                  : 'Open Settings',
                              icon: _showSettings
                                  ? Icons.settings_backup_restore
                                  : Icons.settings,
                              onTap: () => setState(
                                  () => _showSettings = !_showSettings),
                            ),
                            const SizedBox(width: 8),
                            _circleButton(
                              tooltip: 'Minimize',
                              icon: Icons.horizontal_rule,
                              onTap: () => setState(() => _isMinimized = true),
                            ),
                            const SizedBox(width: 8),
                            _circleButton(
                              tooltip: 'Close',
                              icon: Icons.close,
                              onTap: widget.onClose,
                            ),
                          ],
                        ),
                      ),

                    // Back arrow when settings open (top-left)
                    if (_showSettings && !_isMinimized)
                      Positioned(
                        left: 8,
                        top: 6,
                        child: _circleButton(
                          tooltip: 'Back',
                          icon: Icons.arrow_back,
                          onTap: () => setState(() => _showSettings = false),
                        ),
                      ),

                    // Content
                    if (!_isMinimized)
                      Positioned.fill(
                        top: 40,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _showSettings
                              ? _SettingsPanel()
                              : const LogConsolePanel(),
                        ),
                      ),
                    if (_isMinimized)
                      Positioned.fill(
                        child: Center(
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 6,
                            shadowColor: Colors.black26,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setState(() => _isMinimized = false),
                              child: const SizedBox(
                                width: 12,
                                height: 12,
                                child: Center(
                                  child: Icon(Icons.crop_square, size: 10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Explicit edge/corner hit zones (Windows-friendly)
                    if (!_isMinimized)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) =>
                              _applyResizeDelta(d.delta, screen, {_Edge.left}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) =>
                              _applyResizeDelta(d.delta, screen, {_Edge.right}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) =>
                              _applyResizeDelta(d.delta, screen, {_Edge.top}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _applyResizeDelta(
                              d.delta, screen, {_Edge.bottom}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        left: 0,
                        top: 0,
                        width: _hitPad,
                        height: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _applyResizeDelta(
                              d.delta, screen, {_Edge.left, _Edge.top}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        right: 0,
                        top: 0,
                        width: _hitPad,
                        height: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _applyResizeDelta(
                              d.delta, screen, {_Edge.right, _Edge.top}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: _hitPad,
                        height: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _applyResizeDelta(
                              d.delta, screen, {_Edge.left, _Edge.bottom}),
                        ),
                      ),
                    if (!_isMinimized)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: _hitPad,
                        height: _hitPad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _applyResizeDelta(
                              d.delta, screen, {_Edge.right, _Edge.bottom}),
                        ),
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
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16),
        ),
      ),
    ),
  );
}
