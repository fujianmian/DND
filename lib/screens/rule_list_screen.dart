import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'create_rule_wizard.dart';
import 'rule_form_screen.dart';

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({super.key});

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
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
    await database.updateRule(rule.copyWith(isEnabled: isEnabled));
    await automationManager.syncRulesToAndroid();
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
        return 'App: ${rule.packageName ?? 'Not selected'}';
      case 3:
        return 'Activity: ${rule.activityType ?? 'Not selected'}';
      default:
        return 'Unknown trigger';
    }
  }

  List<Widget> _ruleChips(Rule rule) {
    final chips = <Widget>[_buildChip(_triggerLabel(rule))];

    if (rule.allowStarredContacts) {
      chips.add(_buildChip('Starred contacts'));
    }
    if (rule.allowRepeatCallers) {
      chips.add(_buildChip('Repeat callers'));
    }

    return chips;
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.logoBlue),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppTheme.pureBlack),
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
