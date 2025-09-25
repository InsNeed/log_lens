# Changelog

## 0.3.0

feat(console): add clear functionality and improve overlay layout

- Add LogConsolePanelController to manage clear functionality
- Implement clear button in overlay header with controller binding
- Center overlay on screen with constrained width (max 500px)
- Add "Logs" label to overlay header for better context
- Adjust content positioning to accommodate new header elements
- Replace static LogConsolePanel with controlled instance
- Remove redundant top bar from panel content since header now provides controls

The changes improve the overlay usability by adding clear functionality and making the layout more intuitive with proper labeling and centered positioning.

## 0.2.0

- New floating window style: white rounded container with shadow
- Replaced top bar with top-right three circular buttons (settings/minimize/close)
- Top strip supports dragging; edges and all four corners support resizing
- Minimize mode retained (center small restore)
- Settings panel (modules only) inside overlay; back arrow to return to logs

## 0.1.0 - Initial release

- Rename library API to LogLens (static APIs)
- Enum-based module/layer init and logging methods
- In-app console page with module/layer/level switches
- Floating draggable & resizable overlay (mini mode supported)
- Persistence via shared_preferences
