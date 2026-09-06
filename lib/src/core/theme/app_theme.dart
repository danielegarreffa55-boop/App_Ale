import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF181818);
  static const beige = Color(0xFFE8E1D5);
  static const burgundy = Color(0xFF7A302B);
  static const paper = Color(0xFFF6F1E7);
  static const raised = Color(0xFFFFFCF5);
  static const line = Color(0xFFB8AE9E);

  static ThemeData get editorial {
    final scheme = const ColorScheme.light(
      primary: burgundy,
      onPrimary: raised,
      primaryContainer: Color(0xFFF0D8D4),
      onPrimaryContainer: Color(0xFF3A1110),
      secondary: ink,
      onSecondary: raised,
      secondaryContainer: beige,
      onSecondaryContainer: ink,
      tertiary: Color(0xFF9A6A50),
      onTertiary: raised,
      surface: paper,
      onSurface: ink,
      error: Color(0xFF9B2922),
      onError: Colors.white,
      outline: line,
      outlineVariant: Color(0xFFD8D0C3),
      shadow: Color(0x24181818),
    );

    final baseText = Typography.material2021().black.apply(
      bodyColor: ink,
      displayColor: ink,
    );

    TextStyle? editorialTitle(TextStyle? style) => style?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w500,
      letterSpacing: 1.4,
      color: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      textTheme: baseText.copyWith(
        displayLarge: editorialTitle(baseText.displayLarge)
            ?.copyWith(letterSpacing: 2.4),
        displayMedium: editorialTitle(baseText.displayMedium)
            ?.copyWith(letterSpacing: 2),
        displaySmall: editorialTitle(baseText.displaySmall),
        headlineLarge: editorialTitle(baseText.headlineLarge),
        headlineMedium: editorialTitle(baseText.headlineMedium),
        headlineSmall: editorialTitle(baseText.headlineSmall),
        titleLarge: editorialTitle(baseText.titleLarge),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
        labelMedium: baseText.labelMedium?.copyWith(letterSpacing: 0.8),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontFamily: 'Cinzel',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: raised,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFD8D0C3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        labelStyle: TextStyle(color: ink.withValues(alpha: 0.7)),
        floatingLabelStyle: const TextStyle(color: burgundy),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: burgundy, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: burgundy,
          foregroundColor: raised,
          disabledBackgroundColor: beige,
          disabledForegroundColor: ink.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: burgundy,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: burgundy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: burgundy),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: raised,
        indicatorColor: burgundy.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? burgundy : ink,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? burgundy : ink,
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: raised,
        indicatorColor: Color(0xFFF0D8D4),
        selectedIconTheme: IconThemeData(color: burgundy),
        selectedLabelTextStyle: TextStyle(
          color: burgundy,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: raised,
        indicatorColor: Color(0xFFF0D8D4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: const Color(0xFFF0D8D4),
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 0.7),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: raised,
        headerBackgroundColor: burgundy,
        headerForegroundColor: raised,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: raised),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: burgundy),
    );
  }
}
