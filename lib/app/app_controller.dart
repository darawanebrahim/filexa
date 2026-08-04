import 'package:flutter/material.dart';

class AppController {
  AppController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static final ValueNotifier<bool> clipboardDetection =
      ValueNotifier<bool>(true);

  static void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  static void setClipboardDetection(bool enabled) {
    clipboardDetection.value = enabled;
  }
}
