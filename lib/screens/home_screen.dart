import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
// import '../services/dnd_service.dart';
// import '../services/automation_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDndActive = false; // TODO: Bind to DndService

  void _toggleDnd(bool value) {
    setState(() {
      _isDndActive = value;
    });
    // TODO: DndService.instance.setDndMode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quietly')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Large Status Card
          Container(
            decoration: BoxDecoration(
              gradient: _isDndActive
                  ? const LinearGradient(
                      colors: [AppTheme.logoPurple, AppTheme.logoBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _isDndActive ? null : AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(32),
              border: _isDndActive
                  ? null
                  : Border.all(color: AppTheme.pureBlack.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  _isDndActive
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  size: 64,
                  color: _isDndActive ? AppTheme.pureWhite : AppTheme.logoBlue,
                ),
                const SizedBox(height: 16),
                Text(
                  _isDndActive ? 'Focus Mode Active' : 'Notifications On',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isDndActive
                        ? AppTheme.pureWhite
                        : AppTheme.pureBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDndActive ? 'Rule: Deep Work Focus' : 'No active rules',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDndActive
                        ? AppTheme.pureWhite.withOpacity(0.8)
                        : AppTheme.pureBlack.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 32),
                Switch(value: _isDndActive, onChanged: _toggleDnd),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Smart Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.pureBlack,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.logoCyan.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: AppTheme.logoCyan,
                ),
              ),
              title: const Text(
                'Sleep Schedule',
                style: TextStyle(
                  color: AppTheme.pureBlack,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Silence notifications from 11 PM to 7 AM every day.',
                style: TextStyle(color: AppTheme.pureBlack.withOpacity(0.6)),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.logoBlue,
                ),
                onPressed: () {
                  // MOCKED: Add suggestion to rules
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
