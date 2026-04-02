// lib/screens/rule_list_screen.dart
import 'package:flutter/material.dart';
import 'rule_form_screen.dart';
import '../database/database.dart';
import '../main.dart';
import '../services/dnd_service.dart';

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({super.key});

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  // --- NEW: Helper methods to parse TimeOfDay for Kotlin ---
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      var hour = int.parse(parts[0]);
      final minuteParts = parts[1].split(' ');
      final minute = int.parse(minuteParts[0]);

      if (timeStr.contains('PM') && hour != 12) hour += 12;
      if (timeStr.contains('AM') && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, int>> _convertRulesForNative(List<Rule> allRules) {
    List<Map<String, int>> mappedRules = [];
    for (var rule in allRules) {
      // Only send ENABLED time-based rules
      if (rule.isEnabled &&
          rule.type == 0 &&
          rule.startTime != null &&
          rule.endTime != null) {
        final start = _parseTimeString(rule.startTime!);
        final end = _parseTimeString(rule.endTime!);
        if (start != null && end != null) {
          mappedRules.add({
            'startHour': start.hour,
            'startMinute': start.minute,
            'endHour': end.hour,
            'endMinute': end.minute,
          });
        }
      }
    }
    return mappedRules;
  }

  void _showDeleteDialog(Rule rule) {
    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: colorScheme.secondary),
              ),
            ),
            FilledButton(
              onPressed: () async {
                await database.deleteRule(rule);
                if (mounted) Navigator.pop(context);
              },
              // ✅ LIGHT background means we force DARK text
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
                color: colorScheme.surface, // Dark background
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.toggle_on,
                        color: colorScheme.primary,
                      ), // Light icon on dark background
                      const SizedBox(width: 8),
                      Text(
                        "Manual Override",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme
                              .primary, // Light text on dark background
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
                          // ✅ LIGHT background means we force DARK text/icon
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
                          // Outlined button uses dark background, so text is secondary
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
              // 1. Fetch all current rules from Drift database
              final allRules = await database.select(database.rules).get();
              // 2. Convert them
              final mappedRules = _convertRulesForNative(allRules);
              // 3. Start service with dynamic rules
              await DndService().startForegroundService(mappedRules);
            },
            child: const Text("Start Background Automation"),
          ),

          // ElevatedButton(
          //   onPressed: () async {
          //     await DndService().stopForegroundService();
          //   },
          //   child: Text("Stop Background Automation"),
          // ),

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

                    return Card(
                      // Uses the dark Surface color from global theme
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
                                  color:
                                      colorScheme.primary, // ✅ Light Background
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isTimeRule
                                      ? Icons.access_time_filled
                                      : Icons.location_on,
                                  color: colorScheme.onPrimary, // ✅ Dark Icon
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // TEXT INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rule.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme
                                            .primary, // Light text on dark card
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isTimeRule
                                          ? "${rule.startTime ?? '--:--'} to ${rule.endTime ?? '--:--'}"
                                          : "Location-based rule",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme
                                            .secondary, // Secondary grey text
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
                                      bool hasPermission =
                                          await DndService.isPermissionGranted();
                                      if (!hasPermission) {
                                        await DndService.openDndSettings();
                                        return;
                                      }

                                      // 1. Update the database
                                      await database.updateRule(
                                        rule.copyWith(isEnabled: val),
                                      );

                                      // 2. Fetch the newly updated list of rules
                                      final allRules = await database
                                          .select(database.rules)
                                          .get();
                                      final mappedRules =
                                          _convertRulesForNative(allRules);

                                      // 3. Push the fresh rules to the running Kotlin Service
                                      await DndService().updateForegroundRules(
                                        mappedRules,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: colorScheme
                                        .secondary, // Secondary grey icon
                                    onPressed: () => _showDeleteDialog(rule),
                                  ),
                                ],
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
          ),
        ],
      ),
      // FAB automatically uses Accent (Light) background with Dark icon based on our main.dart theme, but we can explicitly set it here to be safe
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RuleFormScreen()),
        ),
        backgroundColor: colorScheme.primary, // Light Accent
        foregroundColor: colorScheme.onPrimary, // Dark Text/Icon
        icon: const Icon(Icons.add),
        label: const Text("New Rule"),
      ),
    );
  }
}
