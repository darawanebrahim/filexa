# Filexa Ultra Sprint 12 — Professional File Workspace

Version: `1.12.0+24`

## Implemented

- Persistent file favorites stored locally in `.filexa_metadata.json`.
- Persistent custom tags for managed files.
- Favorites smart collection in the Files category strip.
- Copy files into managed subfolders with collision-safe naming.
- Move files into managed subfolders, including cross-filesystem fallback.
- Existing-folder suggestions in copy/move dialogs.
- Select-all-visible action for filtered file results.
- Metadata automatically follows rename and move operations.
- Metadata is removed when a file is deleted.
- Duplicate destination names are resolved as `name (1).ext`, `name (2).ext`, etc.
- Version advanced from `1.11.0+23` to `1.12.0+24`.

## Safety

- No file is deleted automatically.
- Copy and move destinations are sanitized.
- Move falls back to copy-then-delete when rename is unavailable across storage boundaries.

## Validation note

The project structure and ZIP integrity were validated in the build environment. Flutter SDK was not available, so run `flutter analyze` and device tests locally before merging into `main`.
