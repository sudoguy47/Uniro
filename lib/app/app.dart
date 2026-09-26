import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class CampusTrackerApp extends StatelessWidget {
  const CampusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.select((AppState s) => s.settings.theme);
    final isDark = theme == AppThemeMode.dark ||
        (theme == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final colors = isDark ? AppColors.dark : AppColors.light;

    final themeMode = switch (theme) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(colors, Brightness.light),
      darkTheme: AppTheme.build(AppColors.dark, Brightness.dark),
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
