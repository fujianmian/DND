import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const QuietlyApp());
}

class QuietlyApp extends StatelessWidget {
  const QuietlyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quietly',
      theme: ThemeData(
        useMaterial3: true,
        // Soft, calm blue/green accent
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A9C89),
          brightness: Brightness.light,
          background: const Color(0xFFFAFAFA), // Off-white neutral background
        ),
        cardTheme: CardTheme(
          elevation: 0, // Flat, clean look
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Soft rounded corners
          ),
          color: const Color(0xFFF0F4F3), // Very subtle surface tint
        ),
        fontFamily: 'Roboto', // Or standard Flutter San Francisco/Roboto
      ),
      home: const MainScreen(),
    );
  }
}
