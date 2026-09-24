import 'package:flutter/widgets.dart';
import 'package:loglens/loglens.dart';

/// Flushes the log store when the app is paused or detached.
///
/// Place near the root of your widget tree after [LogLensFlutter.init]:
/// ```dart
/// runApp(const LogLensLifecycleFlusher(child: MyApp()));
/// ```
class LogLensLifecycleFlusher extends StatefulWidget {
  final Widget child;

  const LogLensLifecycleFlusher({super.key, required this.child});

  @override
  State<LogLensLifecycleFlusher> createState() =>
      _LogLensLifecycleFlusherState();
}

class _LogLensLifecycleFlusherState extends State<LogLensLifecycleFlusher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      LogLens.flush();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
