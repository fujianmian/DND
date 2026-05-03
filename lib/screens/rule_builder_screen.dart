import 'package:flutter/material.dart';

class RuleBuilderScreen extends StatefulWidget {
  const RuleBuilderScreen({Key? key}) : super(key: key);

  @override
  State<RuleBuilderScreen> createState() => _RuleBuilderScreenState();
}

class _RuleBuilderScreenState extends State<RuleBuilderScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Rule")),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2)
            setState(() => _currentStep++);
          else {
            // TODO: backend havent implement - Save new rule to database via AutomationManager
            Navigator.pop(context);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        steps: [
          Step(
            title: const Text("Name your rule"),
            content: TextField(
              decoration: InputDecoration(
                hintText: "e.g., Library Study",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text("Set Triggers (When...)"),
            content: _buildVisualLogicBuilder(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text("Set Actions (Then...)"),
            content: _buildActionBuilder(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  // The visual block builder preventing "Developer style" UI
  Widget _buildVisualLogicBuilder() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: BorderSide(color: theme.colorScheme.secondaryContainer),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18),
                  const SizedBox(width: 8),
                  const Text("Location: Office"),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {},
                  ),
                ],
              ),
              Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilterChip(
                    label: const Text("AND"),
                    selected: true,
                    onSelected: (v) {},
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text("OR"),
                    selected: false,
                    onSelected: (v) {},
                  ),
                ],
              ),
              Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18),
                  const SizedBox(width: 8),
                  const Text("Time: 9AM - 5PM"),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: backend havent implement - Open trigger selection modal (Time/Location/Activity)
          },
          icon: const Icon(Icons.add),
          label: const Text("Add Condition"),
        ),
      ],
    );
  }

  Widget _buildActionBuilder() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Enable Do Not Disturb"),
          trailing: Switch(value: true, onChanged: (v) {}),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Allow Exceptions"),
          subtitle: const Text("Favorite Contacts, Alarms"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: backend havent implement - Open DND Exceptions mapping screen
          },
        ),
      ],
    );
  }
}
