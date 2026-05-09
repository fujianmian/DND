import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database.dart';
import '../main.dart';
import '../services/app_catalog.dart';
import '../theme/app_theme.dart';
import 'create_rule_wizard.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('My Rules')),
      body: StreamBuilder<List<Rule>>(
        stream: database.watchAllRules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rules = snapshot.data ?? [];
          if (rules.isEmpty) return _buildEmptyState();
          _primeAppLabels(rules);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openEditForm(rule),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                rule.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.pureBlack,
                                ),
                              ),
                            ),
                            Switch(
                              value: rule.isEnabled,
                              onChanged: (val) => _toggleRule(rule, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _ruleChips(rule),
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
        label: const Text('New Rule'),
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

  Future<void> _openEditForm(Rule rule) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RuleFormScreen(rule: rule)),
    );
  }

  Future<void> _toggleRule(Rule rule, bool isEnabled) async {
    if (isEnabled && rule.type == 1) {
      final canEnableLocationRule = await _ensureLocationRulePermissions();
      if (!canEnableLocationRule) return;
    }

    await database.updateRule(rule.copyWith(isEnabled: isEnabled));
    await automationManager.syncRulesToAndroid();
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

  String _triggerLabel(Rule rule) {
    switch (rule.type) {
      case 0:
        final start = rule.startTime ?? '--';
        final end = rule.endTime ?? '--';
        return 'Time: $start - $end';
      case 1:
        final radius = rule.radius == null ? '' : ' (${rule.radius}m)';
        return 'Location$radius';
      case 2:
        return 'App: ${appCatalog.labelFor(rule.packageName)}';
      case 3:
        return 'Activity: ${rule.activityType ?? 'Not selected'}';
      default:
        return 'Unknown trigger';
    }
  }

  List<Widget> _ruleChips(Rule rule) {
    final chips = <Widget>[
      _buildChip(_triggerLabel(rule), leading: _triggerLeading(rule)),
    ];

    if (rule.allowStarredContacts) {
      chips.add(_buildChip('Starred contacts'));
    }
    if (rule.allowRepeatCallers) {
      chips.add(_buildChip('Repeat callers'));
    }

    return chips;
  }

  Widget? _triggerLeading(Rule rule) {
    if (rule.type != 2 || rule.packageName == null) return null;

    final entry = appCatalog.cachedEntry(rule.packageName!);
    if (entry?.iconBytes == null) {
      return const Icon(Icons.apps, size: 16, color: AppTheme.logoBlue);
    }

    return Image.memory(entry!.iconBytes!, width: 16, height: 16);
  }

  void _primeAppLabels(List<Rule> rules) {
    for (final rule in rules) {
      final packageName = rule.packageName;
      if (rule.type != 2 ||
          packageName == null ||
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
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.pureBlack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 64, color: AppTheme.logoCyan),
          const SizedBox(height: 16),
          const Text(
            'No rules yet',
            style: TextStyle(
              fontSize: 20,
              color: AppTheme.pureBlack,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to automate your peace of mind.',
            style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
