import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'create_rule_wizard.dart'; // New Wizard screen

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({Key? key}) : super(key: key);

  @override
  _RuleListScreenState createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  // MOCKED DATA: Replace with Database call
  List<Map<String, dynamic>> dummyRules = [
    {
      'name': 'Office Focus',
      'isActive': true,
      'triggers': ['Location: Office', 'Time: Weekdays'],
      'logic': 'AND',
    },
    {
      'name': 'Driving Mode',
      'isActive': false,
      'triggers': ['Activity: Driving', 'Bluetooth: Car'],
      'logic': 'OR',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rules')),
      body: dummyRules.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dummyRules.length,
              itemBuilder: (context, index) {
                final rule = dummyRules[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rule['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryText,
                              ),
                            ),
                            Switch(
                              value: rule['isActive'],
                              activeColor: AppTheme.royalViolet,
                              onChanged: (val) {
                                setState(() => rule['isActive'] = val);
                                // TODO: Update in database
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildChip(rule['triggers'][0]),
                            Text(
                              rule['logic'],
                              style: const TextStyle(
                                color: AppTheme.electricBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            _buildChip(rule['triggers'][1]),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRuleWizard()),
          );
        },
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.offWhiteBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: AppTheme.lavenderGlow),
          SizedBox(height: 16),
          Text(
            'No rules yet',
            style: TextStyle(fontSize: 20, color: AppTheme.primaryText),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to automate your peace of mind.',
            style: TextStyle(color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}
