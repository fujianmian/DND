import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database.dart';
import '../main.dart';
import '../models/rule.dart' as model;
import '../models/rule_trigger_values.dart';
import '../services/app_catalog.dart';
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';

class CreateRuleWizard extends StatefulWidget {
  const CreateRuleWizard({super.key});

  @override
  State<CreateRuleWizard> createState() => _CreateRuleWizardState();
}

class _CreateRuleWizardState extends State<CreateRuleWizard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  int _currentStep = 0;
  model.TriggerType? _selectedType;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  double? _latitude;
  double? _longitude;
  int? _radius;

  String? _packageName;
  List<AppCatalogEntry> _installedApps = [];
  bool _isLoadingApps = false;
  bool _isSaving = false;

  bool _allowStarredContacts = false;
  bool _allowRepeatCallers = false;

  String? _activityType;
  final Map<String, String> _availableActivities = {
    'IN_VEHICLE': 'In Vehicle',
    'ON_BICYCLE': 'On Bicycle',
    'WALKING': 'Walking / On Foot',
    'RUNNING': 'Running',
    'STILL': 'Still / Not Moving',
    'TILTING': 'Tilting Device',
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Rule')),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _handleContinue,
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep -= 1);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == 2 ? 'Save Rule' : 'Continue'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _isSaving ? null : details.onStepCancel,
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: AppTheme.pureBlack.withValues(alpha: 0.6),
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
                controller: _nameController,
                style: const TextStyle(color: AppTheme.pureBlack),
                decoration: _inputDecoration('e.g., Deep Work'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a rule name';
                  }
                  return null;
                },
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text(
                'Choose one trigger type',
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
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.3)),
      filled: true,
      fillColor: AppTheme.pureWhite,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.pureBlack.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.logoBlue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _buildVisualBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.pureBlack.withValues(alpha: 0.1),
            ),
          ),
          child: _selectedType == null
              ? Text(
                  'Choose one trigger type.',
                  style: TextStyle(
                    color: AppTheme.pureBlack.withValues(alpha: 0.6),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(
                          _triggerSummary(),
                          style: const TextStyle(color: AppTheme.pureBlack),
                        ),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppTheme.pureBlack,
                        ),
                        onDeleted: _clearTrigger,
                        backgroundColor: AppTheme.logoCyan.withValues(
                          alpha: 0.2,
                        ),
                        side: BorderSide.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTriggerConfiguration(),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _showTriggerTypePicker,
          icon: const Icon(Icons.add, color: AppTheme.logoBlue),
          label: Text(
            _selectedType == null ? 'Choose Trigger' : 'Change Trigger',
            style: const TextStyle(color: AppTheme.logoBlue),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.logoBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerConfiguration() {
    switch (_selectedType) {
      case model.TriggerType.time:
        return _buildTimeConfiguration();
      case model.TriggerType.location:
        return _buildLocationConfiguration();
      case model.TriggerType.app:
        return _buildAppConfiguration();
      case model.TriggerType.activity:
        return _buildActivityConfiguration();
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeConfiguration() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule, color: AppTheme.logoBlue),
          title: Text(
            _startTime == null
                ? 'Select Start Time'
                : 'Starts at: ${_startTime!.format(context)}',
          ),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _startTime ?? TimeOfDay.now(),
            );
            if (time != null) setState(() => _startTime = time);
          },
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timelapse, color: AppTheme.logoPurple),
          title: Text(
            _endTime == null
                ? 'Select End Time'
                : 'Ends at: ${_endTime!.format(context)}',
          ),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _endTime ?? TimeOfDay.now(),
            );
            if (time != null) setState(() => _endTime = time);
          },
        ),
      ],
    );
  }

  Widget _buildLocationConfiguration() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.map, color: AppTheme.logoBlue),
      title: Text(
        _latitude == null
            ? 'Tap to select a location'
            : 'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
      ),
      subtitle: _radius == null
          ? null
          : Text(
              _radius! < 100
                  ? 'Radius: ${_radius}m - 100m+ recommended for reliability'
                  : 'Radius: ${_radius}m',
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectLocationOnMap,
    );
  }

  Widget _buildAppConfiguration() {
    if (_isLoadingApps) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(_packageName),
      initialValue: _installedApps.any((app) => app.packageName == _packageName)
          ? _packageName
          : null,
      isExpanded: true,
      decoration: _inputDecoration('Select App to Trigger DND'),
      items: _installedApps.map((app) {
        final Uint8List? iconBytes = app.iconBytes;
        return DropdownMenuItem<String>(
          value: app.packageName,
          child: Row(
            children: [
              if (iconBytes != null)
                Image.memory(iconBytes, width: 26, height: 26)
              else
                const Icon(Icons.android, size: 26, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(child: Text(app.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _packageName = val),
    );
  }

  Widget _buildActivityConfiguration() {
    return DropdownButtonFormField<String>(
      key: ValueKey(_activityType),
      initialValue: _activityType,
      decoration: _inputDecoration('Select an Activity'),
      items: _availableActivities.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _activityType = val),
    );
  }

  Widget _buildActionExceptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'These exceptions will apply when this rule activates Do Not Disturb.',
          style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text(
            'Allow starred contacts',
            style: TextStyle(color: AppTheme.pureBlack),
          ),
          value: _allowStarredContacts,
          onChanged: (val) => setState(() => _allowStarredContacts = val),
        ),
        SwitchListTile(
          title: const Text(
            'Allow repeat callers',
            style: TextStyle(color: AppTheme.pureBlack),
          ),
          subtitle: Text(
            'If they call twice in 15 mins',
            style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.6)),
          ),
          value: _allowRepeatCallers,
          onChanged: (val) => setState(() => _allowRepeatCallers = val),
        ),
      ],
    );
  }

  Future<void> _handleContinue() async {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
      return;
    }

    if (_currentStep == 1) {
      final error = _triggerValidationError();
      if (error != null) {
        _showSnackBar(error);
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    await _saveRule();
  }

  Future<void> _showTriggerTypePicker() async {
    final type = await showModalBottomSheet<model.TriggerType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: model.TriggerType.values.map((type) {
              return ListTile(
                leading: Icon(_triggerIcon(type), color: AppTheme.logoBlue),
                title: Text(_triggerTitle(type)),
                onTap: () => Navigator.pop(context, type),
              );
            }).toList(),
          ),
        );
      },
    );

    await _handleTriggerTypeChange(type);
  }

  Future<void> _handleTriggerTypeChange(model.TriggerType? val) async {
    if (val == null) return;

    if (val == model.TriggerType.app) {
      final bool hasPermission = await platform.invokeMethod(
        'checkUsagePermission',
      );
      if (!hasPermission) {
        _showPermissionDialog(
          'Usage Access Required',
          'To detect which app is running, please grant Usage Access.',
          () => platform.invokeMethod('openUsageSettings'),
        );
        return;
      }
      if (_installedApps.isEmpty) {
        await _fetchInstalledApps();
      }
    } else if (val == model.TriggerType.location) {
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return;
    } else if (val == model.TriggerType.activity) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _showPermissionDialog(
          'Activity Recognition Required',
          'To trigger DND by physical activity, please grant Activity permissions.',
          () => openAppSettings(),
        );
        return;
      }
    }

    setState(() => _selectedType = val);
  }

  Future<void> _fetchInstalledApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final apps = await appCatalog.loadInstalledApps();
      if (!mounted) return;
      setState(() {
        _installedApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      debugPrint('Failed to get apps: $e');
      if (mounted) setState(() => _isLoadingApps = false);
    }
  }

  Future<void> _selectLocationOnMap() async {
    final hasLocationPermission = await _ensureForegroundLocationPermission();
    if (!hasLocationPermission) return;
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialRadius: _radius?.toDouble(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _radius = result['radius'];
      });
    }
  }

  Future<void> _saveRule() async {
    final error = _triggerValidationError();
    if (!_formKey.currentState!.validate() || error != null) {
      _showSnackBar(error ?? 'Please complete the rule name.');
      return;
    }

    if (_selectedType == model.TriggerType.location) {
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return;

      final hasBackgroundLocation =
          await _ensureBackgroundLocationForActiveRule();
      if (!hasBackgroundLocation) return;
      if (!mounted) return;
    }

    setState(() => _isSaving = true);
    try {
      final triggerValues = cleanedRuleTriggerValues(
        triggerType: _selectedType!,
        startTime: _startTime?.format(context),
        endTime: _endTime?.format(context),
        latitude: _latitude,
        longitude: _longitude,
        radius: _radius,
        packageName: _packageName,
        activityType: _activityType,
      );

      await database.insertRule(
        RulesCompanion.insert(
          name: _nameController.text.trim(),
          type: triggerValues.type,
          isEnabled: const d.Value(true),
          startTime: triggerValues.startTime,
          endTime: triggerValues.endTime,
          latitude: triggerValues.latitude,
          longitude: triggerValues.longitude,
          radius: triggerValues.radius,
          packageName: triggerValues.packageName,
          activityType: triggerValues.activityType,
          allowStarredContacts: d.Value(_allowStarredContacts),
          allowRepeatCallers: d.Value(_allowRepeatCallers),
        ),
      );

      await automationManager.syncRulesToAndroid();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPermissionDialog(
    String title,
    String content,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureForegroundLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isGranted) return true;

    status = await Permission.location.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    _showPermissionDialog(
      'Location Permission Needed',
      'Allow location access to choose places for location rules.',
      () => openAppSettings(),
    );
    return false;
  }

  Future<bool> _ensureBackgroundLocationForActiveRule() async {
    var status = await Permission.locationAlways.status;
    if (status.isGranted) return true;

    status = await Permission.locationAlways.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    _showPermissionDialog(
      'Background Location Needed',
      'Allow all-the-time location so this rule can activate when Quietly is not open.',
      () => openAppSettings(),
    );
    return false;
  }

  void _clearTrigger() {
    setState(() {
      _selectedType = null;
      _startTime = null;
      _endTime = null;
      _latitude = null;
      _longitude = null;
      _radius = null;
      _packageName = null;
      _activityType = null;
    });
  }

  String? _triggerValidationError() {
    switch (_selectedType) {
      case null:
        return 'Please choose one trigger type.';
      case model.TriggerType.time:
        if (_startTime == null || _endTime == null) {
          return 'Please select start and end times.';
        }
        return null;
      case model.TriggerType.location:
        if (_latitude == null || _longitude == null || _radius == null) {
          return 'Please select a location and radius.';
        }
        if (_radius! < 50) {
          return 'Please select a radius of at least 50m.';
        }
        return null;
      case model.TriggerType.app:
        if (_packageName == null || _packageName!.isEmpty) {
          return 'Please select an application.';
        }
        return null;
      case model.TriggerType.activity:
        if (_activityType == null || _activityType!.isEmpty) {
          return 'Please select an activity.';
        }
        return null;
    }
  }

  String _triggerSummary() {
    switch (_selectedType) {
      case model.TriggerType.time:
        final start = _startTime?.format(context) ?? '--';
        final end = _endTime?.format(context) ?? '--';
        return 'Time: $start - $end';
      case model.TriggerType.location:
        if (_radius == null) return 'Location';
        final recommendation = _radius! < 100 ? ' (100m+ recommended)' : '';
        return 'Location: ${_radius}m radius$recommendation';
      case model.TriggerType.app:
        return 'App: ${_selectedAppName() ?? 'Select app'}';
      case model.TriggerType.activity:
        return 'Activity: ${_availableActivities[_activityType] ?? 'Select activity'}';
      case null:
        return 'Trigger';
    }
  }

  String? _selectedAppName() {
    if (_packageName == null || _packageName!.isEmpty) return null;
    return appCatalog.labelFor(_packageName);
  }

  IconData _triggerIcon(model.TriggerType type) {
    switch (type) {
      case model.TriggerType.time:
        return Icons.schedule;
      case model.TriggerType.location:
        return Icons.location_on_outlined;
      case model.TriggerType.app:
        return Icons.apps;
      case model.TriggerType.activity:
        return Icons.directions_walk;
    }
  }

  String _triggerTitle(model.TriggerType type) {
    switch (type) {
      case model.TriggerType.time:
        return 'Time';
      case model.TriggerType.location:
        return 'Location';
      case model.TriggerType.app:
        return 'App';
      case model.TriggerType.activity:
        return 'Activity';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
