import 'package:flutter/material.dart';

const Color navy = Color(0xFF0B1626);
const Color navyLight = Color(0xFF162033);
const Color navyBorder = Color(0xFF1E2D45);
const Color orange = Color(0xFFF06000);
const Color orangeLight = Color(0xFFFF7A1A);
const Color green = Color(0xFF22C55E);
const Color red = Color(0xFFEF4444);
const Color textPrimary = Color(0xFFE2EAF4);
const Color textSecondary = Color(0xFF8BA3C0);
const Color textMuted = Color(0xFF4A6080);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: navy,
    colorScheme: const ColorScheme.dark(
      primary: orange,
      secondary: orangeLight,
      surface: navyLight,
      onSurface: textPrimary,
      error: red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: navyLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: navyBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: navyLight,
      selectedItemColor: orange,
      unselectedItemColor: textMuted,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: navyLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: navyBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: navyBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: orange, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
          color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(
          color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      bodySmall: TextStyle(color: textMuted, fontSize: 11),
    ),
    dividerTheme:
        const DividerThemeData(color: navyBorder, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: navyBorder,
      labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
  );
}
