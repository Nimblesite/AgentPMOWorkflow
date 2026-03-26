import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0f1119);
  static const surface = Color(0xFF1a1d2e);
  static const surfaceLight = Color(0xFF222539);
  static const border = Color(0xFF2a2d3e);
  static const accent = Color(0xFF6c63ff);
  static const accentHover = Color(0xFF7d75ff);
  static const success = Color(0xFF2dd4a8);
  static const warning = Color(0xFFf5a623);
  static const error = Color(0xFFff4757);
  static const text = Color(0xFFe8eaf6);
  static const textSecondary = Color(0xFFa0a4b8);
  static const muted = Color(0xFF6b7394);
  static const dimmed = Color(0xFF444968);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.text,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text, fontSize: 14),
        bodyMedium: TextStyle(color: AppColors.text, fontSize: 13),
        bodySmall: TextStyle(color: AppColors.muted, fontSize: 12),
        titleLarge: TextStyle(
            color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(
            color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(color: AppColors.muted),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.dimmed),
        radius: const Radius.circular(4),
      ),
    );
  }

  static const monoStyle = TextStyle(
    fontFamilyFallback: ['SF Mono', 'Menlo', 'Monaco', 'monospace'],
    fontSize: 12,
    color: AppColors.text,
    height: 1.5,
  );
}
