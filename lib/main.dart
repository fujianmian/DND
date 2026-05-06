import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // THIS IS THE CRITICAL LINE: It forces Light Theme even if the phone is in Dark Mode
      themeMode: ThemeMode.light,
      home: const MainScreen(),
    );
  }
}
