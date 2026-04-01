// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'rule_list_screen.dart';
import 'status_screen.dart'; // We will create a placeholder for this

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // The screens for our bottom navigation tabs
  final List<Widget> _screens = [const RuleListScreen(), const StatusScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      // NavigationBar is the modern Material 3 replacement for BottomNavigationBar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.rule_folder_outlined),
            selectedIcon: Icon(Icons.rule_folder),
            label: 'Rules',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Status',
          ),
        ],
      ),
    );
  }
}
