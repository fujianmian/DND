import 'package:flutter/material.dart';

class AppTheme {
  // Primary identity colors
  static const Color deepIndigo = Color(0xFF171A4A);
  static const Color royalViolet = Color(0xFF745CFF);
  static const Color electricBlue = Color(0xFF4A86FF);
  static const Color softCyan = Color(0xFF52D6F5);
  static const Color lavenderGlow = Color(0xFFC9B8FF);

  // Background & Surface
  static const Color offWhiteBg = Color(0xFFF7F8FC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // Text
  static const Color primaryText = Color(0xFF1D1F2A);
  static const Color mutedText = Color(0xFF5E6472);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: royalViolet,
      scaffoldBackgroundColor: offWhiteBg,
      fontFamily:
          'Roboto', // Replace with your premium font if applicable (e.g., GoogleFonts.inter())
      colorScheme: const ColorScheme.light(
        primary: royalViolet,
        secondary: electricBlue,
        surface: surfaceWhite,
        background: offWhiteBg,
        onPrimary: surfaceWhite,
        onSurface: primaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: offWhiteBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: deepIndigo),
        titleTextStyle: TextStyle(
          color: deepIndigo,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalViolet,
          foregroundColor: surfaceWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: royalViolet,
        foregroundColor: surfaceWhite,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceWhite,
        indicatorColor: lavenderGlow.withOpacity(0.5),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              color: deepIndigo,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(color: mutedText, fontSize: 12);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: deepIndigo);
          }
          return const IconThemeData(color: mutedText);
        }),
      ),
    );
  }
}
