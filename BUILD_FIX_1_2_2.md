# Filexa 1.2.2 Build Fix

- Fixed the `Invalid constant value` error in `browser_page.dart`.
- Removed `const` from the `SliverPadding` that uses the runtime theme color `scheme.onSurface`.
- Kept compile-time constants on `EdgeInsets` where valid.
- The remaining `unused_element` analyzer messages are warnings and do not block the Android build.
