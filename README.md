# loglens

A modular, embeddable logging toolkit for Flutter apps. It provides:

- Dynamic module/layer registry with per-level switches
- In-app console page with modern, compact UI
- Floating draggable/resizeable overlay window for live logs
- Persistent storage via `shared_preferences`

## Features

- Modules and layers (e.g., module=auth, layer=ui) with level toggles (debug/info/warning/error)
- Realtime stream + in-memory buffer
- Full console page and floating overlay window
- Static API; enum-based initialization for readable module/layer ids

## Install

Add to your `pubspec.yaml` (if your package name is `loglens`):

```yaml
dependencies:
  loglens: ^0.1.0
```

Import:

```dart
import 'package:loglens/loglens.dart';
```

## Quick Start

Define enums that match your project’s modules and layers. For example:

- Modules: login, payment, order, blacklist
- Layers (MVVM-ish): UI, View, ViewModel, Domain, Repository, DataSource, Network/API, Service, Cache

```dart
enum LogModules { auth, pay, order, blacklist }
enum LogLayers {
  ui,
  view,
  viewModel,
  domain,
  repository,
  dataSource,
  network, // or api
  service,
  cache,
}
```

Initialize:

```dart
await LogLens.init(
  defaultModules: LogModules.values,
  defaultLayers: LogLayers.values,
);
```

Write logs (pass enums):

```dart
LogLens.d('example.dart', 'Debug sample', LogModules.auth, LogLayers.ui);
LogLens.i('example.dart', 'Info sample', LogModules.auth, LogLayers.dataSource);
LogLens.w('example.dart', 'Warning sample', LogModules.pay, LogLayers.ui);
LogLens.e('example.dart', 'Error sample', LogModules.pay, LogLayers.dataSource, 'SomeError');
```

Open the floating debug window:

```dart
final controller = FloatingLogConsoleController();
FloatingLogConsoleButton(controller: controller);
// Or programmatically: controller.toggle(context);
```

Open the full console page:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const LogConsolePage()),
);
```

## API Highlights

- `LogLens.init({ LoggerStore? store, LoggerConfig? config, List<Enum>? defaultModules, List<Enum>? defaultLayers })`
- `LogLens.d/i/w/e(String file, dynamic message, Enum module, Enum layer, [error, stacktrace])`

## Persistence

`SharedPrefsLoggerStore` is used by default. You can implement your own `LoggerStore` and pass it to `init`.

## Screenshots (optional)

Add screenshots/GIFs here to showcase the console and overlay.

## License

This project is open source under the MIT License. See [LICENSE](LICENSE).

## Author

- [InsNeed](https://github.com/InsNeed)
