import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  AppTheme._();

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
