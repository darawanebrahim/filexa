# Ultra Sprint 14.4 — Browser Runtime Stability Fix

## Fixed

- Rebuilt the Add Shortcut dialog as a dedicated StatefulWidget.
- Rebuilt the Edit Shortcut sheet as a dedicated StatefulWidget.
- TextEditingControllers are now disposed by their own route widgets after exit animations finish.
- Removed premature controller disposal after showDialog/showModalBottomSheet.
- Changed the DownloadManager Riverpod registration from ChangeNotifierProvider ownership to a plain Provider.
- Added a notification bridge so file lists still refresh without Riverpod disposing the global DownloadManager singleton.

## Targeted runtime errors

- `_dependents.isEmpty is not true`
- `ChangeNotifier.debugAssertNotDisposed`
- `_MergingListenable.addListener`
- `_AnimatedState.didUpdateWidget`
