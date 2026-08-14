import 'package:flutter/material.dart';

/// Sitara Live brand colors — kept identical to the web prototype
/// so the real app looks and feels the same.
class AppColors {
  static const bgDeep = Color(0xFF0B0B14);
  static const surface = Color(0xFF15151F);
  static const surface2 = Color(0xFF1D1D2A);
  static const hot = Color(0xFFFF2E6B);
  static const gold = Color(0xFFFFC93C);
  static const cyan = Color(0xFF2DE8C4);
  static const text = Color(0xFFF5F5FA);
  static const muted = Color(0xFF8A8A9E);
  static const line = Color(0xFF2A2A38);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgDeep,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.hot,
        secondary: AppColors.gold,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.hot),
        ),
        hintStyle: const TextStyle(color: AppColors.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hot,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
      ),
    );
  }
}
