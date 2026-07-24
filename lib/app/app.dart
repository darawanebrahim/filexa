import 'package:flutter/material.dart';

import '../features/navigation/main_navigation.dart';
import '../theme/app_theme.dart';
import 'app_controller.dart';

class FilexaApp extends StatelessWidget {
  const FilexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppController.themeMode,
      child: const MainNavigation(),
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Filexa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: child,
        );
      },
    );
  }
}
