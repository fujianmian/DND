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
  // Helper to show the delete confirmation dialog
  void _showDeleteDialog(Rule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Rule?"),
        content: Text("Are you sure you want to remove '${rule.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await database.deleteRule(rule);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DND Automation')),
      body: Column(
        children: [
          // --- TEST PANEL (Kept for MVP) ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.withOpacity(0.1),
            child: Column(
              children: [
                const Text(
                  "Native DND Test Panel",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => DndService.enableDnd(),
                      icon: const Icon(Icons.do_not_disturb_on),
                      label: const Text("Enable"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => DndService.disableDnd(),
                      icon: const Icon(Icons.do_not_disturb_off),
                      label: const Text("Disable"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- ENHANCED RULE LIST ---
          Expanded(
            child: StreamBuilder<List<Rule>>(
              stream: database.watchAllRules(),
              builder: (context, snapshot) {
                final rules = snapshot.data ?? [];

                if (rules.isEmpty) {
                  return const Center(child: Text('No rules yet.'));
                }

                return ListView.builder(
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        // 1. TAP TO EDIT
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RuleFormScreen(rule: rule),
                          ),
                        ),
                        title: Text(
                          rule.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rule.type == 0
                                  ? "🕒 Time Rule"
                                  : "📍 Location Rule",
                            ),
                            if (rule.type == 0 &&
                                rule.startTime != null &&
                                rule.endTime != null)
                              Text(
                                "${rule.startTime} - ${rule.endTime}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 2. TOGGLE SWITCH
                            Switch(
                              value: rule.isEnabled,
                              onChanged: (val) async {
                                bool hasPermission =
                                    await DndService.isPermissionGranted();
                                if (!hasPermission) {
                                  await DndService.openDndSettings();
                                  return;
                                }
                                database.updateRule(
                                  rule.copyWith(isEnabled: val),
                                );
                                if (val) {
                                  await DndService.enableDnd();
                                } else {
                                  await DndService.disableDnd();
                                }
                              },
                            ),
                            // 3. DELETE BUTTON
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _showDeleteDialog(rule),
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RuleFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
