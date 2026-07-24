# Ultra Sprint 14.3 — Runtime Stability Fix V2

## Fixed
- Replaced the root `ValueListenableBuilder<ThemeMode>` with a stable stateful `MaterialApp` root.
- Added and removed the theme notifier listener safely in `initState`/`dispose`.
- Theme changes now update the existing `MaterialApp` element instead of replacing its inherited-widget tree.
- Theme picker applies changes only after its bottom sheet has completely closed.
- Settings refreshes its visible theme label after selection.
- Version updated to `1.14.3+30`.

## Important test step
This runtime assertion can remain cached by hot reload. Stop the app completely, run `flutter clean`, uninstall the old debug app from the phone, then run again.
