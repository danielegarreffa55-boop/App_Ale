import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF211D1B);
  static const _cream = Color(0xFFF8F4EF);
  static const _copper = Color(0xFFA56648);
  static const _sage = Color(0xFF748678);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _copper,
      brightness: Brightness.light,
      surface: _cream,
      primary: _ink,
      secondary: _copper,
      tertiary: _sage,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _cream,
      textTheme: Typography.material2021().black.apply(
        bodyColor: _ink,
        displayColor: _ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.82),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _ink.withValues(alpha: 0.07)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _ink.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
