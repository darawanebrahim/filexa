# Filexa Ultra Sprint 14.2 — Search Layout Stability

## Fixed
- Fixed the 1.2-pixel bottom overflow on the global search empty state when the keyboard is open.
- Made the empty-state card scroll-safe on smaller screens and with large keyboards.
- Added keyboard dismissal when tapping outside the search box.
- Added keyboard dismissal while dragging search content.
- Preserved the existing search filters, sorting, recent searches, and result list.

## Version
- `1.14.2+27`

## Validation note
- Source structure and ZIP integrity were checked in the workspace.
- Flutter SDK was not available in this environment, so run `flutter analyze` and `flutter run` locally.
