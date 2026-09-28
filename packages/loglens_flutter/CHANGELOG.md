# Changelog

## 0.6.1

- Fix full screen from the floating console throwing "context that does not include a Navigator" when the root overlay sits above the app's Navigator (e.g. a toast host in `MaterialApp.builder`).
- `FloatingLogConsoleController(navigatorKey:)` to attach the overlay and full-screen route to a given navigator.
- `show` / `toggle(showSettings: true)` opens the floating console on its settings page.
- Console shows live logs even if loading history fails.
- Requires `loglens` ^0.6.1 (file store history / write fixes).

## 0.6.0

First release, aligned with `loglens` 0.6.0.

- `LogConsolePage` / `LogConsolePanel` / `LogConsolePanelController`: hydrate from disk on open, live stream, module / layer / level filters, search, display pause, fullscreen, copy-all; clear is UI-only.
- `FloatingLogConsoleController` / `FloatingLogConsoleButton`: draggable, resizable overlay console.
- `LogLensFlutter.init`: `FileLoggerStore` under the app documents dir.
- `LogLensLifecycleFlusher`: flushes the store on pause / hidden / detach.
- `SharedPrefsLoggerStore`: optional `SharedPreferences`-backed store.
