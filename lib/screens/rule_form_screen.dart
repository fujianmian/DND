import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import '../database/database.dart';
// Use a prefix to prevent the "Rule" name collision error
import '../models/rule.dart' as model;
import '../models/rule_trigger_values.dart';
import '../main.dart'; // Access global 'database'
import 'map_picker_screen.dart'; // Make sure this matches your map screen file name
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class RuleFormScreen extends StatefulWidget {
  // Drift's generated Rule class from database.dart
  final Rule? rule;

  const RuleFormScreen({super.key, this.rule});

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  late TextEditingController _nameController;
  late model.TriggerType _selectedType;

  // Time state
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Location state
  double? _latitude;
  double? _longitude;
  int? _radius;

  // App state
  String? _packageName;

  String? _activityType;
  final Map<String, String> _availableActivities = {
    'IN_VEHICLE': 'In Vehicle',
    'ON_BICYCLE': 'On Bicycle',
    'WALKING': 'Walking / On Foot',
    'RUNNING': 'Running',
    'STILL': 'Still / Not Moving',
    'TILTING': 'Tilting Device',
  };

  List<Map<String, dynamic>> _installedApps = [];
  bool _isLoadingApps = false;
  bool _allowStarredContacts = false;
  bool _allowRepeatCallers = false;

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
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTriggerTypeChange(model.TriggerType? val) async {
    if (val == null) return;

    if (val == model.TriggerType.app) {
      final bool hasPermission = await platform.invokeMethod(
        'checkUsagePermission',
      );
      if (!hasPermission) {
        _showPermissionDialog(
          "Usage Access Required",
          "To detect which app is running, please grant Usage Access.",
          () => platform.invokeMethod('openUsageSettings'),
        );
        return; // Stop here, don't change the UI state yet
      }
      if (_installedApps.isEmpty) {
        _fetchInstalledApps();
      }
    } else if (val == model.TriggerType.location) {
      var status = await Permission.location.request();
      if (!status.isGranted) {
        _showPermissionDialog(
          "Location Required",
          "To trigger DND by location, please grant Location permissions.",
          () => openAppSettings(), // Opens App Info settings
        );
        return;
      }
      // Note: For background geofencing, you might also need Permission.locationAlways
    } else if (val == model.TriggerType.activity) {
      var status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _showPermissionDialog(
          "Activity Recognition Required",
          "To trigger DND by physical activity, please grant Activity permissions.",
          () => openAppSettings(),
        );
        return;
      }
    }

    // If permissions are granted, update the UI
    setState(() => _selectedType = val);
  }

  @override
  void initState() {
    super.initState();
    // 1. Initialize data based on whether we are editing or creating
    _nameController = TextEditingController(text: widget.rule?.name ?? '');

    // Map the database integer (0, 1, or 2) back to our UI Enum
    if (widget.rule != null) {
      if (widget.rule!.type == 0) {
        _selectedType = model.TriggerType.time;
      } else if (widget.rule!.type == 1) {
        _selectedType = model.TriggerType.location;
      } else if (widget.rule!.type == 2) {
        _selectedType = model.TriggerType.app;
        _fetchInstalledApps();
      } else if (widget.rule!.type == 3) {
        _selectedType = model.TriggerType.activity;
      }
    } else {
      _selectedType = model.TriggerType.time;
    }

    // 2. Parse existing times if editing a Time Rule
    if (widget.rule?.startTime != null) {
      _startTime = _parseTimeString(widget.rule!.startTime!);
    }
    if (widget.rule?.endTime != null) {
      _endTime = _parseTimeString(widget.rule!.endTime!);
    }

    // 3. Load existing location data if editing a Location Rule
    if (widget.rule?.latitude != null && widget.rule?.longitude != null) {
      _latitude = widget.rule!.latitude;
      _longitude = widget.rule!.longitude;
      _radius = widget.rule!.radius;
    }

    // 4. Load existing app data if editing an App Rule
    if (widget.rule?.packageName != null) {
      _packageName = widget.rule!.packageName;
    }

    if (widget.rule?.activityType != null) {
      _activityType = widget.rule!.activityType;
    }

    _allowStarredContacts = widget.rule?.allowStarredContacts ?? false;
    _allowRepeatCallers = widget.rule?.allowRepeatCallers ?? false;
  }

  Future<void> _fetchInstalledApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final List<dynamic> apps = await platform.invokeMethod(
        'getInstalledApps',
      );
      setState(() {
        _installedApps = apps.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingApps = false;
      });
    } catch (e) {
      print("Failed to get apps: $e");
      setState(() => _isLoadingApps = false);
    }
  }

  // Helper to convert "HH:mm" or "h:mm a" back to TimeOfDay
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    final triggerError = _triggerValidationError();
    if (!_formKey.currentState!.validate() || triggerError != null) {
      if (triggerError != null) {
        _showSnackBar(triggerError);
      }
      return;
    }

    final name = _nameController.text.trim();

    final triggerValues = cleanedRuleTriggerValues(
      triggerType: _selectedType,
      startTime: _startTime?.format(context),
      endTime: _endTime?.format(context),
      latitude: _latitude,
      longitude: _longitude,
      radius: _radius,
      packageName: _packageName,
      activityType: _activityType,
    );

    if (widget.rule == null) {
      // CREATE NEW RULE
      await database.insertRule(
        RulesCompanion.insert(
          name: name,
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
    } else {
      // UPDATE EXISTING RULE
      await database.updateRule(
        widget.rule!.copyWith(
          name: name,
          type: triggerValues.type,
          startTime: triggerValues.startTime,
          endTime: triggerValues.endTime,
          latitude: triggerValues.latitude,
          longitude: triggerValues.longitude,
          radius: triggerValues.radius,
          packageName: triggerValues.packageName,
          activityType: triggerValues.activityType,
          allowStarredContacts: _allowStarredContacts,
          allowRepeatCallers: _allowRepeatCallers,
        ),
      );
    }

    // 🔴 FIX: Tell the Android Service the rules have changed!
    await automationManager.syncRulesToAndroid();

    if (mounted) Navigator.pop(context);
  }

  String? _triggerValidationError() {
    switch (_selectedType) {
      case model.TriggerType.time:
        if (_startTime == null || _endTime == null) {
          return 'Please select start and end times.';
        }
        return null;
      case model.TriggerType.location:
        if (_latitude == null || _longitude == null || _radius == null) {
          return 'Please select a location and radius.';
        }
        if (_radius! <= 0) {
          return 'Please select a radius greater than 0.';
        }
        return null;
      case model.TriggerType.app:
        if (_packageName == null || _packageName!.trim().isEmpty) {
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _deleteRule() async {
    if (widget.rule != null) {
      await database.deleteRule(widget.rule!);

      // 🔴 FIX: Sync deletion to Android Service
      await automationManager.syncRulesToAndroid();

      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          // Pass the existing values if they exist
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Rule' : 'New Rule'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rule Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<model.TriggerType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Trigger Type'),
              items: model.TriggerType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: _handleTriggerTypeChange,
            ),
            const SizedBox(height: 20),

            if (_selectedType == model.TriggerType.time) ...[
              const Text(
                "Schedule Configuration",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.start),
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
                      leading: const Icon(Icons.outbond),
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
                ),
              ),
            ] else if (_selectedType == model.TriggerType.location) ...[
              const Text(
                "Location Configuration",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.map, color: Colors.blue),
                        title: Text(
                          _latitude == null || _longitude == null
                              ? 'Tap to select a location'
                              : 'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
                        ),
                        subtitle: _radius != null
                            ? Text('Radius: ${_radius}m')
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _selectLocationOnMap,
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_selectedType == model.TriggerType.app) ...[
              const Text(
                "App Configuration",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: _isLoadingApps
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : DropdownButtonFormField<String>(
                        value:
                            _installedApps.any(
                              (app) => app['package'] == _packageName,
                            )
                            ? _packageName
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select App to Trigger DND',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        items: _installedApps.map((app) {
                          // 🔹 Extract the Icon bytes
                          final Uint8List? iconBytes =
                              app['icon'] as Uint8List?;

                          return DropdownMenuItem<String>(
                            value: app['package'] as String,
                            child: Row(
                              children: [
                                // 🔹 Display the image, or a default icon if missing
                                if (iconBytes != null)
                                  Image.memory(iconBytes, width: 26, height: 26)
                                else
                                  const Icon(
                                    Icons.android,
                                    size: 26,
                                    color: Colors.green,
                                  ),

                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    app['name'] as String,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _packageName = val),
                        validator: (v) =>
                            (_selectedType == model.TriggerType.app &&
                                (v == null || v.isEmpty))
                            ? 'Please select an application'
                            : null,
                      ),
              ),
            ] else if (_selectedType == model.TriggerType.activity) ...[
              const Text(
                "Activity Configuration",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String>(
                    value: _activityType,
                    decoration: const InputDecoration(
                      labelText: 'Select an Activity',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(8),
                    ),
                    items: _availableActivities.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _activityType = val),
                    validator: (v) =>
                        (_selectedType == model.TriggerType.activity &&
                            (v == null || v.isEmpty))
                        ? 'Please select an activity'
                        : null,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            _buildExceptionControls(),

            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _saveRule,
              child: Text(isEditing ? 'UPDATE RULE' : 'SAVE RULE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Exceptions", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          "These exceptions will apply when this rule activates Do Not Disturb.",
          style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Allow starred contacts"),
                value: _allowStarredContacts,
                onChanged: (val) => setState(() => _allowStarredContacts = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("Allow repeat callers"),
                subtitle: const Text("If they call twice in 15 mins"),
                value: _allowRepeatCallers,
                onChanged: (val) => setState(() => _allowRepeatCallers = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Rule?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRule();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
