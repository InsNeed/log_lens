import 'package:flutter/material.dart';

import '_draggable_resizable_overlay.dart';

class FloatingLogConsoleController {
  /// Pass the app's root [navigatorKey] (e.g. the one given to GoRouter or
  /// MaterialApp) to attach the overlay and full-screen route to it.
  FloatingLogConsoleController({GlobalKey<NavigatorState>? navigatorKey})
      : _navigatorKey = navigatorKey;

  final GlobalKey<NavigatorState>? _navigatorKey;
  OverlayEntry? _entry;
  Rect? _rect;

  bool get isShowing => _entry != null;

  /// Opens the console; [showSettings] opens it on the settings page.
  void show(
    BuildContext context, {
    Rect? initialRect,
    bool showSettings = false,
  }) {
    if (_entry != null) return;
    _rect = initialRect;
    final keyed = _navigatorKey?.currentState;
    final overlay = keyed?.overlay ?? Overlay.of(context, rootOverlay: true);
    final navigator =
        keyed ?? Navigator.maybeOf(context, rootNavigator: true);
    _entry = OverlayEntry(
      builder: (ctx) => DraggableResizableOverlay(
        initialRect: _rect,
        onClose: hide,
        navigator: navigator,
        initialShowSettings: showSettings,
        child: const SizedBox.shrink(),
      ),
    );
    overlay.insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }

  void toggle(
    BuildContext context, {
    Rect? initialRect,
    bool showSettings = false,
  }) {
    if (isShowing) {
      hide();
    } else {
      show(context, initialRect: initialRect, showSettings: showSettings);
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
    return Align(
      alignment: widget.alignment,
      child: Padding(
        padding: widget.padding,
        child: FloatingActionButton.extended(
          onPressed: () => setState(() {
            _controller.toggle(context, initialRect: widget.initialRect);
          }),
          icon: const Icon(Icons.bug_report),
          label: Text(_controller.isShowing ? 'Close Logs' : 'Open Logs'),
        ),
      ),
    );
  }
}
