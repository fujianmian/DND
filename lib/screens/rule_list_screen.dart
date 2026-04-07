import 'package:flutter/material.dart';
import 'rule_form_screen.dart';
import '../database/database.dart';
import '../main.dart'; // Accesses global `database` and `automationManager`
import '../services/dnd_service.dart';
import 'dart:typed_data';

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({super.key});

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  void _showDeleteDialog(Rule rule) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            "Delete Rule?",
            style: TextStyle(color: colorScheme.primary),
          ),
          content: Text(
            "Are you sure you want to remove '${rule.name}'?",
            style: TextStyle(color: colorScheme.secondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: TextStyle(color: colorScheme.secondary),
              ),
            ),
            FilledButton(
              onPressed: () async {
                // 1. Delete from database
                await database.deleteRule(rule);

                // 2. Sync deletion to the Android background service
                automationManager.syncRulesToAndroid();

                // 3. Safely pop using the dialog's context
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Automations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // --- STATUS & TEST PANEL ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.toggle_on, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        "Manual Override",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => DndService.enableDnd(),
                          icon: const Icon(Icons.do_not_disturb_on, size: 18),
                          label: const Text("Enable"),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => DndService.disableDnd(),
                          icon: const Icon(Icons.do_not_disturb_off, size: 18),
                          label: const Text("Disable"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.secondary,
                            side: BorderSide(color: colorScheme.secondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              // Push all current rules to the background service directly via the manager
              await automationManager.syncRulesToAndroid();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Synced rules to background service!'),
                  ),
                );
              }
            },
            child: const Text("Sync Rules to Background"),
          ),

          // --- ENHANCED RULE LIST ---
          Expanded(
            child: StreamBuilder<List<Rule>>(
              stream: database.watchAllRules(),
              builder: (context, snapshot) {
                final rules = snapshot.data ?? [];

                if (rules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rule_folder_outlined,
                          size: 64,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No rules configured yet.',
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];

                    final isTimeRule = rule.type == 0;
                    final isLocationRule = rule.type == 1;
                    final isAppRule = rule.type == 2;

                    // 🔹 Internal helper to render the UI for a rule
                    Widget buildRuleCard(
                      String displayName,
                      Widget iconWidget,
                    ) {
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RuleFormScreen(rule: rule),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // ICON CONTAINER
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: iconWidget,
                                ),
                                const SizedBox(width: 16),

                                // TEXT INFO
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rule.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isTimeRule
                                            ? "${rule.startTime ?? '--:--'} to ${rule.endTime ?? '--:--'}"
                                            : (isLocationRule
                                                  ? "Location-based rule"
                                                  : "App trigger: $displayName"),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.secondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ACTIONS
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: rule.isEnabled,
                                      onChanged: (val) async {
                                        bool hasDndPermission =
                                            await DndService.isPermissionGranted();
                                        if (!hasDndPermission) {
                                          await DndService.openDndSettings();
                                          return;
                                        }

                                        if (val == true && isAppRule) {
                                          bool hasUsagePermission =
                                              await DndService.isUsagePermissionGranted();
                                          if (!hasUsagePermission) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please grant Usage Access to enable App triggers.',
                                                  ),
                                                ),
                                              );
                                            }
                                            await DndService.openUsageSettings();
                                            return;
                                          }
                                        }

                                        await database.updateRule(
                                          rule.copyWith(isEnabled: val),
                                        );
                                        automationManager.syncRulesToAndroid();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: colorScheme.secondary,
                                      onPressed: () => _showDeleteDialog(rule),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // 🔹 IF APP RULE: Dynamically fetch App Name and Icon
                    if (isAppRule) {
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: DndService.getAppInfo(rule.packageName ?? ''),
                        builder: (context, snapshot) {
                          // Extract Data
                          final String displayName =
                              snapshot.data?['name'] ??
                              rule.packageName ??
                              'Unknown App';
                          final Uint8List? iconBytes = snapshot.data?['icon'];

                          // Determine Icon Widget
                          final Widget dynamicIcon = (iconBytes != null)
                              ? Image.memory(iconBytes, width: 28, height: 28)
                              : Icon(
                                  Icons.apps,
                                  color: colorScheme.onPrimary,
                                  size: 28,
                                );

                          return buildRuleCard(displayName, dynamicIcon);
                        },
                      );
                    }

                    // 🔹 IF TIME OR LOCATION RULE: Render Normally
                    final Widget staticIcon = Icon(
                      isTimeRule ? Icons.access_time_filled : Icons.location_on,
                      color: colorScheme.onPrimary,
                      size: 28,
                    );
                    return buildRuleCard("", staticIcon);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RuleFormScreen()),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text("New Rule"),
      ),
    );
  }
}
