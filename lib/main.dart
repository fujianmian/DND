// lib/main.dart
import 'package:flutter/material.dart';
import 'database/database.dart';
import 'services/automation_manager.dart';
import 'screens/main_screen.dart';

late AppDatabase database;
late AutomationManager automationManager;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  database = AppDatabase();

  automationManager = AutomationManager();
  automationManager.start();

  runApp(const DndAutoApp());
}

class DndAutoApp extends StatelessWidget {
  const DndAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎨 DESIGN SYSTEM DEFINITIONS
    const colorBg = Color(0xFF14110F); // Dark base (Background)
    const colorSurface = Color(0xFF34312D); // Cards / Surface
    const colorSecondary = Color(0xFF7E7F83); // Text / Subtle elements
    const colorAccent = Color(0xFFD9C5B2); // Highlights / Active / Primary Text

    return MaterialApp(
      title: 'Context DND',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: colorBg,

        // 1. Core Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: colorAccent, // Active elements / default buttons
          onPrimary: colorBg, // Text on top of active elements
          surface: colorSurface, // Card & Dialog backgrounds
          onSurface: colorAccent, // Primary text color on surfaces
          secondary: colorSecondary,
          onSecondary: Colors.white,
        ),

        // 2. Global Typography
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: colorAccent),
          bodyMedium: TextStyle(color: colorSecondary),
          titleLarge: TextStyle(
            color: colorAccent,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: colorAccent,
            fontWeight: FontWeight.w600,
          ),
        ),

        // 3. AppBar Styling
        appBarTheme: const AppBarTheme(
          backgroundColor: colorBg,
          foregroundColor: colorAccent, // Text and icons in AppBar
          centerTitle: true,
          elevation: 0,
        ),

        // 4. Card Component Styling
        cardTheme: CardThemeData(
          color: colorSurface,
          elevation: 0, // Flat look is modern and clean
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        // 5. Buttons & Switches
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: colorAccent,
          foregroundColor: colorBg, // Dark icon on light accent button
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return colorAccent;
            return colorSecondary; // Unselected thumb
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorAccent.withOpacity(0.3); // Active track
            }
            return colorBg; // Unselected track
          }),
        ),

        // 6. Navigation Bar Styling
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colorBg, // Setting to BG to blend with Scaffold
          indicatorColor: colorAccent.withOpacity(
            0.15,
          ), // Subtle highlight bubble
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: colorAccent);
            }
            return const IconThemeData(color: colorSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: colorAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
            }
            return const TextStyle(color: colorSecondary, fontSize: 12);
          }),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
