# Changelog

## 0.3.1

feat(overlay): improve draggable resizable overlay behavior

- Update package version to 0.3.0
- Add \_miniHitScale constant for better touch target sizing
- Refactor edge resizing logic to handle minimum size constraints more precisely
- Simplify drag movement by removing unnecessary clamping
- Implement edge snapping for minimized overlay to prevent it from going off-screen
- Improve overall user experience with more intuitive resize and drag interactions
- Optimize console list rendering with RepaintBoundary + ListView.builder + stable keys
- Add initial loading state via FutureBuilder for persisted logs
- Add search bar with case-sensitive toggle in console panel

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
