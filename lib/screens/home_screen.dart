import 'package:flutter/material.dart';
import '../main.dart';
import '../services/dnd_service.dart';
import '../theme/app_theme.dart';
import 'create_rule_wizard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenRules});

  final VoidCallback onOpenRules;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _pauseActionBusy = false;

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

    return ValueListenableBuilder<AutomationPauseState>(
      valueListenable: automationManager.automationPauseState,
      builder: (context, pauseState, _) {
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
                                pauseState: pauseState,
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
              _buildQuickActions(pauseState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard({
    required bool isDndActive,
    required List<String> activeRuleNames,
    required String detailText,
    required DateTime? changedAt,
    required AutomationPauseState pauseState,
  }) {
    final isPaused = pauseState.automationPaused && !pauseState.isExpired;
    final primaryRuleName = activeRuleNames.isEmpty
        ? null
        : activeRuleNames.first;
    final alsoActiveCount = activeRuleNames.length > 1
        ? activeRuleNames.length - 1
        : 0;
    final title = isPaused
        ? 'Automation paused'
        : (isDndActive ? 'DND Automation Active' : 'Quietly is monitoring');
    final statusText = isPaused
        ? _pausedStatusText(pauseState)
        : (isDndActive && primaryRuleName != null
              ? 'Active: $primaryRuleName'
              : 'No automation rule is active');
    final changedText = changedAt == null
        ? null
        : '${isDndActive ? 'Active' : 'Updated'} since ${_formatDateTime(changedAt)}';
    final useActiveStyle = isDndActive && !isPaused;

    return Container(
      decoration: BoxDecoration(
        gradient: useActiveStyle
            ? const LinearGradient(
                colors: [AppTheme.logoPurple, AppTheme.logoBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: useActiveStyle ? null : AppTheme.pureWhite,
        borderRadius: AppTheme.largeCardBorderRadius,
        border: useActiveStyle
            ? null
            : Border.all(color: AppTheme.pureBlack.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(AppTheme.sectionGap),
      child: Column(
        children: [
          Icon(
            isPaused
                ? Icons.pause_circle_outline_rounded
                : isDndActive
                ? Icons.notifications_off_rounded
                : Icons.notifications_active_rounded,
            size: 64,
            color: useActiveStyle ? AppTheme.pureWhite : AppTheme.logoBlue,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: useActiveStyle ? AppTheme.pureWhite : AppTheme.pureBlack,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              color: useActiveStyle
                  ? AppTheme.pureWhite.withValues(alpha: 0.85)
                  : AppTheme.pureBlack.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (!isPaused && alsoActiveCount > 0) ...[
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
            isPaused
                ? 'Rules and profiles stay enabled.'
                : changedText ?? detailText,
            style: TextStyle(
              fontSize: 12,
              color: useActiveStyle
                  ? AppTheme.pureWhite.withValues(alpha: 0.7)
                  : AppTheme.pureBlack.withValues(alpha: 0.45),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AutomationPauseState pauseState) {
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
            LayoutBuilder(
              builder: (context, constraints) {
                final pauseButton =
                    pauseState.automationPaused && !pauseState.isExpired
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'Resume automation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: _pauseActionBusy ? null : _resumeAutomation,
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.pause_rounded),
                        label: const Text(
                          'Pause automation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: _pauseActionBusy
                            ? null
                            : _showPauseAutomationDialog,
                      );
                final createButton = OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Create rule',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _openCreateRule,
                );

                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      pauseButton,
                      const SizedBox(height: 8),
                      createButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: pauseButton),
                    const SizedBox(width: 12),
                    Expanded(child: createButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.rule_outlined),
                label: const Text(
                  'Manage rules',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: widget.onOpenRules,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPauseAutomationDialog() async {
    final selection = await showDialog<_PauseSelection>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Quietly automation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PauseOptionTile(
              label: '15 minutes',
              onTap: () => Navigator.pop(
                context,
                const _PauseSelection(Duration(minutes: 15)),
              ),
            ),
            _PauseOptionTile(
              label: '30 minutes',
              onTap: () => Navigator.pop(
                context,
                const _PauseSelection(Duration(minutes: 30)),
              ),
            ),
            _PauseOptionTile(
              label: '1 hour',
              onTap: () => Navigator.pop(
                context,
                const _PauseSelection(Duration(hours: 1)),
              ),
            ),
            _PauseOptionTile(
              label: 'Until I resume',
              onTap: () => Navigator.pop(context, const _PauseSelection(null)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted || selection == null) return;

    await _pauseAutomation(selection.duration);
  }

  Future<void> _pauseAutomation(Duration? duration) async {
    setState(() => _pauseActionBusy = true);
    await DndService.pauseAutomation(duration);
    await automationManager.refreshUiState();
    if (!mounted) return;
    setState(() => _pauseActionBusy = false);
    _showSnackBar(
      duration == null
          ? 'Automation paused until resumed.'
          : 'Automation paused for ${_durationLabel(duration)}.',
    );
  }

  Future<void> _resumeAutomation() async {
    setState(() => _pauseActionBusy = true);
    await DndService.resumeAutomation();
    await automationManager.refreshUiState();
    if (!mounted) return;
    setState(() => _pauseActionBusy = false);
    _showSnackBar('Automation resumed.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreateRule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRuleWizard()),
    );
  }

  String _pausedStatusText(AutomationPauseState pauseState) {
    if (pauseState.isIndefinite) return 'Paused until resumed';
    final pauseUntil = pauseState.pauseUntil;
    if (pauseUntil == null) return 'Paused until resumed';
    return 'Paused until ${_formatTimeOfDay(pauseUntil)}';
  }

  String _durationLabel(Duration duration) {
    if (duration.inMinutes == 15) return '15 minutes';
    if (duration.inMinutes == 30) return '30 minutes';
    if (duration.inHours == 1) return '1 hour';
    return '${duration.inMinutes} minutes';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return _formatTimeOfDay(local);
  }

  String _formatTimeOfDay(DateTime dateTime) {
    final local = dateTime.toLocal();
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }
}

class _PauseSelection {
  const _PauseSelection(this.duration);

  final Duration? duration;
}

class _PauseOptionTile extends StatelessWidget {
  const _PauseOptionTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      onTap: onTap,
    );
  }
}
