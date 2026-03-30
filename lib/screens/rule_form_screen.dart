import 'package:flutter/material.dart';
import '../models/rule.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../main.dart'; // To access the global 'database'

class RuleFormScreen extends StatefulWidget {
  const RuleFormScreen({super.key});

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  TriggerType _selectedType = TriggerType.time;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Rule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Rule Name'),
              validator: (v) => v!.isEmpty ? 'Enter a name' : null,
              onSaved: (v) => _name = v!,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<TriggerType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Trigger Type'),
              items: TriggerType.values
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
            if (_selectedType == TriggerType.time) ...[
              ListTile(
                title: Text(
                  _startTime == null
                      ? 'Select Start Time'
                      : 'Start: ${_startTime!.format(context)}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) setState(() => _startTime = time);
                },
              ),
              ListTile(
                title: Text(
                  _endTime == null
                      ? 'Select End Time'
                      : 'End: ${_endTime!.format(context)}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) setState(() => _endTime = time);
                },
              ),
            ] else ...[
              const Text('Location Picker (Mocked for MVP Step 2)'),
              const TextField(
                decoration: InputDecoration(hintText: 'Latitude (e.g. 3.1390)'),
              ),
              const TextField(
                decoration: InputDecoration(
                  hintText: 'Longitude (e.g. 101.6869)',
                ),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                // 1. Added 'async' keyword here
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  // 2. RulesCompanion and Value are now recognized
                  final newEntry = RulesCompanion.insert(
                    name: _name,
                    type: _selectedType == TriggerType.time ? 0 : 1,
                    startTime: Value(_startTime?.format(context)),
                    endTime: Value(_endTime?.format(context)),
                  );

                  await database.addRule(newEntry);

                  if (mounted) {
                    // 3. Guarding the context across async gaps
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Save Rule'),
            ),
          ],
        ),
      ),
    );
  }
}
