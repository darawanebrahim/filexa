# Filexa Sprint 9 — Smart Download Engine

## Stability fixes
- Removed unused legacy browser widgets reported by the analyzer.
- Replaced the unnecessary single cascade in the browser controller setup.
- Rechecked bracket balance in browser, search, download manager, task model, and downloads UI.

## Smart download engine
- Download priority levels: High, Normal, and Low.
- Queue scheduling now respects priority, then creation time.
- Priority badge on every active download card.
- Priority controls in each download menu.
- Priority shown in download details.
- Duplicate-name detection before starting a manual download.
- Duplicate flow supports Skip or Download a copy.
- Existing pause, resume, retry, cancel, speed, ETA, progress, timeline, search, sort, and compact view are retained.

## Version
- 1.9.0+21
