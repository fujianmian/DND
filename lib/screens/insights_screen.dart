import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          AppTheme.pagePadding,
          AppTheme.pagePadding,
          AppTheme.sectionGap + bottomSafePadding,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.cardPadding),
              child: Row(
                children: [
                  const Icon(Icons.history, color: AppTheme.logoBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No automation history entries are available.',
                      style: TextStyle(
                        color: AppTheme.pureBlack.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
