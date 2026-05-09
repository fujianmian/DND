import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    automationManager.refreshUiState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      automationManager.refreshUiState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quietly')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Large Status Card
          ValueListenableBuilder<bool>(
            valueListenable: automationManager.isDndEnabled,
            builder: (context, isDndActive, _) {
              return ValueListenableBuilder<String>(
                valueListenable: automationManager.activeStatusText,
                builder: (context, statusText, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: automationManager.nextChangeText,
                    builder: (context, detailText, _) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: isDndActive
                              ? const LinearGradient(
                                  colors: [
                                    AppTheme.logoPurple,
                                    AppTheme.logoBlue,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isDndActive ? null : AppTheme.pureWhite,
                          borderRadius: BorderRadius.circular(32),
                          border: isDndActive
                              ? null
                              : Border.all(
                                  color: AppTheme.pureBlack.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                        ),
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              isDndActive
                                  ? Icons.notifications_off_rounded
                                  : Icons.notifications_active_rounded,
                              size: 64,
                              color: isDndActive
                                  ? AppTheme.pureWhite
                                  : AppTheme.logoBlue,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isDndActive
                                  ? 'Focus Mode Active'
                                  : 'Notifications On',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDndActive
                                    ? AppTheme.pureWhite
                                    : AppTheme.pureBlack,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDndActive
                                    ? AppTheme.pureWhite.withValues(alpha: 0.85)
                                    : AppTheme.pureBlack.withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              detailText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDndActive
                                    ? AppTheme.pureWhite.withValues(alpha: 0.7)
                                    : AppTheme.pureBlack.withValues(
                                        alpha: 0.45,
                                      ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
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
                  color: AppTheme.logoCyan.withValues(alpha: 0.1),
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
                style: TextStyle(
                  color: AppTheme.pureBlack.withValues(alpha: 0.6),
                ),
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
