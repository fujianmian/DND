import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.electricBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppTheme.electricBlue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Privacy First',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepIndigo,
                        ),
                      ),
                      Text(
                        'All your automation data is stored securely and locally on your device.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Permissions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.do_not_disturb_on,
                    color: AppTheme.royalViolet,
                  ),
                  title: const Text('DND Access'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () {
                    /* Mock: Open settings */
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: AppTheme.royalViolet,
                  ),
                  title: const Text('Location Services'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () {
                    /* Mock: Open settings */
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Preferences',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.color_lens_outlined,
                color: AppTheme.mutedText,
              ),
              title: const Text('App Theme'),
              subtitle: const Text('Light Mode'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                /* Mock: Change theme */
              },
            ),
          ),
        ],
      ),
    );
  }
}
