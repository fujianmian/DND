import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import '../database/database.dart';
// Use a prefix to prevent the "Rule" name collision error
import '../models/rule.dart' as model;
import '../main.dart'; // Access global 'database'
import 'map_picker_screen.dart'; // Make sure this matches your map screen file name

class RuleFormScreen extends StatefulWidget {
  // Drift's generated Rule class from database.dart
  final Rule? rule;

  const RuleFormScreen({super.key, this.rule});

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late model.TriggerType _selectedType;

  // Time state
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Location state
  double? _latitude;
  double? _longitude;
  int? _radius;

  @override
  void initState() {
    super.initState();
    // 1. Initialize data based on whether we are editing or creating
    _nameController = TextEditingController(text: widget.rule?.name ?? '');

    // Map the database integer (0 or 1) back to our UI Enum
    _selectedType = widget.rule != null
        ? (widget.rule!.type == 0
              ? model.TriggerType.time
              : model.TriggerType.location)
        : model.TriggerType.time;

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
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final typeInt = _selectedType == model.TriggerType.time ? 0 : 1;

      // Formatting time to string for database storage
      final startTimeStr = _startTime?.format(context);
      final endTimeStr = _endTime?.format(context);

      if (widget.rule == null) {
        // CREATE NEW RULE
        await database.insertRule(
          RulesCompanion.insert(
            name: name,
            type: typeInt,
            isEnabled: const d.Value(true),
            startTime: d.Value(startTimeStr),
            endTime: d.Value(endTimeStr),
            latitude: d.Value(_latitude),
            longitude: d.Value(_longitude),
            radius: d.Value(_radius),
          ),
        );
      } else {
        // UPDATE EXISTING RULE
        await database.updateRule(
          widget.rule!.copyWith(
            name: name,
            type: typeInt,
            startTime: d.Value(startTimeStr),
            endTime: d.Value(endTimeStr),
            latitude: d.Value(_latitude),
            longitude: d.Value(_longitude),
            radius: d.Value(_radius),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    }
  }

  void _deleteRule() async {
    if (widget.rule != null) {
      await database.deleteRule(widget.rule!);
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
              onChanged: (val) => setState(() => _selectedType = val!),
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
            ] else ...[
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
                          _latitude == null
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
            ],

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
