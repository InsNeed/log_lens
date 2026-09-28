# loglens_flutter

Flutter companion for [`loglens`](https://pub.dev/packages/loglens): in-app log console, draggable floating overlay, documents-dir file persistence, and an optional `SharedPreferences` store.

## Install

```yaml
dependencies:
  loglens: ^0.6.0
  loglens_flutter: ^0.6.0
```

## Init

```dart
import 'package:loglens/loglens.dart';
import 'package:loglens_flutter/loglens_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogLensFlutter.init(
    defaultModules: LoggerDefaultModule.values,
    defaultLayers: LoggerDefaultLayer.values,
  );
  runApp(const LogLensLifecycleFlusher(child: MyApp()));
}
```

- `LogLensFlutter.init` stores logs under the app documents dir (`.../loglens`) via `FileLoggerStore`. Pass `store:` to use your own store.
- `LogLensLifecycleFlusher` calls `LogLens.flush()` when the app is paused, hidden or detached.

If you already call `LogLens.init` yourself, you can skip `LogLensFlutter.init` and just use the UI below.

## Console

Full page:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const LogConsolePage()),
);
```

Floating, draggable and resizable overlay:

```dart
final controller = FloatingLogConsoleController();
controller.toggle(context);

// or drop in a ready-made button
const FloatingLogConsoleButton();
```

Embed the panel anywhere:

```dart
final panelController = LogConsolePanelController();
LogConsolePanel(controller: panelController);
panelController.clear(); // clears the UI buffer only
```

The console hydrates recent entries from disk when opened, then follows the live stream. It supports module / layer / level filtering, text search, pause, fullscreen and copy-all. **Clear** only affects the UI; use `LogLens.deleteAllLogs()` to remove files.

## SharedPreferences store

```dart
await LogLens.init(store: SharedPrefsLoggerStore());
```

## License

MIT
