import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Notifications Blocked',
                  '142',
                  Icons.notifications_off,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard('Focus Time', '4h 12m', Icons.timer),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Most Active Rule',
                    style: TextStyle(color: AppTheme.mutedText),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Office Focus',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepIndigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active for 30 hours this week',
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.softCyan, size: 28),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
