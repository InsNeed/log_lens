part of my_logger;

class _DraggableResizableOverlay extends StatefulWidget {
  final Widget child;
  final Rect? initialRect;
  final VoidCallback? onClose;

  const _DraggableResizableOverlay({
    required this.child,
    this.initialRect,
    this.onClose,
  });

  @override
  State<_DraggableResizableOverlay> createState() =>
      _DraggableResizableOverlayState();
}

class _DraggableResizableOverlayState
    extends State<_DraggableResizableOverlay> {
  late Rect _rect;
  bool _isMinimized = false;

  static const Size _minSize = Size(240, 160);
  static const double _handleSize = 16;
  static const double _edgeThickness = 8;
  static const double _miniHeight = 48;
  static const double _miniWidth = 150;

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

  void _onResize(DragUpdateDetails d, Size screen) {
    final double maxWidth = screen.width - _rect.left;
    final double safeMaxWidth =
        maxWidth >= _minSize.width ? maxWidth : _minSize.width;
    final double maxHeight = screen.height - _rect.top;
    final double safeMaxHeight =
        maxHeight >= _minSize.height ? maxHeight : _minSize.height;
    final newWidth =
        (_rect.width + d.delta.dx).clamp(_minSize.width, safeMaxWidth);
    final newHeight =
        (_rect.height + d.delta.dy).clamp(_minSize.height, safeMaxHeight);
    setState(() =>
        _rect = Rect.fromLTWH(_rect.left, _rect.top, newWidth, newHeight));
  }

  void _onResizeLeft(DragUpdateDetails d, Size screen) {
    double newLeft = _rect.left + d.delta.dx;
    double newWidth = _rect.width - d.delta.dx;
    if (newWidth < _minSize.width) {
      newLeft -= (_minSize.width - newWidth);
      newWidth = _minSize.width;
    }
    final double safeMaxLeft = (_rect.right - _minSize.width) >= 0
        ? (_rect.right - _minSize.width)
        : 0.0;
    newLeft = newLeft.clamp(0.0, safeMaxLeft);
    setState(() =>
        _rect = Rect.fromLTWH(newLeft, _rect.top, newWidth, _rect.height));
  }

  void _onResizeRight(DragUpdateDetails d, Size screen) {
    final double maxWidth = screen.width - _rect.left;
    final double safeMaxWidth =
        maxWidth >= _minSize.width ? maxWidth : _minSize.width;
    final double newWidth =
        (_rect.width + d.delta.dx).clamp(_minSize.width, safeMaxWidth);
    setState(() =>
        _rect = Rect.fromLTWH(_rect.left, _rect.top, newWidth, _rect.height));
  }

  void _onResizeTop(DragUpdateDetails d, Size screen) {
    double newTop = _rect.top + d.delta.dy;
    double newHeight = _rect.height - d.delta.dy;
    if (newHeight < _minSize.height) {
      newTop -= (_minSize.height - newHeight);
      newHeight = _minSize.height;
    }
    final double safeMaxTop = (_rect.bottom - _minSize.height) >= 0
        ? (_rect.bottom - _minSize.height)
        : 0.0;
    newTop = newTop.clamp(0.0, safeMaxTop);
    setState(() =>
        _rect = Rect.fromLTWH(_rect.left, newTop, _rect.width, newHeight));
  }

  void _onResizeBottom(DragUpdateDetails d, Size screen) {
    final double maxHeight = screen.height - _rect.top;
    final double safeMaxHeight =
        maxHeight >= _minSize.height ? maxHeight : _minSize.height;
    final double newHeight =
        (_rect.height + d.delta.dy).clamp(_minSize.height, safeMaxHeight);
    setState(() =>
        _rect = Rect.fromLTWH(_rect.left, _rect.top, _rect.width, newHeight));
  }

  void _onResizeBottomLeft(DragUpdateDetails d, Size screen) {
    // Horizontal (left edge)
    double newLeft = _rect.left + d.delta.dx;
    double newWidth = _rect.width - d.delta.dx;
    if (newWidth < _minSize.width) {
      newLeft -= (_minSize.width - newWidth);
      newWidth = _minSize.width;
    }
    final double safeMaxLeft = (_rect.right - _minSize.width) >= 0
        ? (_rect.right - _minSize.width)
        : 0.0;
    newLeft = newLeft.clamp(0.0, safeMaxLeft);

    // Vertical (bottom edge)
    final double maxHeight = screen.height - _rect.top;
    final double safeMaxHeight =
        maxHeight >= _minSize.height ? maxHeight : _minSize.height;
    final double newHeight =
        (_rect.height + d.delta.dy).clamp(_minSize.height, safeMaxHeight);

    setState(
        () => _rect = Rect.fromLTWH(newLeft, _rect.top, newWidth, newHeight));
  }

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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.4)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Header bar
                GestureDetector(
                  onPanUpdate: (d) => _onDrag(d, screen),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5),
                      border: Border(
                          bottom: BorderSide(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.3))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator, size: 18),
                        const SizedBox(width: 6),
                        const Text('Logs'),
                        const Spacer(),
                        IconButton(
                          tooltip: _isMinimized ? 'Restore' : 'Minimize',
                          icon: Icon(_isMinimized
                              ? Icons.crop_square
                              : Icons.minimize),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          iconSize: 20,
                          onPressed: () =>
                              setState(() => _isMinimized = !_isMinimized),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          iconSize: 20,
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                if (!_isMinimized)
                  Positioned.fill(
                    top: 40,
                    child: widget.child,
                  ),
                // Resize handle (bottom-right)
                if (!_isMinimized)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: _handleSize,
                    height: _handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => _onResize(d, screen),
                        child: const Icon(Icons.drag_handle, size: 16),
                      ),
                    ),
                  ),

                // Resize handle (bottom-left)
                if (!_isMinimized)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: _handleSize,
                    height: _handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => _onResizeBottomLeft(d, screen),
                        child: const Icon(Icons.drag_handle, size: 16),
                      ),
                    ),
                  ),

                // Edge resize areas
                if (!_isMinimized)
                  Positioned(
                    left: 0,
                    top: 40,
                    bottom: 0,
                    width: _edgeThickness,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) => _onResizeLeft(d, screen),
                      ),
                    ),
                  ),
                if (!_isMinimized)
                  Positioned(
                    right: 0,
                    top: 40,
                    bottom: 0,
                    width: _edgeThickness,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) => _onResizeRight(d, screen),
                      ),
                    ),
                  ),
                if (!_isMinimized)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 40,
                    height: _edgeThickness,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) => _onResizeTop(d, screen),
                      ),
                    ),
                  ),
                if (!_isMinimized)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _edgeThickness,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) => _onResizeBottom(d, screen),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
