import 'package:flutter/material.dart';

class AppTheme {
  // Extracted directly from the provided logo
  static const Color logoPurple = Color(0xFFB588FF);
  static const Color logoBlue = Color(0xFF5A9CFF);
  static const Color logoCyan = Color(0xFF4EE0D4);

  // Strictly allowed extra colors
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: logoBlue,
      scaffoldBackgroundColor: pureWhite,
      colorScheme: const ColorScheme.light(
        primary: logoBlue,
        secondary: logoCyan,
        tertiary: logoPurple,
        surface: pureWhite,
        background: pureWhite,
        onPrimary: pureWhite,
        onSurface: pureBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: pureBlack),
        titleTextStyle: TextStyle(
          color: pureBlack,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          // Subtle pure black opacity border for depth without adding gray
          side: BorderSide(color: pureBlack.withOpacity(0.1), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: logoBlue,
          foregroundColor: pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: logoBlue,
        foregroundColor: pureWhite,
        elevation: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          return pureWhite;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return logoCyan;
          return pureBlack.withOpacity(0.2); // Faded black for off state
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureWhite,
        indicatorColor: logoPurple.withOpacity(0.2), // Soft purple highlight
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              color: logoBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return TextStyle(color: pureBlack.withOpacity(0.5), fontSize: 12);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: logoBlue);
          }
          return IconThemeData(color: pureBlack.withOpacity(0.5));
        }),
      ),
    );
  }
}
