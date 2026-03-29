import 'package:flutter/material.dart';
// import '../models/rule.dart';
import 'rule_form_screen.dart';

import '../database/database.dart';
import '../main.dart'; // To access the global 'database'

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({super.key});

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DND Automation')),
      body: StreamBuilder<List<Rule>>(
        // 1. Use StreamBuilder
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
                child: ListTile(
                  title: Text(rule.name),
                  subtitle: Text(
                    rule.type == 0 ? "Time Rule" : "Location Rule",
                  ),
                  trailing: Switch(
                    value: rule.isEnabled,
                    onChanged: (val) {
                      // 2. Update DB directly
                      database.updateRule(rule.copyWith(isEnabled: val));
                    },
                  ),
                ),
              );
            },
          );
        },
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
