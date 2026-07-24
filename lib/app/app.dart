import 'package:flutter/material.dart';

import '../features/navigation/main_navigation.dart';
import '../theme/app_theme.dart';
import 'app_controller.dart';

/// Root application widget.
///
/// The theme notifier is listened to by this State object instead of wrapping
/// MaterialApp with ValueListenableBuilder. Keeping the MaterialApp element
/// stable prevents inherited theme/media-query elements from being removed
/// while routes or bottom sheets still depend on them.
class FilexaApp extends StatefulWidget {
  const FilexaApp({super.key});

  @override
  State<FilexaApp> createState() => _FilexaAppState();
}

class _FilexaAppState extends State<FilexaApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = AppController.themeMode.value;
    AppController.themeMode.addListener(_handleThemeChanged);
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    final nextMode = AppController.themeMode.value;
    if (nextMode == _themeMode) return;
    setState(() => _themeMode = nextMode);
  }

  @override
  void dispose() {
    AppController.themeMode.removeListener(_handleThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Filexa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigation(),
    );
  }
}
