import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import '../database/database.dart';
// Use a prefix to prevent the "Rule" name collision error
import '../models/rule.dart' as model;
import '../models/rule_trigger_draft.dart';
import '../models/time_repeat.dart';
import '../main.dart'; // Access global 'database'
import '../services/app_catalog.dart';
import '../services/calendar_auth_service.dart';
import '../services/calendar_event_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_trigger_fields.dart';
import '../widgets/location_trigger_fields.dart';
import '../widgets/time_repeat_fields.dart';
import 'map_picker_screen.dart'; // Make sure this matches your map screen file name
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class RuleFormScreen extends StatefulWidget {
  // Drift's generated Rule class from database.dart
  final Rule? rule;
  final int? profileId;

  const RuleFormScreen({super.key, this.rule, this.profileId});

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
  int _timeRepeatMode = timeRepeatEveryDay;
  int _timeRepeatDaysMask = timeRepeatEveryDayMask;

  // Location state
  double? _latitude;
  double? _longitude;
  int? _radius;
  int? _savedLocationId;
  String? _locationLabel;

  // App state
  String? _packageName;

  String? _activityType;
  String? _calendarId;
  String? _calendarKeyword;
  bool _calendarIncludeAllDay = false;
  int? _calendarLookaheadHours;
  final Map<String, String> _availableActivities = {
    'IN_VEHICLE': 'In Vehicle',
    'ON_BICYCLE': 'On Bicycle',
    'WALKING': 'Walking / On Foot',
    'RUNNING': 'Running',
    'STILL': 'Still / Not Moving',
    'TILTING': 'Tilting Device',
  };

  List<AppCatalogEntry> _installedApps = [];
  bool _isLoadingApps = false;
  bool _hasMultipleTriggers = false;
  int _priority = rulePriorityTime;
  bool _priorityManuallySelected = false;
  bool _isCalendarAuthBusy = false;
  CalendarConnectionMetadata _calendarMetadata =
      const CalendarConnectionMetadata(connected: false);

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
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return;
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
      } else if (widget.rule!.type == 3) {
        _selectedType = model.TriggerType.activity;
      } else if (widget.rule!.type == 4) {
        _selectedType = model.TriggerType.calendar;
      } else {
        _selectedType = model.TriggerType.time;
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
    if (widget.rule?.type == RuleTriggerDraft.time) {
      _timeRepeatMode = widget.rule!.timeRepeatMode;
      _timeRepeatDaysMask = widget.rule!.timeRepeatDaysMask;
    }

    // 3. Load existing location data if editing a Location Rule
    if (widget.rule?.latitude != null && widget.rule?.longitude != null) {
      _latitude = widget.rule!.latitude;
      _longitude = widget.rule!.longitude;
      _radius = widget.rule!.radius;
      _savedLocationId = widget.rule!.savedLocationId;
      _locationLabel = widget.rule!.locationLabel;
    }

    // 4. Load existing app data if editing an App Rule
    if (widget.rule?.packageName != null) {
      _packageName = widget.rule!.packageName;
    }

    if (_selectedType == model.TriggerType.app) {
      _fetchInstalledApps();
    }

    if (widget.rule?.activityType != null) {
      _activityType = widget.rule!.activityType;
    }

    _priority = widget.rule?.priority ?? rulePriorityTime;
    _priorityManuallySelected = widget.rule != null;

    _loadCalendarMetadata();
    _loadPrimaryTriggerFromRuleTriggers();
  }

  Future<void> _loadCalendarMetadata() async {
    final metadata = await calendarAuthService.getConnectionMetadata();
    if (!mounted) return;
    setState(() => _calendarMetadata = metadata);
  }

  Future<void> _loadPrimaryTriggerFromRuleTriggers() async {
    final rule = widget.rule;
    if (rule == null) return;

    final triggers = await database.getRuleTriggers(rule.id);
    if (!mounted || triggers.isEmpty) return;

    final trigger = triggers.first;
    setState(() {
      _hasMultipleTriggers = triggers.length > 1;
      switch (trigger.triggerType) {
        case 0:
          _selectedType = model.TriggerType.time;
          _startTime = trigger.startTime == null
              ? null
              : _parseTimeString(trigger.startTime!);
          _endTime = trigger.endTime == null
              ? null
              : _parseTimeString(trigger.endTime!);
          _timeRepeatMode = trigger.timeRepeatMode;
          _timeRepeatDaysMask = trigger.timeRepeatDaysMask;
          _latitude = null;
          _longitude = null;
          _radius = null;
          _savedLocationId = null;
          _locationLabel = null;
          _packageName = null;
          _activityType = null;
          _clearCalendarFields();
          break;
        case 1:
          _selectedType = model.TriggerType.location;
          _startTime = null;
          _endTime = null;
          _latitude = trigger.latitude;
          _longitude = trigger.longitude;
          _radius = trigger.radius?.round();
          _savedLocationId = trigger.savedLocationId;
          _locationLabel = trigger.locationLabel;
          _packageName = null;
          _activityType = null;
          _clearCalendarFields();
          break;
        case 2:
          _selectedType = model.TriggerType.app;
          _startTime = null;
          _endTime = null;
          _latitude = null;
          _longitude = null;
          _radius = null;
          _savedLocationId = null;
          _locationLabel = null;
          _packageName = trigger.packageName;
          _activityType = null;
          _clearCalendarFields();
          break;
        case 3:
          _selectedType = model.TriggerType.activity;
          _startTime = null;
          _endTime = null;
          _latitude = null;
          _longitude = null;
          _radius = null;
          _savedLocationId = null;
          _locationLabel = null;
          _packageName = null;
          _activityType = trigger.activityType;
          _clearCalendarFields();
          break;
        case 4:
          _selectedType = model.TriggerType.calendar;
          _startTime = null;
          _endTime = null;
          _latitude = null;
          _longitude = null;
          _radius = null;
          _savedLocationId = null;
          _locationLabel = null;
          _packageName = null;
          _activityType = null;
          _calendarId = trigger.calendarId;
          _calendarKeyword = trigger.calendarKeyword;
          _calendarIncludeAllDay = trigger.calendarIncludeAllDay;
          _calendarLookaheadHours = trigger.calendarLookaheadHours;
          break;
        default:
          break;
      }
    });

    if (trigger.triggerType == 2 && _installedApps.isEmpty) {
      await _fetchInstalledApps();
    }
  }

  void _clearCalendarFields() {
    _calendarId = null;
    _calendarKeyword = null;
    _calendarIncludeAllDay = false;
    _calendarLookaheadHours = null;
  }

  Future<void> _fetchInstalledApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final apps = await appCatalog.loadInstalledApps();
      final selectedPackage = _packageName;
      var entries = apps;
      if (selectedPackage != null &&
          selectedPackage.isNotEmpty &&
          !entries.any((app) => app.packageName == selectedPackage)) {
        final selectedApp = await appCatalog.loadAppInfo(selectedPackage);
        entries = [
          ...entries,
          selectedApp ??
              AppCatalogEntry(
                packageName: selectedPackage,
                name: selectedPackage,
              ),
        ];
      }
      if (!mounted) return;
      setState(() {
        _installedApps = entries;
        _isLoadingApps = false;
      });
    } catch (e) {
      debugPrint("Failed to get apps: $e");
      if (mounted) setState(() => _isLoadingApps = false);
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
    if (_hasMultipleTriggers) {
      _showSnackBar(
        'This rule has multiple conditions. Open it from Rules to use the multi-condition editor.',
      );
      return;
    }

    final triggerError = _triggerValidationError();
    if (!_formKey.currentState!.validate() || triggerError != null) {
      if (triggerError != null) {
        _showSnackBar(triggerError);
      }
      return;
    }

    if (_selectedType == model.TriggerType.location) {
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return;
      if (!mounted) return;

      final willBeEnabled = widget.rule?.isEnabled ?? true;
      if (willBeEnabled) {
        final hasBackgroundLocation =
            await _ensureBackgroundLocationForActiveRule();
        if (!hasBackgroundLocation) return;
        if (!mounted) return;
      }
    }

    final draft = _toRuleTriggerDraft();
    final willBeEnabled = widget.rule?.isEnabled ?? true;
    if (draft.triggerType == RuleTriggerDraft.calendar &&
        willBeEnabled &&
        !await calendarAuthService.isConnected()) {
      _showSnackBar(
        'Connect Google Calendar before saving an enabled Calendar rule.',
      );
      return;
    }

    final name = _nameController.text.trim();
    final selectedPriority = _priorityManuallySelected
        ? _priority
        : priorityForTrigger(
            triggerType: draft.triggerType,
            activityType: draft.activityType,
          );

    if (widget.rule == null) {
      // CREATE NEW RULE
      final baseRule = RulesCompanion.insert(
        name: name,
        type: draft.triggerType,
        isEnabled: const d.Value(true),
        priority: d.Value(selectedPriority),
        profileId: d.Value<int?>(widget.profileId),
        allowStarredContacts: const d.Value(false),
        allowRepeatCallers: const d.Value(false),
      );
      await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(baseRule, draft),
        triggers: [draft.toCompanion()],
      );
    } else {
      // UPDATE EXISTING RULE
      final baseRule = const RulesCompanion().copyWith(
        name: d.Value(name),
        isEnabled: d.Value(widget.rule!.isEnabled),
        priority: d.Value(selectedPriority),
        profileId: d.Value<int?>(widget.rule!.profileId),
        allowStarredContacts: const d.Value(false),
        allowRepeatCallers: const d.Value(false),
      );
      await database.updateRuleWithTriggers(
        ruleId: widget.rule!.id,
        rule: withFirstTriggerLegacyFields(baseRule, draft),
        triggers: [draft.toCompanion()],
      );
    }

    // 🔴 FIX: Tell the Android Service the rules have changed!
    await _syncCalendarBusyWindowsAfterSave(draft);
    await automationManager.syncRulesToAndroid();

    if (mounted) Navigator.pop(context);
  }

  RuleTriggerDraft _toRuleTriggerDraft() {
    return RuleTriggerDraft(
      triggerType: _triggerTypeFor(_selectedType),
      startTime: _startTime?.format(context),
      endTime: _endTime?.format(context),
      timeRepeatMode: _timeRepeatMode,
      timeRepeatDaysMask: _timeRepeatDaysMask,
      latitude: _latitude,
      longitude: _longitude,
      radius: _radius?.toDouble(),
      savedLocationId: _savedLocationId,
      locationLabel: _locationLabel,
      packageName: _packageName,
      activityType: _activityType,
      calendarId: _calendarId,
      calendarKeyword: _calendarKeyword,
      calendarIncludeAllDay: _calendarIncludeAllDay,
      calendarLookaheadHours: _calendarLookaheadHours,
    );
  }

  Future<void> _syncCalendarBusyWindowsAfterSave(RuleTriggerDraft draft) async {
    if (draft.triggerType != RuleTriggerDraft.calendar) return;
    if (!await calendarAuthService.isConnected()) {
      if (mounted) {
        _showSnackBar(
          'Calendar rule saved. Connect Google Calendar to update meeting times.',
        );
      }
      return;
    }

    final result = await CalendarEventSyncService(
      database: database,
    ).syncAllCalendarTriggerBusyWindows();
    if (!result.success && mounted) {
      _showSnackBar(result.message);
    }
  }

  String? _triggerValidationError() {
    switch (_selectedType) {
      case model.TriggerType.time:
        return validateRuleTriggerDrafts(
          ruleName: _nameController.text,
          matchType: 0,
          triggers: [_toRuleTriggerDraft()],
        );
      case model.TriggerType.location:
        if (_latitude == null || _longitude == null || _radius == null) {
          return 'Please select a location and radius.';
        }
        if (_radius! < 50) {
          return 'Please select a radius of at least 50m.';
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
      case model.TriggerType.calendar:
        return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureForegroundLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isGranted) return true;

    status = await Permission.location.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    _showPermissionDialog(
      "Location Permission Needed",
      "Allow location access to choose places for location rules.",
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
      "Background Location Needed",
      "Allow all-the-time location so this rule can activate when Quietly is not open.",
      () => openAppSettings(),
    );
    return false;
  }

  void _deleteRule() async {
    if (widget.rule != null) {
      await database.deleteRuleAndTriggers(widget.rule!.id);

      // 🔴 FIX: Sync deletion to Android Service
      await automationManager.syncRulesToAndroid();

      if (mounted) Navigator.pop(context);
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
          // Pass the existing values if they exist
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialRadius: _radius?.toDouble(),
          initialAddress: _locationLabel,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _radius = result['radius'];
        _savedLocationId = null;
        _locationLabel = _cleanText(result['address'] as String?);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

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
          padding: EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.pagePadding,
            AppTheme.pagePadding,
            AppTheme.sectionGap + bottomSafePadding,
          ),
          children: [
            _sectionTitle('Rule details'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rule Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: AppTheme.sectionGap),
            _sectionTitle('Condition'),
            const SizedBox(height: 8),
            DropdownButtonFormField<model.TriggerType>(
              initialValue: _selectedType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trigger type',
                border: OutlineInputBorder(),
              ),
              items: model.TriggerType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        t.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _handleTriggerTypeChange,
            ),
            const SizedBox(height: 16),

            if (_selectedType == model.TriggerType.time) ...[
              const Text(
                "Time condition",
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? TimeOfDay.now(),
                        );
                        if (time != null) setState(() => _endTime = time);
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TimeRepeatFields(
                        repeatMode: _timeRepeatMode,
                        repeatDaysMask: _timeRepeatDaysMask,
                        onChanged: (repeatMode, repeatDaysMask) {
                          setState(() {
                            _timeRepeatMode = repeatMode;
                            _timeRepeatDaysMask = repeatDaysMask;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedType == model.TriggerType.location) ...[
              const Text(
                "Location condition",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.cardPadding),
                  child: LocationTriggerFields(
                    activeSavedLocations: database.watchActiveSavedLocations(),
                    savedLocationId: _savedLocationId,
                    locationLabel: _locationLabel,
                    latitude: _latitude,
                    longitude: _longitude,
                    radius: _radius,
                    onSavedLocationSelected: (location) {
                      setState(() {
                        _latitude = location.latitude;
                        _longitude = location.longitude;
                        _radius = location.radius;
                        _savedLocationId = location.id;
                        _locationLabel = location.name;
                      });
                    },
                    onPickCustomLocation: _selectLocationOnMap,
                  ),
                ),
              ),
            ] else if (_selectedType == model.TriggerType.app) ...[
              const Text(
                "App condition",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: _isLoadingApps
                    ? const Padding(
                        padding: EdgeInsets.all(AppTheme.cardPadding),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey(_packageName),
                        initialValue:
                            _installedApps.any(
                              (app) => app.packageName == _packageName,
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
                          final Uint8List? iconBytes = app.iconBytes;

                          return DropdownMenuItem<String>(
                            value: app.packageName,
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
                                    app.name,
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
                "Activity condition",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _activityType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select an Activity',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(8),
                    ),
                    items: _availableActivities.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
            ] else if (_selectedType == model.TriggerType.calendar) ...[
              const Text(
                "Calendar condition",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.cardPadding),
                  child: CalendarTriggerFields(
                    connected: _calendarMetadata.connected,
                    email: _calendarMetadata.email,
                    isConnecting: _isCalendarAuthBusy,
                    includeAllDay: _calendarIncludeAllDay,
                    onIncludeAllDayChanged: (value) {
                      setState(() => _calendarIncludeAllDay = value);
                    },
                    keyword: _calendarKeyword,
                    onKeywordChanged: (value) {
                      _calendarKeyword = value;
                    },
                    onConnect: _connectCalendar,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppTheme.sectionGap),
            _buildPrioritySelector(),

            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _saveRule,
              child: Text(isEditing ? 'Update rule' : 'Save rule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectCalendar() async {
    setState(() => _isCalendarAuthBusy = true);
    final result = await calendarAuthService.connect();
    final metadata = await calendarAuthService.getConnectionMetadata();

    if (!mounted) return;
    setState(() {
      _calendarMetadata = metadata;
      _isCalendarAuthBusy = false;
    });
    _showSnackBar(
      result.connected
          ? 'Google Calendar connected as ${result.email}.'
          : result.message,
    );
  }

  Widget _buildPrioritySelector() {
    final value = _effectivePriority;
    final choices = {...rulePriorityChoices, value}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Priority", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey('priority-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Priority',
            border: OutlineInputBorder(),
          ),
          items: choices
              .map(
                (priority) => DropdownMenuItem<int>(
                  value: priority,
                  child: Text(
                    priorityDescription(priority),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _priority = value;
              _priorityManuallySelected = true;
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          "Higher priority rules become the main active rule when multiple rules match.",
          style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.62)),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.pureBlack,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  int get _effectivePriority {
    if (_priorityManuallySelected) return _priority;
    return priorityForTrigger(
      triggerType: _triggerTypeFor(_selectedType),
      activityType: _activityType,
    );
  }

  int _triggerTypeFor(model.TriggerType type) {
    switch (type) {
      case model.TriggerType.time:
        return 0;
      case model.TriggerType.location:
        return 1;
      case model.TriggerType.app:
        return 2;
      case model.TriggerType.activity:
        return 3;
      case model.TriggerType.calendar:
        return 4;
    }
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

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
