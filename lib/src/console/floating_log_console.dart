part of my_logger;

class FloatingLogConsoleController {
  OverlayEntry? _entry;
  Rect? _rect;

  bool get isShowing => _entry != null;

  void show(BuildContext context, {Rect? initialRect}) {
    if (_entry != null) return;
    _rect = initialRect;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (ctx) => _DraggableResizableOverlay(
        initialRect: _rect,
        onClose: hide,
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: LogConsolePanel(),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }

  void toggle(BuildContext context, {Rect? initialRect}) {
    if (isShowing) {
      hide();
    } else {
      show(context, initialRect: initialRect);
    }
  }
}

class FloatingLogConsoleButton extends StatefulWidget {
  final FloatingLogConsoleController? controller;
  final Rect? initialRect;
  final bool autoAttach;
  final Alignment alignment;
  final EdgeInsets padding;

  const FloatingLogConsoleButton({
    super.key,
    this.controller,
    this.initialRect,
    this.autoAttach = true,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<FloatingLogConsoleButton> createState() =>
      _FloatingLogConsoleButtonState();
}

class _FloatingLogConsoleButtonState extends State<FloatingLogConsoleButton> {
  late final FloatingLogConsoleController _controller =
      widget.controller ?? FloatingLogConsoleController();

  @override
  Widget build(BuildContext context) {
    if (!widget.autoAttach) return _buildButton(context);
    return Stack(
      children: [
        Positioned.fill(child: const SizedBox.shrink()),
        Align(
          alignment: widget.alignment,
          child: Padding(
            padding: widget.padding,
            child: _buildButton(context),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        // MyLogger.I.i('FloatingLogConsoleButton',
        //     'FloatingLogConsoleButton pressed', 'my_logger', 'ui');
      },
      icon: const Icon(Icons.bug_report),
      label: Text(_controller.isShowing ? 'Close Logs' : 'Open Logs'),
    );
  }
}
