# Ultra Sprint 14.3 — Runtime Stability Fix

- Fixed Flutter `_dependents.isEmpty` assertion caused by simultaneous root and descendant theme listeners.
- Preserved `MainNavigation` as the child of the root `ValueListenableBuilder`.
- Removed the nested theme `ValueListenableBuilder` from Settings.
- Deferred theme changes until the bottom sheet is fully dismissed.
- Replaced deprecated `RadioListTile.groupValue/onChanged` usage with explicit selectable `ListTile` rows.
- Fixed async BuildContext warning in Browser link copy action.
- Cleaned analyzer warnings for separator callbacks and null-aware collection elements.
- Version: 1.14.3+29.
