import 'package:flutter/material.dart';

class AppController {
  AppController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }
}
