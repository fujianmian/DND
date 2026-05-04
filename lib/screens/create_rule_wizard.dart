import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CreateRuleWizard extends StatefulWidget {
  const CreateRuleWizard({Key? key}) : super(key: key);

  @override
  _CreateRuleWizardState createState() => _CreateRuleWizardState();
}

class _CreateRuleWizardState extends State<CreateRuleWizard> {
  int _currentStep = 0;

  // MOCKED STATE
  List<String> selectedTriggers = ['Location: Office'];
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
            Navigator.pop(context); // MOCKED: Save rule
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
                    child: const Text(
                      'Back',
                      style: TextStyle(color: AppTheme.mutedText),
                    ),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Name your rule'),
            content: TextFormField(
              decoration: InputDecoration(
                hintText: 'e.g., Deep Work',
                filled: true,
                fillColor: AppTheme.surfaceWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Set Triggers (Visual Builder)'),
            content: _buildVisualBuilder(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Exceptions & Actions'),
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
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Chip(
                label: const Text('Location: Office'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {},
                backgroundColor: AppTheme.lavenderGlow.withOpacity(0.4),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: logicMode,
                    items: ['AND', 'OR']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.electricBlue,
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
                label: const Text('Time: Weekdays 9-5'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {},
                backgroundColor: AppTheme.lavenderGlow.withOpacity(0.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            /* MOCK: Show Trigger Bottom Sheet */
          },
          icon: const Icon(Icons.add, color: AppTheme.royalViolet),
          label: const Text(
            'Add Trigger',
            style: TextStyle(color: AppTheme.royalViolet),
          ),
        ),
      ],
    );
  }

  Widget _buildActionExceptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Allow Favorite Contacts'),
          value: true,
          onChanged: (val) {
            /* Mock Backend */
          },
          activeColor: AppTheme.royalViolet,
        ),
        SwitchListTile(
          title: const Text('Allow Repeat Callers'),
          subtitle: const Text('If they call twice in 15 mins'),
          value: false,
          onChanged: (val) {
            /* Mock Backend */
          },
          activeColor: AppTheme.royalViolet,
        ),
      ],
    );
  }
}
