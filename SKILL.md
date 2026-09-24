---
name: loglens
description: >-
  Integrate and use LogLens (Dart/Flutter logging). Use when adding LogLens,
  instrumenting logs, wiring persistence/console, or choosing module/layer ids.
---

# LogLens

## Init

**Flutter (preferred)**

```dart
await LogLensFlutter.init(
  defaultModules: /* feature enums */,
  defaultLayers: LoggerDefaultLayer.values, // or project layers
);
runApp(const LogLensLifecycleFlusher(child: MyApp()));
```

**Pure Dart / tests:** `LogLens.init(...)`. Prefer `store: InMemoryLoggerStore()` in tests. On web, pass a non-`FileLoggerStore` store.

Do not use `SharedPrefsLoggerStore` as the default for large histories.

## Call

```dart
LogLens.d/i/w/e(message, module, layer);
// e may take error, stackTrace
```

If the app wraps LogLens, set `skipCallerContains` at init so caller file names resolve past the wrapper.

## Module / layer naming

- `module` = concrete feature domain: `auth`, `pay`, `cart`, `upload`, …
- Do **not** use vague modules: `app`, `common`, `misc`, `general`, `system`, `core`, `log`, `util`, `test`, `temp`, `other`, `all`
- Prefer `LoggerDefaultModule` (`auth`, `pay`, `user`, `profile`) or a custom enum with the same rules
- `layer` = architecture: `LoggerDefaultLayer` (`ui`, `provider`, `repo`, `dataSource`, `service`, `util`)

## Persistence & clear

- Default store is file-based; Flutter writes under documents `…/loglens`
- `LogLens.flush()` drains pending writes (lifecycle flusher does this on pause/detach)
- Console **Clear** = UI buffer only
- Disk wipe: `LogLens.deleteAllLogs()` (or `clearEntries()`)
- Inspect: `LogLens.loadStorageInfo()` / `loadEntries()` / `LogLens.stream`

## Release

`debugGuard: true` (default): product builds skip **only** `LogLevel.debug`. `info` / `warning` / `error` still log and persist.
