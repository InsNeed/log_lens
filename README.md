# loglens

A modular, embeddable **pure Dart** logging toolkit. Optional Flutter UI lives in the companion package [`loglens_flutter`](packages/loglens_flutter).

## Features

- Dynamic module/layer registry with per-level switches
- Realtime stream + pluggable persistence (`InMemoryLoggerStore`, `FileLoggerStore`)
- Automatic caller file name from `StackTrace`
- Release-mode guard (`debugGuard`, on by default)
- Static API; enum-based module/layer ids

## Install

```yaml
dependencies:
  loglens: ^0.5.0
```

For Flutter console UI and `SharedPreferences` storage:

```yaml
dependencies:
  loglens: ^0.5.0
  loglens_flutter: ^0.5.0
```

## Quick Start

```dart
enum LogModules { auth, pay }
enum LogLayers { ui, dataSource }

await LogLens.init(
  defaultModules: LogModules.values,
  defaultLayers: LogLayers.values,
  // debugGuard: true, // default — no logging in release/product builds
);

LogLens.i('User pressed login', LogModules.auth, LogLayers.ui);
LogLens.e('Login failed', LogModules.auth, LogLayers.dataSource);
```

File names are resolved automatically from the call stack — no manual `file` argument.

## Release Guard

By default, logging is disabled when compiled with `dart.vm.product` (release/product builds):

```dart
await LogLens.init(debugGuard: false); // allow logging in release
```

Pure Dart equivalent of Flutter's `kDebugMode` guard:

```dart
import 'package:loglens/loglens.dart';

if (kDebugMode) { /* ... */ }
```

## Flutter UI

```dart
import 'package:loglens/loglens.dart';
import 'package:loglens_flutter/loglens_flutter.dart';

await LogLens.init(store: SharedPrefsLoggerStore());

FloatingLogConsoleController().toggle(context);
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const LogConsolePage()),
);
```

## API Highlights

- `LogLens.init({ LoggerStore? store, bool debugGuard = true, ... })`
- `LogLens.d/i/w/e(dynamic message, Enum module, Enum layer, [error, stackTrace])`
- `parseCallerFileName([StackTrace?])` — utility for custom integrations

## Persistence

| Store | Package | Notes |
|-------|---------|-------|
| `InMemoryLoggerStore` | `loglens` | Default |
| `FileLoggerStore` | `loglens` | Rolling NDJSON files (`dart:io`) |
| `SharedPrefsLoggerStore` | `loglens_flutter` | Flutter apps |

Implement `LoggerStore` or use init callbacks for custom backends.

## License

MIT — see [LICENSE](LICENSE).

## Author

- [InsNeed](https://github.com/InsNeed)
