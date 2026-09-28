# Changelog

## 0.6.0

First release, aligned with `loglens` 0.6.0.

- `LogConsolePage` / `LogConsolePanel` / `LogConsolePanelController`: hydrate from disk on open, live stream, module / layer / level filters, search, display pause, fullscreen, copy-all; clear is UI-only.
- `FloatingLogConsoleController` / `FloatingLogConsoleButton`: draggable, resizable overlay console.
- `LogLensFlutter.init`: `FileLoggerStore` under the app documents dir.
- `LogLensLifecycleFlusher`: flushes the store on pause / hidden / detach.
- `SharedPrefsLoggerStore`: optional `SharedPreferences`-backed store.
