import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  AppTheme._();

  // ── Light theme ───────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const bg = Color(0xFFF5F5F5);
    const surface = Colors.white;
    const card = Colors.white;
    const textPrimary = Color(0xFF1B2838);
    const textSecondary = Color(0xFF5F6B7A);
    const divider = Color(0xFFE0E0E0);
    const border = Color(0xFFBDBDBD);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: SteamColors.steamBlue,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFD6EEFF),
        onPrimaryContainer: const Color(0xFF1B2838),
        secondary: SteamColors.steamGreen,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: SteamColors.error,
        onError: Colors.white,
        outline: border,
        outlineVariant: divider,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B6FA8),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1B6FA8),
          side: const BorderSide(color: Color(0xFF1B6FA8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1B6FA8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF1B6FA8), width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: textPrimary,
        iconColor: textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 22),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF1B6FA8),
        linearTrackColor: Color(0xFFE0E0E0),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1B6FA8);
          }
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1B6FA8).withAlpha(80);
          }
          return const Color(0xFFE0E0E0);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1B6FA8);
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: divider),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ── Color scheme ──────────────────────────────────────────────────
      colorScheme: ColorScheme.dark(
        primary: SteamColors.steamBlue,
        onPrimary: SteamColors.darkerBackground,
        primaryContainer: SteamColors.surfaceColor,
        onPrimaryContainer: SteamColors.steamLightBlue,
        secondary: SteamColors.steamGreen,
        onSecondary: Colors.white,
        secondaryContainer: SteamColors.steamDarkGreen,
        onSecondaryContainer: Colors.white,
        surface: SteamColors.darkBackground,
        onSurface: SteamColors.textPrimary,
        surfaceContainerHighest: SteamColors.cardBackground,
        error: SteamColors.error,
        onError: Colors.white,
        outline: SteamColors.border,
        outlineVariant: SteamColors.divider,
      ),

      // ── Scaffold ──────────────────────────────────────────────────────
      scaffoldBackgroundColor: SteamColors.darkerBackground,

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: SteamColors.darkerBackground,
        foregroundColor: SteamColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: SteamColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: SteamColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SteamColors.divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Elevated button ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SteamColors.steamBlue,
          foregroundColor: SteamColors.darkerBackground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Outlined button ───────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SteamColors.steamBlue,
          side: const BorderSide(color: SteamColors.steamBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Text button ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SteamColors.steamBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input decoration ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SteamColors.darkBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SteamColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SteamColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SteamColors.steamBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SteamColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SteamColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: SteamColors.textSecondary),
        hintStyle: const TextStyle(color: SteamColors.textSecondary),
      ),

      // ── Dialog ────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: SteamColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SteamColors.divider),
        ),
        titleTextStyle: const TextStyle(
          color: SteamColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: SteamColors.textSecondary,
          fontSize: 14,
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: SteamColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: SteamColors.textPrimary,
        iconColor: SteamColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Icon ──────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: SteamColors.textSecondary,
        size: 22,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SteamColors.surfaceColor,
        contentTextStyle: const TextStyle(color: SteamColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Tooltip ───────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: SteamColors.surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SteamColors.divider),
        ),
        textStyle: const TextStyle(color: SteamColors.textPrimary, fontSize: 12),
      ),

      // ── Progress indicator ────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SteamColors.steamBlue,
        linearTrackColor: SteamColors.surfaceColor,
      ),

      // ── Switch / Checkbox / Radio ─────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SteamColors.steamBlue;
          }
          return SteamColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SteamColors.steamBlue.withAlpha(80);
          }
          return SteamColors.surfaceColor;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SteamColors.steamBlue;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(SteamColors.darkerBackground),
        side: const BorderSide(color: SteamColors.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Bottom navigation / navigation rail ──────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: SteamColors.darkerBackground,
        selectedIconTheme:
            const IconThemeData(color: SteamColors.steamBlue, size: 24),
        unselectedIconTheme:
            const IconThemeData(color: SteamColors.textSecondary, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: SteamColors.steamBlue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: SteamColors.textSecondary,
          fontSize: 12,
        ),
        indicatorColor: SteamColors.steamBlue.withAlpha(30),
      ),

      // ── Popup menu ────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: SteamColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SteamColors.divider),
        ),
        textStyle: const TextStyle(
          color: SteamColors.textPrimary,
          fontSize: 14,
        ),
      ),

      // ── Text theme ────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: SteamColors.textPrimary),
        displayMedium: TextStyle(color: SteamColors.textPrimary),
        displaySmall: TextStyle(color: SteamColors.textPrimary),
        headlineLarge: TextStyle(
          color: SteamColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: SteamColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: SteamColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: SteamColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(color: SteamColors.textPrimary),
        titleSmall: TextStyle(color: SteamColors.textSecondary),
        bodyLarge: TextStyle(color: SteamColors.textPrimary),
        bodyMedium: TextStyle(color: SteamColors.textPrimary),
        bodySmall: TextStyle(color: SteamColors.textSecondary),
        labelLarge: TextStyle(
          color: SteamColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: SteamColors.textSecondary),
        labelSmall: TextStyle(color: SteamColors.textSecondary),
      ),
    );
  }
}
