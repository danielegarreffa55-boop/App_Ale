import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const canvas = Color(0xFF090A0C);
  static const panel = Color(0xFF14161A);
  static const panelStrong = Color(0xFF1B1E23);
  static const panelElevated = Color(0xFF23262B);
  static const line = Color(0xFF30343B);
  static const ink = Color(0xFFF5F5F5);
  static const muted = Color(0xFFA7ABB2);
  static const currentTimeIndicator = ink;

  static ThemeData get editorial {
    final scheme =
        const ColorScheme.dark(
          primary: ink,
          onPrimary: canvas,
          primaryContainer: panelElevated,
          onPrimaryContainer: ink,
          secondary: muted,
          onSecondary: canvas,
          secondaryContainer: panelStrong,
          onSecondaryContainer: ink,
          tertiary: Color(0xFF8FA6D6),
          onTertiary: canvas,
          tertiaryContainer: Color(0xFF1D2B47),
          onTertiaryContainer: Color(0xFFDDE7FF),
          surface: canvas,
          onSurface: ink,
          error: Color(0xFFFF6B6B),
          onError: Color(0xFF230707),
          errorContainer: Color(0xFF4A171A),
          onErrorContainer: Color(0xFFFFDAD9),
          outline: line,
          outlineVariant: Color(0xFF25282E),
          shadow: Color(0xB3000000),
          scrim: Color(0xCC000000),
          inverseSurface: ink,
          onInverseSurface: canvas,
          inversePrimary: Color(0xFF2A2D32),
        ).copyWith(
          surfaceContainerLowest: const Color(0xFF07080A),
          surfaceContainerLow: panel,
          surfaceContainer: panelStrong,
          surfaceContainerHigh: panelElevated,
          surfaceContainerHighest: const Color(0xFF2B2F35),
        );

    final baseText = Typography.material2021().white.apply(
      bodyColor: ink,
      displayColor: ink,
    );

    TextStyle? editorialTitle(TextStyle? style) => style?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: ink,
    );

    final roundedCard = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      shadowColor: Colors.black,
      splashColor: ink.withValues(alpha: 0.08),
      highlightColor: ink.withValues(alpha: 0.04),
      iconTheme: const IconThemeData(color: ink),
      textTheme: baseText.copyWith(
        displayLarge: editorialTitle(baseText.displayLarge)
            ?.copyWith(letterSpacing: 1.8),
        displayMedium: editorialTitle(baseText.displayMedium)
            ?.copyWith(letterSpacing: 1.4),
        displaySmall: editorialTitle(baseText.displaySmall),
        headlineLarge: editorialTitle(baseText.headlineLarge),
        headlineMedium: editorialTitle(baseText.headlineMedium),
        headlineSmall: editorialTitle(baseText.headlineSmall),
        titleLarge: editorialTitle(baseText.titleLarge),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
        labelMedium: baseText.labelMedium?.copyWith(letterSpacing: 0.4),
        bodySmall: baseText.bodySmall?.copyWith(color: muted),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontFamily: 'Cinzel',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: panel,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: roundedCard,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        subtitleTextStyle: TextStyle(color: muted),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        labelStyle: const TextStyle(color: muted),
        floatingLabelStyle: const TextStyle(color: ink),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.72)),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: ink,
          foregroundColor: canvas,
          disabledBackgroundColor: panelElevated,
          disabledForegroundColor: muted.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: const Color(0xFF0D0F12),
        surfaceTintColor: Colors.transparent,
        indicatorColor: ink.withValues(alpha: 0.10),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? ink : muted,
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0D0F12),
        indicatorColor: panelElevated,
        selectedIconTheme: IconThemeData(color: ink),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: panel,
        indicatorColor: panelElevated,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panelStrong,
        selectedColor: panelElevated,
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(color: ink),
        iconTheme: const IconThemeData(color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : null,
        ),
        checkColor: const WidgetStatePropertyAll(canvas),
        side: const BorderSide(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: const RadioThemeData(fillColor: WidgetStatePropertyAll(ink)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? canvas : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : line,
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 0.7),
      dialogTheme: DialogThemeData(
        elevation: 18,
        backgroundColor: panelStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: panelStrong,
        modalBackgroundColor: panelStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: panelStrong,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: ink,
        headerForegroundColor: canvas,
        dayForegroundColor: const WidgetStatePropertyAll(ink),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : null,
        ),
        todayForegroundColor: const WidgetStatePropertyAll(ink),
        todayBorder: const BorderSide(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: panelStrong,
        dialBackgroundColor: panel,
        hourMinuteColor: panelElevated,
        hourMinuteTextColor: ink,
        dialHandColor: ink,
        dialTextColor: ink,
        entryModeIconColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: canvas),
        actionTextColor: canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
      popupMenuTheme: PopupMenuThemeData(
        color: panelStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: canvas),
      ),
    );
  }
}
