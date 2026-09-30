# loglens

A modular, embeddable **pure Dart** logging toolkit. Optional Flutter UI lives in [`loglens_flutter`](packages/loglens_flutter).

## Features

- Dynamic module/layer registry with per-level switches
- Realtime stream + **default file persistence** (`FileLoggerStore`; optional `InMemoryLoggerStore` / `SharedPrefsLoggerStore`)
- Automatic caller file name from `StackTrace`
- Release-mode guard (`debugGuard`: strips `debug` only in product builds)
- Static API; enum-based module/layer ids

## Install

```yaml
dependencies:
  loglens: ^0.6.0
```

Flutter (console UI + documents-dir file store):

```yaml
dependencies:
  loglens: ^0.6.0
  loglens_flutter: ^0.6.0
```

## Usage

### 1. Init

**Flutter (recommended)**

```dart
import 'package:loglens/loglens.dart';
import 'package:loglens_flutter/loglens_flutter.dart';

await LogLensFlutter.init(
  defaultModules: LogModules.values, // or LoggerDefaultModule.values
  defaultLayers: LoggerDefaultLayer.values,
);
runApp(const LogLensLifecycleFlusher(child: MyApp()));
```

Logs go under the app documents dir at `…/loglens`. `LogLensLifecycleFlusher` calls `flush()` on pause/detach.

**Pure Dart**

```dart
await LogLens.init(
  defaultModules: LogModules.values,
  defaultLayers: LoggerDefaultLayer.values,
);
```

Optional: `debugGuard: false` to allow debug in release. If you call LogLens through your own wrapper, see below.

#### Wrapping LogLens (e.g. `AppLogger`)

The file name on each entry is taken from the first stack frame outside `package:loglens` / `package:logger`. If every call goes through a wrapper such as `AppLogger.info(...)`, that first frame is always the wrapper, so every entry shows `app_logger.dart`.

Tell LogLens to skip the wrapper once, at init:

```dart
await LogLens.init(
  defaultModules: AppLogModule.values,
  defaultLayers: AppLogLayer.values,
  skipCallerContains: const ['core/logging/app_logger.dart'],
);
```

Any stack frame containing one of these substrings is skipped, so entries show the real caller (`login_page.dart`, …). `LogLensFlutter.init` takes the same parameter.

This can't be automatic: from the stack alone LogLens can't tell a wrapper from business code. Guessing by file name (e.g. anything with `logger`) would hide real callers, and skipping a fixed number of frames would break apps that call `LogLens` directly.

> Don't pass `debugGuard: kDebugMode`. It evaluates to `false` in release, which turns the guard **off** and keeps debug logs in release builds. Leave `debugGuard` at its default (`true`).

### 2. Call

`LogLens.d/i/w/e(message, module, layer)`; `e` may take `error, stackTrace`. File name comes from the stack.

```dart
LogLens.i('login tapped', LogModules.auth, LoggerDefaultLayer.ui);
LogLens.e('login failed', LogModules.auth, LoggerDefaultLayer.dataSource, err, st);
```

### 3. Read

```dart
final entries = await LogLens.loadEntries(limit: 500);
final info = await LogLens.loadStorageInfo(limit: 500); // path + size
LogLens.stream.listen((e) { /* live */ });

FloatingLogConsoleController().toggle(context);
// or Navigator.push → LogConsolePage()
```

### 4. Delete files

Console **Clear** only clears the UI buffer. To wipe disk:

```dart
await LogLens.deleteAllLogs();
```

### Module / Layer

Use concrete feature domains for `module` (`auth`, `pay`, …) — avoid vague names like `app` / `common` / `util`. Prefer `LoggerDefaultModule` (`auth`, `pay`, `user`, `profile`) or a custom enum that follows the same rule. Use `LoggerDefaultLayer` for layers.

## Release Guard

With `debugGuard: true` (default), product builds skip only `debug`. `info` / `warning` / `error` still log and persist. Pass `debugGuard: false` to allow debug in release.

## API

- `LogLens.init` / `LogLensFlutter.init` — Flutter default: documents-dir `FileLoggerStore`
- `LogLens.d/i/w/e` · `flush` · `loadEntries` · `loadStorageInfo` · `deleteAllLogs`
- Stores: `FileLoggerStore` (default) · `InMemoryLoggerStore` · `SharedPrefsLoggerStore` (optional)

## Skill

For Cursor (or other agents), add the project skill so the agent wires LogLens correctly (init, modules/layers, flush, clear vs delete).

1. Copy [`SKILL.md`](SKILL.md) into your project, e.g. `.cursor/skills/loglens/SKILL.md`.
2. Or point the agent at this repo’s `SKILL.md` when integrating logging.
3. Ask the agent to “add LogLens” / “instrument with LogLens” — it should follow the skill (Flutter `LogLensFlutter.init` + `LogLensLifecycleFlusher`, concrete module names, UI clear ≠ disk delete).

See [`SKILL.md`](SKILL.md) for the full rules.

## License

MIT — see [LICENSE](LICENSE).

## Author

- [InsNeed](https://github.com/InsNeed)
