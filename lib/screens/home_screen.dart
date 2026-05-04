import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
// import '../services/dnd_service.dart'; // Retain your existing service
// import '../services/automation_manager.dart'; // Retain your existing service

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
              gradient: LinearGradient(
                colors: _isDndActive
                    ? [AppTheme.royalViolet, AppTheme.deepIndigo]
                    : [AppTheme.surfaceWhite, AppTheme.surfaceWhite],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: _isDndActive
                  ? null
                  : Border.all(color: Colors.grey.shade300),
              boxShadow: _isDndActive
                  ? [
                      BoxShadow(
                        color: AppTheme.royalViolet.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  _isDndActive
                      ? Icons.do_not_disturb_on_rounded
                      : Icons.do_not_disturb_off_rounded,
                  size: 64,
                  color: _isDndActive
                      ? AppTheme.surfaceWhite
                      : AppTheme.deepIndigo,
                ),
                const SizedBox(height: 16),
                Text(
                  _isDndActive ? 'Focus Mode Active' : 'Notifications On',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isDndActive
                        ? AppTheme.surfaceWhite
                        : AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDndActive ? 'Rule: Deep Work Focus' : 'No active rules',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDndActive
                        ? AppTheme.lavenderGlow
                        : AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 32),
                Switch(
                  value: _isDndActive,
                  onChanged: _toggleDnd,
                  activeColor: AppTheme.surfaceWhite,
                  activeTrackColor: AppTheme.softCyan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Smart Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 12),

          // Suggestion Card
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lavenderGlow.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: AppTheme.royalViolet,
                ),
              ),
              title: const Text('Sleep Schedule'),
              subtitle: const Text(
                'Silence notifications from 11 PM to 7 AM every day.',
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.electricBlue,
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
