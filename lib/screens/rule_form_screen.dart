import 'package:flutter/material.dart';

class RuleFormScreen extends StatefulWidget {
  const RuleFormScreen({super.key});

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  // --- Mock State for Rule Builder ---
  String _ruleName = '';
  IconData _selectedIcon = Icons.tune;

  // Outer list = OR groups. Inner list = AND conditions.
  // Pre-filled with one empty condition to show the UI
  final List<List<String>> _triggerGroups = [
    ['Geofencing: Office'],
  ];

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Save Rule Logic Here
      Navigator.pop(context);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Rule'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Minimalist Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(
                0.3,
              ),
              color: colorScheme.primary,
              minHeight: 2,
            ),
            const SizedBox(height: 16),

            // Step Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Step ${_currentStep + 1} of $_totalSteps',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Wizard Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Force button navigation
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildStep1BasicInfo(colorScheme),
                  _buildStep2LogicEngine(colorScheme),
                  _buildStep3Actions(colorScheme),
                ],
              ),
            ),

            // Bottom Navigation Area
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _prevStep,
                    child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                  ),
                  FilledButton(
                    onPressed: _nextStep,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      _currentStep == _totalSteps - 1
                          ? 'Save Rule'
                          : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 1: BASIC INFO
  // ===========================================================================
  Widget _buildStep1BasicInfo(ColorScheme colorScheme) {
    final List<IconData> icons = [
      Icons.tune,
      Icons.work_outline,
      Icons.home_outlined,
      Icons.directions_car_outlined,
      Icons.nightlight_round,
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Name your rule',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Give it a clear name so you know exactly what it does.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Rule Name',
            hintText: 'e.g., Deep Work, Commute',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          onChanged: (val) => _ruleName = val,
        ),
        const SizedBox(height: 32),
        Text('Select an icon', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: icons.map((icon) {
            final isSelected = _selectedIcon == icon;
            return ChoiceChip(
              label: Icon(
                icon,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: colorScheme.primary,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
              onSelected: (selected) {
                if (selected) setState(() => _selectedIcon = icon);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 2: LOGIC ENGINE (TRIGGERS)
  // ===========================================================================
  Widget _buildStep2LogicEngine(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'When should this activate?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Combine triggers to create perfect context awareness.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),

        ..._triggerGroups.asMap().entries.map((entry) {
          int groupIndex = entry.key;
          List<String> conditions = entry.value;

          return Column(
            children: [
              if (groupIndex > 0) _buildOrDivider(colorScheme),
              _buildAndCard(conditions, groupIndex, colorScheme),
            ],
          );
        }),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _triggerGroups.add(['Activity: Driving']); // Mock addition
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Alternative Condition'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAndCard(
    List<String> conditions,
    int groupIndex,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...conditions.asMap().entries.map((entry) {
            int condIndex = entry.key;
            return Column(
              children: [
                if (condIndex > 0) _buildAndDivider(colorScheme),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(entry.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        // Handle remove logic
                      },
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),

          // Trigger Selector Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _triggerGroups[groupIndex].add(value);
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Geofencing',
                child: Text('📍 Geofencing'),
              ),
              const PopupMenuItem(
                value: 'Activity',
                child: Text('🏃 Activity'),
              ),
              const PopupMenuItem(
                value: 'Calendar',
                child: Text('📅 Calendar Event'),
              ),
              const PopupMenuItem(
                value: 'App Usage',
                child: Text('📱 App Opened'),
              ),
            ],
            child: TextButton.icon(
              onPressed: null, // Let PopupMenuButton handle the tap
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Condition'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndDivider(ColorScheme colorScheme) {
    return Column(
      children: [
        Container(width: 1, height: 12, color: colorScheme.outlineVariant),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'AND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Container(width: 1, height: 12, color: colorScheme.outlineVariant),
      ],
    );
  }

  Widget _buildOrDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR',
              style: TextStyle(
                color: colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 3: ACTIONS
  // ===========================================================================
  Widget _buildStep3Actions(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'What should happen?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Define the system state when this rule is active.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),

        SwitchListTile(
          value: true,
          onChanged: (val) {},
          title: const Text('Enable Do Not Disturb'),
          subtitle: const Text('Blocks notifications and calls'),
          secondary: const Icon(Icons.do_not_disturb_on_outlined),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: false,
          onChanged: (val) {},
          title: const Text('Set Ringer to Vibrate'),
          secondary: const Icon(Icons.vibration),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
      ],
    );
  }
}
