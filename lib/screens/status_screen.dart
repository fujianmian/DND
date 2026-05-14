import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // Allows access to the global automationManager
import '../theme/app_theme.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  late Timer _clockTimer;

  final Color bgColor = const Color(0xFF14110F);
  final Color cardColor = const Color(0xFF34312D);
  final Color primaryTextColor = const Color(0xFFD9C5B2);
  final Color secondaryTextColor = const Color(0xFF7E7F83);

  @override
  void initState() {
    super.initState();
    _checkInitialDndPermission();
    automationManager.refreshUiState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        TimeOfDay.now();
      });
      automationManager.refreshUiState();
    });
  }

  Future<void> _checkInitialDndPermission() async {
    try {
      final bool hasAccess = await platform.invokeMethod('checkPermission');
      if (!hasAccess) {
        await platform.invokeMethod('openDndSettings');
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to check DND permission: ${e.message}");
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Automation Status',
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.pagePadding,
            AppTheme.pagePadding,
            AppTheme.sectionGap + bottomSafePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildClockHeader(),
              const SizedBox(height: AppTheme.sectionGap),
              ValueListenableBuilder<bool>(
                valueListenable: automationManager.isDndEnabled,
                builder: (context, isDndActive, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: automationManager.activeStatusText,
                    builder: (context, activeStatusText, _) {
                      return ValueListenableBuilder<List<String>>(
                        valueListenable:
                            automationManager.activeRuleDisplayNames,
                        builder: (context, activeRuleNames, _) {
                          return ValueListenableBuilder<DateTime?>(
                            valueListenable:
                                automationManager.lastAutomationDndChangedAt,
                            builder: (context, changedAt, _) {
                              return _buildAutomationCard(
                                isDndActive: isDndActive,
                                activeStatusText: activeStatusText,
                                activeRuleNames: activeRuleNames,
                                changedAt: changedAt,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: automationManager.nextChangeText,
                builder: (context, nextText, _) {
                  return _buildInfoCard(
                    title: 'Next change',
                    body: nextText,
                    icon: Icons.schedule,
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: 'Service state',
                body:
                    'Quietly refreshes this screen from the foreground automation service.',
                icon: Icons.sync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockHeader() {
    return Column(
      children: [
        Text(
          TimeOfDay.now().format(context),
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w300,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Current time',
          style: TextStyle(fontSize: 15, color: secondaryTextColor),
        ),
      ],
    );
  }

  Widget _buildAutomationCard({
    required bool isDndActive,
    required String activeStatusText,
    required List<String> activeRuleNames,
    required DateTime? changedAt,
  }) {
    final statusBody = isDndActive && activeRuleNames.isEmpty
        ? 'Automation DND is active'
        : activeStatusText;
    final changedText = changedAt == null
        ? null
        : '${isDndActive ? 'Active' : 'Updated'} since ${_formatDateTime(changedAt)}';

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDndActive
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                  color: isDndActive ? primaryTextColor : secondaryTextColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automation status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDndActive ? 'DND Automation Active' : 'Monitoring',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              statusBody,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: primaryTextColor),
            ),
            if (activeRuleNames.length > 1) ...[
              const SizedBox(height: 12),
              Text('Active rules', style: TextStyle(color: secondaryTextColor)),
              const SizedBox(height: 8),
              ...activeRuleNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: primaryTextColor),
                  ),
                ),
              ),
            ],
            if (changedText != null) ...[
              const SizedBox(height: 12),
              Text(changedText, style: TextStyle(color: secondaryTextColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, color: secondaryTextColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: primaryTextColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
