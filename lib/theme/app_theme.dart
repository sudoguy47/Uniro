import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData build(AppColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.pageBg,
      fontFamily: 'Inter',

      // ── Zero ripple (splashColor: transparent) ──
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,

      // ── ThemeExtension: AppColors ──
      extensions: [c],

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: c.pageBg,
        elevation: 0,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),

      // ── Floating SnackBar ──
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  // Motion tokens (used in UI animations & transitions)
  static const micro = Duration(milliseconds: 140);
  static const fast = Duration(milliseconds: 200);
}
