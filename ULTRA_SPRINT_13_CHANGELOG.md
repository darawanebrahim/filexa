# Filexa Ultra Sprint 13 — Viewport & Scroll Stability

Version: 1.13.0+25

## Fixed
- Browser start page now scrolls through the complete Quick Access grid.
- The final Add shortcut tile is no longer hidden behind bottom navigation.
- Downloads now use one continuous vertical scroll instead of scrolling only the center list.
- Empty-download action card and New download button remain fully visible.
- Bottom navigation no longer overlays page content.
- Added safe bottom spacing for gesture/navigation areas.

## Improved
- Added visible scrollbars to Browser start and Downloads.
- Added always-scrollable/bouncing physics for short and long pages.
- The keyboard closes naturally when the user drags either page.
- Download statistics, filters, search, and results now move together as one page.

## Main changed files
- lib/features/navigation/main_navigation.dart
- lib/features/browser/browser_page.dart
- lib/features/downloads/downloads_page.dart
- pubspec.yaml
