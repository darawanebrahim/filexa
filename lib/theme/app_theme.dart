import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const seed = Color(0xFF8B5CF6);
  static const _darkBackground = Color(0xFF080B14);
  static const _darkSurface = Color(0xFF111625);
  static const _darkSurfaceHigh = Color(0xFF181E30);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: dark ? _darkSurface : Colors.white,
    );
    final background = dark ? _darkBackground : const Color(0xFFF7F4FC);
    final surface = dark ? _darkSurface : Colors.white;
    final onSurface = dark ? const Color(0xFFF8F7FF) : const Color(0xFF191724);
    final onSurfaceVariant = dark ? const Color(0xFFABB2C5) : const Color(0xFF625E6B);

    final baseText = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      iconTheme: IconThemeData(color: onSurfaceVariant),
      textTheme: baseText.apply(bodyColor: onSurface, displayColor: onSurface).copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.8),
        headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.5),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: dark ? const Color(0xFF272E42) : const Color(0xFFE9E3F4),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF0D111D) : const Color(0xFFFFFFFF),
        indicatorColor: dark ? const Color(0xFF5B2FB5) : const Color(0xFFE6D9FF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 24);
          }
          return IconThemeData(color: onSurfaceVariant, size: 23);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected) ? onSurface : onSurfaceVariant,
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w700,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? _darkSurfaceHigh : Colors.white,
        hintStyle: TextStyle(color: onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF282F44) : const Color(0xFFE9E3F4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: seed, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF6D35D8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
        backgroundColor: Color(0xFF6D35D8),
        shape: StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? _darkSurfaceHigh : const Color(0xFFF0E9FA),
        selectedColor: dark ? const Color(0xFF4E278F) : const Color(0xFFE4D4FF),
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF252B3C) : const Color(0xFFE9E3F4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
