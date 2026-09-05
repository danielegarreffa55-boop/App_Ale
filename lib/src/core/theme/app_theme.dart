import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const black = Color(0xFF080808);
  static const charcoal = Color(0xFF141414);
  static const raised = Color(0xFF1C1A16);
  static const gold = Color(0xFFD4AF37);
  static const deepGold = Color(0xFF8E6B16);
  static const champagne = Color(0xFFF1E3B6);
  static const ivory = Color(0xFFF8F4E8);

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: charcoal,
        ).copyWith(
          primary: gold,
          onPrimary: black,
          primaryContainer: const Color(0xFF3B2E0C),
          onPrimaryContainer: champagne,
          secondary: champagne,
          onSecondary: black,
          secondaryContainer: const Color(0xFF302711),
          onSecondaryContainer: ivory,
          tertiary: const Color(0xFFB9973A),
          onTertiary: black,
          surface: charcoal,
          onSurface: ivory,
          outline: const Color(0xFF8A7436),
          outlineVariant: const Color(0xFF3D3521),
        );

    final textTheme = Typography.material2021().white.apply(
      fontFamily: 'Cinzel',
      bodyColor: ivory,
      displayColor: ivory,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      fontFamily: 'Cinzel',
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          color: gold,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: champagne,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: black,
        foregroundColor: gold,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: gold,
          fontFamily: 'Cinzel',
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: raised,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: gold.withValues(alpha: 0.25)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111111),
        labelStyle: const TextStyle(color: champagne),
        floatingLabelStyle: const TextStyle(color: gold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: gold,
          foregroundColor: black,
          disabledBackgroundColor: deepGold.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: gold.withValues(alpha: 0.65)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 8,
        backgroundColor: const Color(0xFF0D0D0D),
        indicatorColor: gold.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? gold : ivory,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? gold : ivory,
            fontFamily: 'Cinzel',
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0D0D0D),
        indicatorColor: Color(0xFF302711),
        selectedIconTheme: IconThemeData(color: gold),
        selectedLabelTextStyle: TextStyle(
          color: gold,
          fontFamily: 'Cinzel',
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: const Color(0xFF3B2E0C),
        side: BorderSide(color: gold.withValues(alpha: 0.35)),
        labelStyle: const TextStyle(color: ivory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: gold.withValues(alpha: 0.22),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: gold.withValues(alpha: 0.3)),
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: raised,
        headerBackgroundColor: black,
        headerForegroundColor: gold,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF302711),
        contentTextStyle: TextStyle(color: ivory, fontFamily: 'Cinzel'),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    );
  }
}
