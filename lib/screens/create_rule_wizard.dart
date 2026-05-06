import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CreateRuleWizard extends StatefulWidget {
  const CreateRuleWizard({Key? key}) : super(key: key);

  @override
  _CreateRuleWizardState createState() => _CreateRuleWizardState();
}

class _CreateRuleWizardState extends State<CreateRuleWizard> {
  int _currentStep = 0;
  String logicMode = 'AND';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Rule')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2)
            setState(() => _currentStep += 1);
          else
            Navigator.pop(context);
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep -= 1);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 2 ? 'Save Rule' : 'Continue'),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: AppTheme.pureBlack.withOpacity(0.6),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text(
              'Name your rule',
              style: TextStyle(color: AppTheme.pureBlack),
            ),
            content: TextFormField(
              style: const TextStyle(color: AppTheme.pureBlack),
              decoration: InputDecoration(
                hintText: 'e.g., Deep Work',
                hintStyle: TextStyle(
                  color: AppTheme.pureBlack.withOpacity(0.3),
                ),
                filled: true,
                fillColor: AppTheme.pureWhite,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.pureBlack.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.logoBlue),
                ),
              ),
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text(
              'Set Triggers',
              style: TextStyle(color: AppTheme.pureBlack),
            ),
            content: _buildVisualBuilder(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text(
              'Exceptions & Actions',
              style: TextStyle(color: AppTheme.pureBlack),
            ),
            content: _buildActionExceptions(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.pureBlack.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Chip(
                label: const Text(
                  'Location: Office',
                  style: TextStyle(color: AppTheme.pureBlack),
                ),
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.pureBlack,
                ),
                onDeleted: () {},
                backgroundColor: AppTheme.logoCyan.withOpacity(0.2),
                side: BorderSide.none,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: logicMode,
                    dropdownColor: AppTheme.pureWhite,
                    items: ['AND', 'OR']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.logoPurple,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => logicMode = val!),
                  ),
                ),
              ),
              Chip(
                label: const Text(
                  'Time: Weekdays 9-5',
                  style: TextStyle(color: AppTheme.pureBlack),
                ),
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.pureBlack,
                ),
                onDeleted: () {},
                backgroundColor: AppTheme.logoCyan.withOpacity(0.2),
                side: BorderSide.none,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, color: AppTheme.logoBlue),
          label: const Text(
            'Add Trigger',
            style: TextStyle(color: AppTheme.logoBlue),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.logoBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildActionExceptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text(
            'Allow Favorite Contacts',
            style: TextStyle(color: AppTheme.pureBlack),
          ),
          value: true,
          onChanged: (val) {},
        ),
        SwitchListTile(
          title: const Text(
            'Allow Repeat Callers',
            style: TextStyle(color: AppTheme.pureBlack),
          ),
          subtitle: Text(
            'If they call twice in 15 mins',
            style: TextStyle(color: AppTheme.pureBlack.withOpacity(0.6)),
          ),
          value: false,
          onChanged: (val) {},
        ),
      ],
    );
  }
}
