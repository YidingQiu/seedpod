library;

import 'package:flutter/material.dart';

// Brand colors — invariant across themes
const Color colorPrimary = Color(0xFF4A7C59);
const Color colorAccent = Color(0xFFE8A87C);

// Light palette
const Color colorBg = Color(0xFFFAF8F5);
const Color colorCard = Color(0xFFFFFFFF);
const Color colorText = Color(0xFF1A1A1A);
const Color colorSecondary = Color(0xFF6B7280);
const Color colorDivider = Color(0xFFE5E1DB);

// Dark palette
const Color colorBgDark = Color(0xFF141816);
const Color colorCardDark = Color(0xFF1E2621);
const Color colorTextDark = Color(0xFFE8EDE9);
const Color colorSecondaryDark = Color(0xFF8FA68F);
const Color colorDividerDark = Color(0xFF2D3830);

/// Use these on a [BuildContext] instead of the raw color constants when the
/// color needs to adapt to the current theme brightness.
extension AdaptiveColors on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;
  Color get aCard => _dark ? colorCardDark : colorCard;
  Color get aBg => _dark ? colorBgDark : colorBg;
  Color get aDivider => _dark ? colorDividerDark : colorDivider;
  Color get aText => _dark ? colorTextDark : colorText;
  Color get aSecondary => _dark ? colorSecondaryDark : colorSecondary;
}

const double radiusSmall = 8.0;
const double radiusMedium = 16.0;
const double radiusLarge = 24.0;

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colorPrimary,
      surface: colorBg,
    ),
    scaffoldBackgroundColor: colorBg,
    cardTheme: const CardThemeData(
      color: colorCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        side: BorderSide(color: colorDivider),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: colorDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: colorDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: colorPrimary, width: 2),
      ),
      filled: true,
      fillColor: colorCard,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: colorText,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: colorText,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: colorText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: colorText,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: colorText, fontSize: 16),
      bodyMedium: TextStyle(color: colorSecondary, fontSize: 14),
      labelSmall: TextStyle(color: colorSecondary, fontSize: 12),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colorPrimary,
      brightness: Brightness.dark,
      surface: colorBgDark,
    ),
    scaffoldBackgroundColor: colorBgDark,
    cardTheme: const CardThemeData(
      color: colorCardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        side: BorderSide(color: colorDividerDark),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: colorDividerDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: colorDividerDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: colorPrimary, width: 2),
      ),
      filled: true,
      fillColor: colorCardDark,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: colorTextDark,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: colorTextDark,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: colorTextDark,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: colorTextDark,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: colorTextDark, fontSize: 16),
      bodyMedium: TextStyle(color: colorSecondaryDark, fontSize: 14),
      labelSmall: TextStyle(color: colorSecondaryDark, fontSize: 12),
    ),
  );
}
