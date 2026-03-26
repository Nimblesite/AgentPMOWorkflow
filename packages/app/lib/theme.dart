import 'package:flutter/material.dart';

// -- Palette --
class AppColors {
  static const background = Color(0xFF0f1119);
  static const surface = Color(0xFF1a1d2e);
  static const surfaceAlt = Color(0xFF161929);
  static const headerBg = Color(0xFF12141f);
  static const accent = Color(0xFF6c63ff);
  static const success = Color(0xFF2dd4a8);
  static const warning = Color(0xFFf5a623);
  static const error = Color(0xFFff4757);
  static const textPrimary = Color(0xFFe8eaf6);
  static const textMuted = Color(0xFF6b7394);
  static const border = Color(0xFF2a2d3e);
  static const hoverRow = Color(0xFF1f2236);
}

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  canvasColor: AppColors.background,
  fontFamily: '.AppleSystemUIFont', // system font on macOS (SF Pro)
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimary,
    onError: Colors.white,
  ),
  dividerColor: AppColors.border,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.0,
    ),
  ),
  iconTheme: const IconThemeData(
    color: AppColors.textMuted,
    size: 18,
  ),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStateProperty.all(AppColors.border),
    radius: const Radius.circular(4),
    thickness: WidgetStateProperty.all(6),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.border),
    ),
    textStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 12,
    ),
  ),
);
