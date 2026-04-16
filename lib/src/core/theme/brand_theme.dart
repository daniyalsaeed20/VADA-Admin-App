import 'package:flutter/material.dart';

class BrandTheme {
  static const Color vadaRed = Color(0xFFB50000);
  static const Color vadaRedDark = Color(0xFF7D0000);
  static const Color vadaCharcoal = Color(0xFF1F1F1F);
  static const Color vadaSteel = Color(0xFF767676);
  static const Color vadaCanvas = Color(0xFFF5F5F5);

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: vadaRed,
      onPrimary: Colors.white,
      secondary: vadaCharcoal,
      onSecondary: Colors.white,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: vadaCharcoal,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: vadaCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: vadaCharcoal,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: vadaRed, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: vadaRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: vadaSteel,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(color: vadaRed),
        selectedLabelTextStyle: TextStyle(
          color: vadaRed,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: vadaCharcoal,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: vadaCharcoal,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: vadaCharcoal,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: vadaCharcoal),
        bodyMedium: TextStyle(color: vadaCharcoal),
      ),
      useMaterial3: true,
    );
  }
}
