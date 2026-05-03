import 'package:flutter/material.dart';
import 'rule_builder_screen.dart';
// import '../services/automation_manager.dart';

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({Key? key}) : super(key: key);

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  // Mock data representing your models/rule.dart
  List<Map<String, dynamic>> rules = [
    {
      "name": "Work Focus",
      "status": true,
      "triggers": ["Office", "AND", "Weekday"],
    },
    {
      "name": "Driving Mode",
      "status": false,
      "triggers": ["Driving", "OR", "Bluetooth: Car"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Rules"), centerTitle: false),
      body: rules.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rule['name'],
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Switch(
                              value: rule['status'],
                              onChanged: (val) {
                                setState(() => rule['status'] = val);
                                // TODO: backend havent implement - Update rule status in database
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: (rule['triggers'] as List<String>).map((
                            trigger,
                          ) {
                            if (trigger == "AND" || trigger == "OR") {
                              return Text(
                                trigger,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return Chip(
                              label: Text(trigger),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RuleBuilderScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text("Create Rule"),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: Theme.of(context).colorScheme.outlineOpacity,
          ),
          const SizedBox(height: 16),
          const Text("No rules yet."),
          const Text("Create a rule to automate your focus."),
        ],
      ),
    );
  }
}
