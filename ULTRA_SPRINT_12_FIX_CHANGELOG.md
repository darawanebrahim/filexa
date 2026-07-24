# Filexa Ultra Sprint 12 — Compile Fix Update

Version: 1.12.0+24

## Fixed
- Imported the `FileMetadata` model where it is instantiated in Files.
- Replaced unsupported `drive_file_move_outline_rounded` with `drive_file_move_rounded`.
- Removed the invalid const-expression caused by the unsupported icon getter.
- Migrated all deprecated `Share.share` and `Share.shareXFiles` calls to `SharePlus.instance.share(ShareParams(...))`.
- Updated sharing in Files, Documents, Text Reader, and Browser.

## Ultra Sprint 12 features retained
- Persistent favorites and file tags.
- Favorites category in Files.
- Copy and move to managed folders.
- Automatic duplicate-name handling.
- Select all visible files.
- Metadata migration on rename/move and cleanup on delete.

## Validation note
The ZIP archive and edited Dart sources were inspected in this environment. Flutter SDK is not installed here, so `flutter analyze` and device compilation must be run locally.
