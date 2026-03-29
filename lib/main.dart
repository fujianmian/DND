import 'package:flutter/material.dart';
import 'database/database.dart'; // Import your new DB
import 'screens/rule_list_screen.dart';

// Global database instance
late AppDatabase database;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  database = AppDatabase(); // Initialize here
  runApp(const DndAutoApp());
}

class DndAutoApp extends StatelessWidget {
  const DndAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context DND',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RuleListScreen(),
    );
  }
}
