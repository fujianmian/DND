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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.logoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.logoBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppTheme.logoBlue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Privacy First',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.pureBlack,
                        ),
                      ),
                      Text(
                        'All your automation data is stored securely and locally on your device.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.pureBlack.withOpacity(0.6),
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
              color: AppTheme.pureBlack,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.do_not_disturb_on,
                    color: AppTheme.logoPurple,
                  ),
                  title: const Text(
                    'DND Access',
                    style: TextStyle(color: AppTheme.pureBlack),
                  ),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: AppTheme.logoCyan,
                  ),
                  onTap: () {},
                ),
                Divider(height: 1, color: AppTheme.pureBlack.withOpacity(0.1)),
                ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: AppTheme.logoPurple,
                  ),
                  title: const Text(
                    'Location Services',
                    style: TextStyle(color: AppTheme.pureBlack),
                  ),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: AppTheme.logoCyan,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
