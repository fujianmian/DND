import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database.dart';
import '../main.dart';
import '../models/rule_trigger_summary.dart';
import '../services/app_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/rule_edit_navigation.dart';
import '../widgets/rule_list_empty_state.dart';
import 'create_rule_wizard.dart';
import 'multi_trigger_rule_form_screen.dart';
import 'rule_form_screen.dart';

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({super.key});

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  final Set<String> _loadingAppPackages = {};

  @override
  void initState() {
    super.initState();
    _loadAppCatalog();
  }

  Future<void> _loadAppCatalog() async {
    await appCatalog.loadInstalledApps();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('My Rules')),
      body: StreamBuilder<List<RuleWithTriggers>>(
        stream: database.watchStandaloneRulesWithTriggers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          if (entries.isEmpty) return _buildEmptyState(bottomSafePadding);
          _primeAppLabels(entries);

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              96 + bottomSafePadding,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rule = entry.rule;
              return Card(
                child: InkWell(
                  borderRadius: AppTheme.cardBorderRadius,
                  onTap: () => _openEditForm(entry),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rule.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.pureBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _stateDot(rule.isEnabled),
                                      const SizedBox(width: 6),
                                      Text(
                                        rule.isEnabled ? 'Enabled' : 'Paused',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: rule.isEnabled
                                              ? AppTheme.logoBlue
                                              : AppTheme.pureBlack.withValues(
                                                  alpha: 0.55,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: rule.isEnabled,
                              onChanged: (val) => _toggleRule(entry, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(entry),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _detailChips(entry),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
        onPressed: _openCreateWizard,
      ),
    );
  }

  Future<void> _openCreateWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRuleWizard()),
    );
  }

  Future<void> _openEditForm(RuleWithTriggers entry) async {
    if (shouldUseMultiConditionEditor(entry)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiTriggerRuleFormScreen(ruleWithTriggers: entry),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RuleFormScreen(rule: entry.rule)),
    );
  }

  Future<void> _toggleRule(RuleWithTriggers entry, bool isEnabled) async {
    final rule = entry.rule;
    if (isEnabled && _hasLocationTrigger(entry)) {
      final canEnableLocationRule = await _ensureLocationRulePermissions();
      if (!canEnableLocationRule) return;
    }

    await database.updateRule(rule.copyWith(isEnabled: isEnabled));
    await automationManager.syncRulesToAndroid();
  }

  bool _hasLocationTrigger(RuleWithTriggers entry) {
    if (entry.triggers.isEmpty) return entry.rule.type == 1;
    return entry.triggers.any((trigger) => trigger.triggerType == 1);
  }

  Future<bool> _ensureLocationRulePermissions() async {
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
    }
    if (!locationStatus.isGranted) {
      if (!mounted) return false;
      _showPermissionDialog(
        'Location Permission Needed',
        'Allow location access to use location rules.',
      );
      return false;
    }
    if (!mounted) return false;

    var backgroundStatus = await Permission.locationAlways.status;
    if (!backgroundStatus.isGranted) {
      backgroundStatus = await Permission.locationAlways.request();
    }
    if (!backgroundStatus.isGranted) {
      if (!mounted) return false;
      _showPermissionDialog(
        'Background Location Needed',
        'Allow all-the-time location so this rule can activate when Quietly is not open.',
      );
      return false;
    }

    return true;
  }

  void _showPermissionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _triggerLabel(RuleWithTriggers entry) {
    return RuleTriggerSummaryFormatter.ruleSummary(
      entry,
      appLabelFor: appCatalog.labelFor,
    );
  }

  Widget _stateDot(bool isEnabled) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isEnabled
            ? AppTheme.logoCyan
            : AppTheme.pureBlack.withValues(alpha: 0.28),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSummaryRow(RuleWithTriggers entry) {
    final leading = _triggerLeading(entry);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading ?? _summaryIcon(entry),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _triggerLabel(entry),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.pureBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryIcon(RuleWithTriggers entry) {
    final triggerType = entry.triggers.isEmpty
        ? entry.rule.type
        : entry.triggers.first.triggerType;
    final icon = switch (triggerType) {
      0 => Icons.schedule,
      1 => Icons.location_on_outlined,
      2 => Icons.apps,
      3 => Icons.directions_walk,
      4 => Icons.event,
      _ => Icons.rule,
    };
    return Icon(icon, size: 18, color: AppTheme.logoBlue);
  }

  List<Widget> _detailChips(RuleWithTriggers entry) {
    final rule = entry.rule;
    final chips = <Widget>[
      _buildChip('Priority: ${priorityLabel(rule.priority)}'),
    ];

    return chips;
  }

  Widget? _triggerLeading(RuleWithTriggers entry) {
    final packageName = _singleAppPackage(entry);
    if (packageName == null) return null;

    final appEntry = appCatalog.cachedEntry(packageName);
    if (appEntry?.iconBytes == null) {
      return const Icon(Icons.apps, size: 16, color: AppTheme.logoBlue);
    }

    return Image.memory(appEntry!.iconBytes!, width: 16, height: 16);
  }

  void _primeAppLabels(List<RuleWithTriggers> entries) {
    for (final entry in entries) {
      for (final packageName in _appPackagesFor(entry)) {
        if (packageName == null ||
            packageName.isEmpty ||
            appCatalog.cachedEntry(packageName) != null ||
            _loadingAppPackages.contains(packageName)) {
          continue;
        }

        _loadingAppPackages.add(packageName);
        appCatalog.loadAppInfo(packageName).whenComplete(() {
          _loadingAppPackages.remove(packageName);
          if (mounted) setState(() {});
        });
      }
    }
  }

  String? _singleAppPackage(RuleWithTriggers entry) {
    if (entry.triggers.length == 1) {
      final trigger = entry.triggers.single;
      if (trigger.triggerType == 2) return trigger.packageName;
      return null;
    }

    if (entry.triggers.isEmpty && entry.rule.type == 2) {
      return entry.rule.packageName;
    }

    return null;
  }

  Iterable<String?> _appPackagesFor(RuleWithTriggers entry) {
    if (entry.triggers.isNotEmpty) {
      return entry.triggers
          .where((trigger) => trigger.triggerType == 2)
          .map((trigger) => trigger.packageName);
    }

    if (entry.rule.type == 2) return [entry.rule.packageName];
    return const [];
  }

  Widget _buildChip(String label, {Widget? leading}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.logoBlue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 96,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.pureBlack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double bottomSafePadding) {
    return RuleListEmptyState(
      bottomSafePadding: bottomSafePadding,
      onCreateRule: _openCreateWizard,
    );
  }
}
