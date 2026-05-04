import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const DndAutoApp());
}

class DndAutoApp extends StatelessWidget {
  const DndAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cold Slate Blue brand color
    const brandColor = Color(0xFF475569);

    return MaterialApp(
      title: 'Context-Aware DND',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          brightness: Brightness.light,
        ),
        // A very light slate-grey background enhances the "clean" aesthetic
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: const CardThemeData(
          elevation: 1, // Subtle elevation for floating effect
          color: Colors.white,
          shadowColor: Colors.black12,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: brandColor.withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
