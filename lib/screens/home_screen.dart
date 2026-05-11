import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'create_rule_wizard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenRules});

  final VoidCallback onOpenRules;

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
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Quietly')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          AppTheme.pagePadding,
          AppTheme.pagePadding,
          AppTheme.sectionGap + bottomSafePadding,
        ),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: automationManager.isDndEnabled,
            builder: (context, isDndActive, _) {
              return ValueListenableBuilder<List<String>>(
                valueListenable: automationManager.activeRuleDisplayNames,
                builder: (context, activeRuleNames, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: automationManager.nextChangeText,
                    builder: (context, detailText, _) {
                      return ValueListenableBuilder<DateTime?>(
                        valueListenable:
                            automationManager.lastAutomationDndChangedAt,
                        builder: (context, changedAt, _) {
                          return _buildStatusCard(
                            isDndActive: isDndActive,
                            activeRuleNames: activeRuleNames,
                            detailText: detailText,
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
          const SizedBox(height: AppTheme.sectionGap),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required bool isDndActive,
    required List<String> activeRuleNames,
    required String detailText,
    required DateTime? changedAt,
  }) {
    final primaryRuleName = activeRuleNames.isEmpty
        ? null
        : activeRuleNames.first;
    final alsoActiveCount = activeRuleNames.length > 1
        ? activeRuleNames.length - 1
        : 0;
    final title = isDndActive
        ? 'DND Automation Active'
        : 'Quietly is monitoring';
    final statusText = isDndActive && primaryRuleName != null
        ? 'Active: $primaryRuleName'
        : 'No automation rule is active';
    final changedText = changedAt == null
        ? null
        : '${isDndActive ? 'Active' : 'Updated'} since ${_formatDateTime(changedAt)}';

    return Container(
      decoration: BoxDecoration(
        gradient: isDndActive
            ? const LinearGradient(
                colors: [AppTheme.logoPurple, AppTheme.logoBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isDndActive ? null : AppTheme.pureWhite,
        borderRadius: AppTheme.largeCardBorderRadius,
        border: isDndActive
            ? null
            : Border.all(color: AppTheme.pureBlack.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(AppTheme.sectionGap),
      child: Column(
        children: [
          Icon(
            isDndActive
                ? Icons.notifications_off_rounded
                : Icons.notifications_active_rounded,
            size: 64,
            color: isDndActive ? AppTheme.pureWhite : AppTheme.logoBlue,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDndActive ? AppTheme.pureWhite : AppTheme.pureBlack,
            ),
            textAlign: TextAlign.center,
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
          if (alsoActiveCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '+ $alsoActiveCount more active',
              style: TextStyle(
                fontSize: 13,
                color: isDndActive
                    ? AppTheme.pureWhite.withValues(alpha: 0.78)
                    : AppTheme.pureBlack.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            changedText ?? detailText,
            style: TextStyle(
              fontSize: 12,
              color: isDndActive
                  ? AppTheme.pureWhite.withValues(alpha: 0.7)
                  : AppTheme.pureBlack.withValues(alpha: 0.45),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick actions',
              style: TextStyle(
                color: AppTheme.pureBlack,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create rule'),
                    onPressed: _openCreateRule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.rule_outlined),
                    label: const Text('Manage rules'),
                    onPressed: widget.onOpenRules,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateRule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRuleWizard()),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
