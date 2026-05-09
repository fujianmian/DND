import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database/database.dart';
import 'services/automation_manager.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

final database = AppDatabase();
final automationManager = AutomationManager();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Unable to load .env: $e');
  }
  automationManager.start();
  runApp(const QuietlyApp());
}

class QuietlyApp extends StatelessWidget {
  const QuietlyApp({super.key});

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
