import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database.dart';
import '../main.dart';
import '../models/rule.dart' as model;
import '../models/rule_trigger_draft.dart';
import '../models/time_repeat.dart';
import '../services/app_catalog.dart';
import '../services/calendar_auth_service.dart';
import '../services/calendar_event_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_trigger_fields.dart';
import '../widgets/location_trigger_fields.dart';
import '../widgets/time_repeat_fields.dart';
import 'map_picker_screen.dart';

class CreateRuleWizard extends StatefulWidget {
  const CreateRuleWizard({super.key, this.profileId});

  final int? profileId;

  @override
  State<CreateRuleWizard> createState() => _CreateRuleWizardState();
}

class _CreateRuleWizardState extends State<CreateRuleWizard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  int _currentStep = 0;
  int _matchType = 0;
  final List<_ConditionDraft> _conditions = [_ConditionDraft()];

  List<AppCatalogEntry> _installedApps = [];
  bool _isLoadingApps = false;
  bool _isSaving = false;
  bool _isCalendarAuthBusy = false;
  CalendarConnectionMetadata _calendarMetadata =
      const CalendarConnectionMetadata(connected: false);

  int _priority = rulePriorityTime;
  bool _priorityManuallySelected = false;

  final Map<String, String> _availableActivities = {
    'IN_VEHICLE': 'In Vehicle',
    'ON_BICYCLE': 'On Bicycle',
    'WALKING': 'Walking / On Foot',
    'RUNNING': 'Running',
    'STILL': 'Still / Not Moving',
    'TILTING': 'Tilting Device',
  };

  @override
  void initState() {
    super.initState();
    _loadCalendarMetadata();
  }

  Future<void> _loadCalendarMetadata() async {
    final metadata = await calendarAuthService.getConnectionMetadata();
    if (!mounted) return;
    setState(() => _calendarMetadata = metadata);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Rule')),
      body: SafeArea(
        top: false,
        child: Form(
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
                          : Text(_currentStep == 2 ? 'Save rule' : 'Continue'),
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
                  'Rule details',
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
                  'Conditions',
                  style: TextStyle(color: AppTheme.pureBlack),
                ),
                content: _buildConditionsStep(),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text(
                  'Priority',
                  style: TextStyle(color: AppTheme.pureBlack),
                ),
                content: _buildPriorityStep(),
                isActive: _currentStep >= 2,
              ),
            ],
          ),
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
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: BorderSide(
          color: AppTheme.pureBlack.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: const BorderSide(color: AppTheme.logoBlue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _buildConditionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Match type'),
        const SizedBox(height: 8),
        _buildMatchTypeSelector(),
        const SizedBox(height: 16),
        _buildMatchTypeHelper(),
        const SizedBox(height: 16),
        ..._conditions.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildConditionCard(entry.key, entry.value),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _addCondition,
          icon: const Icon(Icons.add, color: AppTheme.logoBlue),
          label: const Text(
            'Add condition',
            style: TextStyle(color: AppTheme.logoBlue),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.logoBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment<int>(
              value: 0,
              icon: Icon(Icons.call_split),
              label: Text('Any'),
            ),
            ButtonSegment<int>(
              value: 1,
              icon: Icon(Icons.done_all),
              label: Text('All'),
            ),
          ],
          selected: {_matchType},
          onSelectionChanged: (selection) {
            setState(() => _matchType = selection.single);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _matchType == 0
              ? 'Quietly will activate this rule when any condition matches.'
              : 'Quietly will activate this rule only when all conditions match.',
          style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildMatchTypeHelper() {
    if (_conditions.length <= 1) return const SizedBox.shrink();

    final message = _matchType == 1
        ? 'Every condition must match before this rule activates.'
        : 'Any condition can activate this rule.';

    return Text(
      message,
      style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.6)),
    );
  }

  Widget _buildConditionCard(int index, _ConditionDraft condition) {
    final triggerType = _modelTypeFor(condition.triggerType);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Condition ${index + 1}',
                        style: const TextStyle(
                          color: AppTheme.pureBlack,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _conditionSummary(condition),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.pureBlack.withValues(alpha: 0.62),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (triggerType != null) ...[
                  Icon(
                    _triggerIcon(triggerType),
                    color: AppTheme.logoBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  tooltip: 'Remove condition',
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppTheme.pureBlack.withValues(alpha: 0.65),
                  ),
                  onPressed: _conditions.length == 1
                      ? () =>
                            _showSnackBar('At least one condition is required.')
                      : () => _removeCondition(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<model.TriggerType>(
              initialValue: triggerType,
              isExpanded: true,
              decoration: _inputDecoration('Trigger type'),
              items: model.TriggerType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_triggerIcon(type), color: AppTheme.logoBlue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _triggerTitle(type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (type) => _handleConditionTypeChange(index, type),
            ),
            if (condition.triggerType != null) ...[
              const SizedBox(height: 12),
              _buildConditionConfiguration(index, condition),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConditionConfiguration(int index, _ConditionDraft condition) {
    switch (condition.triggerType) {
      case RuleTriggerDraft.time:
        return _buildTimeConfiguration(index, condition);
      case RuleTriggerDraft.location:
        return _buildLocationConfiguration(index, condition);
      case RuleTriggerDraft.app:
        return _buildAppConfiguration(index, condition);
      case RuleTriggerDraft.activity:
        return _buildActivityConfiguration(index, condition);
      case RuleTriggerDraft.calendar:
        return _buildCalendarConfiguration(index, condition);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeConfiguration(int index, _ConditionDraft condition) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule, color: AppTheme.logoBlue),
          title: Text(
            condition.startTime == null
                ? 'Select Start Time'
                : 'Starts at: ${condition.startTime!.format(context)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: condition.startTime ?? TimeOfDay.now(),
            );
            if (time != null) {
              setState(() => _conditions[index].startTime = time);
            }
          },
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timelapse, color: AppTheme.logoPurple),
          title: Text(
            condition.endTime == null
                ? 'Select End Time'
                : 'Ends at: ${condition.endTime!.format(context)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: condition.endTime ?? TimeOfDay.now(),
            );
            if (time != null) {
              setState(() => _conditions[index].endTime = time);
            }
          },
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TimeRepeatFields(
            repeatMode: condition.timeRepeatMode,
            repeatDaysMask: condition.timeRepeatDaysMask,
            onChanged: (repeatMode, repeatDaysMask) {
              setState(() {
                _conditions[index]
                  ..timeRepeatMode = repeatMode
                  ..timeRepeatDaysMask = repeatDaysMask;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationConfiguration(int index, _ConditionDraft condition) {
    return LocationTriggerFields(
      activeSavedLocations: database.watchActiveSavedLocations(),
      savedLocationId: condition.savedLocationId,
      locationLabel: condition.locationLabel,
      latitude: condition.latitude,
      longitude: condition.longitude,
      radius: condition.radius,
      onSavedLocationSelected: (location) {
        setState(() {
          _conditions[index]
            ..latitude = location.latitude
            ..longitude = location.longitude
            ..radius = location.radius
            ..savedLocationId = location.id
            ..locationLabel = location.name;
        });
      },
      onPickCustomLocation: () => _selectLocationOnMap(index),
    );
  }

  Widget _buildAppConfiguration(int index, _ConditionDraft condition) {
    if (_isLoadingApps) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('app-$index-${condition.packageName}'),
      initialValue:
          _installedApps.any((app) => app.packageName == condition.packageName)
          ? condition.packageName
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
      onChanged: (val) {
        setState(() => _conditions[index].packageName = val);
      },
    );
  }

  Widget _buildActivityConfiguration(int index, _ConditionDraft condition) {
    return DropdownButtonFormField<String>(
      key: ValueKey('activity-$index-${condition.activityType}'),
      initialValue: condition.activityType,
      isExpanded: true,
      decoration: _inputDecoration('Select an Activity'),
      items: _availableActivities.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() => _conditions[index].activityType = val);
      },
    );
  }

  Widget _buildCalendarConfiguration(int index, _ConditionDraft condition) {
    return CalendarTriggerFields(
      connected: _calendarMetadata.connected,
      email: _calendarMetadata.email,
      isConnecting: _isCalendarAuthBusy,
      includeAllDay: condition.calendarIncludeAllDay,
      onIncludeAllDayChanged: (value) {
        setState(() => _conditions[index].calendarIncludeAllDay = value);
      },
      keyword: condition.calendarKeyword,
      onKeywordChanged: (value) {
        _conditions[index].calendarKeyword = value;
      },
      onConnect: _connectCalendar,
    );
  }

  Widget _buildPriorityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Priority'),
        const SizedBox(height: 8),
        _buildPrioritySelector(
          value: _effectivePriority,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _priority = value;
              _priorityManuallySelected = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector({
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    final choices = {...rulePriorityChoices, value}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('priority-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: _inputDecoration('Priority'),
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
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Higher priority rules become the main active rule when multiple rules match.',
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

  String _conditionSummary(_ConditionDraft condition) {
    switch (condition.triggerType) {
      case RuleTriggerDraft.time:
        final start = condition.startTime?.format(context) ?? 'start time';
        final end = condition.endTime?.format(context) ?? 'end time';
        final repeat = repeatLabel(
          condition.timeRepeatMode,
          daysMask: condition.timeRepeatDaysMask,
        );
        return 'Time: $start-$end, $repeat';
      case RuleTriggerDraft.location:
        if (condition.latitude == null || condition.longitude == null) {
          return 'Location not selected';
        }
        final label = condition.locationLabel?.trim();
        if (label != null && label.isNotEmpty) {
          return 'Location: $label, ${condition.radius ?? 100}m';
        }
        return 'Location radius: ${condition.radius ?? 100}m';
      case RuleTriggerDraft.app:
        final packageName = condition.packageName;
        if (packageName == null || packageName.isEmpty) {
          return 'App not selected';
        }
        return 'App: ${appCatalog.labelFor(packageName)}';
      case RuleTriggerDraft.activity:
        final activity = condition.activityType;
        if (activity == null || activity.isEmpty) {
          return 'Activity not selected';
        }
        return 'Activity: ${_availableActivities[activity] ?? activity}';
      case RuleTriggerDraft.calendar:
        final keyword = condition.calendarKeyword?.trim();
        final summary = keyword == null || keyword.isEmpty
            ? 'Calendar event'
            : "Calendar event matching '$keyword'";
        return condition.calendarIncludeAllDay
            ? '$summary, including all-day'
            : summary;
      default:
        return 'Choose a trigger type';
    }
  }

  Future<void> _handleContinue() async {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
      return;
    }

    if (_currentStep == 1) {
      final error = _draftValidationError();
      if (error != null) {
        _showSnackBar(error);
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    await _saveRule();
  }

  Future<void> _handleConditionTypeChange(
    int index,
    model.TriggerType? val,
  ) async {
    if (val == null) return;

    if (val == model.TriggerType.app) {
      final hasPermission = await _ensureUsagePermission();
      if (!hasPermission) return;
      if (_installedApps.isEmpty) {
        await _fetchInstalledApps();
      }
    } else if (val == model.TriggerType.location) {
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return;
    } else if (val == model.TriggerType.activity) {
      final hasActivityPermission = await _ensureActivityPermission();
      if (!hasActivityPermission) return;
    }

    setState(() {
      _conditions[index] = _ConditionDraft(triggerType: _triggerTypeFor(val));
    });
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

  Future<void> _selectLocationOnMap(int index) async {
    final hasLocationPermission = await _ensureForegroundLocationPermission();
    if (!hasLocationPermission) return;
    if (!mounted) return;

    final condition = _conditions[index];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: condition.latitude,
          initialLongitude: condition.longitude,
          initialRadius: condition.radius?.toDouble(),
          initialAddress: condition.locationLabel,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _conditions[index]
          ..latitude = result['latitude']
          ..longitude = result['longitude']
          ..radius = result['radius']
          ..savedLocationId = null
          ..locationLabel = _cleanText(result['address'] as String?);
      });
    }
  }

  Future<void> _saveRule() async {
    final error = _draftValidationError();
    if (!_formKey.currentState!.validate() || error != null) {
      _showSnackBar(error ?? 'Please complete the rule name.');
      return;
    }

    final drafts = _toRuleTriggerDrafts();
    final hasPermissions = await _ensurePermissionsForDrafts(drafts);
    if (!hasPermissions || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final baseRule = RulesCompanion.insert(
        name: _nameController.text.trim(),
        type: drafts.first.triggerType,
        isEnabled: const d.Value(true),
        matchType: d.Value(_matchType),
        priority: d.Value(_effectivePriority),
        profileId: d.Value<int?>(widget.profileId),
        allowStarredContacts: const d.Value(false),
        allowRepeatCallers: const d.Value(false),
      );

      await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(baseRule, drafts.first),
        triggers: drafts.map((draft) => draft.toCompanion()).toList(),
      );

      await _syncCalendarBusyWindowsAfterSave(drafts);
      await automationManager.syncRulesToAndroid();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _ensurePermissionsForDrafts(
    List<RuleTriggerDraft> drafts,
  ) async {
    if (drafts.any((draft) => draft.triggerType == RuleTriggerDraft.app)) {
      final hasPermission = await _ensureUsagePermission();
      if (!hasPermission) return false;
      if (_installedApps.isEmpty) {
        await _fetchInstalledApps();
      }
    }

    if (drafts.any((draft) => draft.triggerType == RuleTriggerDraft.activity)) {
      final hasPermission = await _ensureActivityPermission();
      if (!hasPermission) return false;
    }

    if (drafts.any((draft) => draft.triggerType == RuleTriggerDraft.location)) {
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return false;

      final hasBackgroundLocation =
          await _ensureBackgroundLocationForActiveRule();
      if (!hasBackgroundLocation) return false;
    }

    if (drafts.any((draft) => draft.triggerType == RuleTriggerDraft.calendar)) {
      final connected = await calendarAuthService.isConnected();
      if (!connected) {
        _showSnackBar(
          'Connect Google Calendar before saving an enabled Calendar rule.',
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _syncCalendarBusyWindowsAfterSave(
    List<RuleTriggerDraft> drafts,
  ) async {
    if (!drafts.any(
      (draft) => draft.triggerType == RuleTriggerDraft.calendar,
    )) {
      return;
    }
    if (!await calendarAuthService.isConnected()) return;

    final result = await CalendarEventSyncService(
      database: database,
    ).syncAllCalendarTriggerBusyWindows();
    if (!result.success && mounted) {
      _showSnackBar(result.message);
    }
  }

  Future<bool> _ensureUsagePermission() async {
    final bool hasPermission = await platform.invokeMethod(
      'checkUsagePermission',
    );
    if (hasPermission) return true;

    if (!mounted) return false;
    _showPermissionDialog(
      'Usage Access Required',
      'To detect which app is running, please grant Usage Access.',
      () => platform.invokeMethod('openUsageSettings'),
    );
    return false;
  }

  Future<bool> _ensureActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    _showPermissionDialog(
      'Activity Recognition Required',
      'To trigger DND by physical activity, please grant Activity permissions.',
      () => openAppSettings(),
    );
    return false;
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

  void _addCondition() {
    setState(() => _conditions.add(_ConditionDraft()));
  }

  void _removeCondition(int index) {
    setState(() => _conditions.removeAt(index));
  }

  String? _draftValidationError() {
    return validateRuleTriggerDrafts(
      ruleName: _nameController.text,
      matchType: _matchType,
      triggers: _toRuleTriggerDrafts(),
    );
  }

  List<RuleTriggerDraft> _toRuleTriggerDrafts() {
    return _conditions.map((condition) => condition.toDraft(context)).toList();
  }

  int get _effectivePriority {
    if (_priorityManuallySelected) return _priority;
    return priorityForDrafts(_toRuleTriggerDrafts());
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
      case model.TriggerType.calendar:
        return Icons.event;
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
      case model.TriggerType.calendar:
        return 'Calendar';
    }
  }

  int _triggerTypeFor(model.TriggerType type) {
    switch (type) {
      case model.TriggerType.time:
        return RuleTriggerDraft.time;
      case model.TriggerType.location:
        return RuleTriggerDraft.location;
      case model.TriggerType.app:
        return RuleTriggerDraft.app;
      case model.TriggerType.activity:
        return RuleTriggerDraft.activity;
      case model.TriggerType.calendar:
        return RuleTriggerDraft.calendar;
    }
  }

  model.TriggerType? _modelTypeFor(int? type) {
    switch (type) {
      case RuleTriggerDraft.time:
        return model.TriggerType.time;
      case RuleTriggerDraft.location:
        return model.TriggerType.location;
      case RuleTriggerDraft.app:
        return model.TriggerType.app;
      case RuleTriggerDraft.activity:
        return model.TriggerType.activity;
      case RuleTriggerDraft.calendar:
        return model.TriggerType.calendar;
      default:
        return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConditionDraft {
  _ConditionDraft({this.triggerType});

  int? triggerType;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int timeRepeatMode = timeRepeatEveryDay;
  int timeRepeatDaysMask = timeRepeatEveryDayMask;
  double? latitude;
  double? longitude;
  int? radius;
  int? savedLocationId;
  String? locationLabel;
  String? packageName;
  String? activityType;
  String? calendarId;
  String? calendarKeyword;
  bool calendarIncludeAllDay = false;
  int? calendarLookaheadHours;

  RuleTriggerDraft toDraft(BuildContext context) {
    return RuleTriggerDraft(
      triggerType: triggerType ?? -1,
      startTime: startTime?.format(context),
      endTime: endTime?.format(context),
      timeRepeatMode: timeRepeatMode,
      timeRepeatDaysMask: timeRepeatDaysMask,
      latitude: latitude,
      longitude: longitude,
      radius: radius?.toDouble(),
      savedLocationId: savedLocationId,
      locationLabel: locationLabel,
      packageName: packageName,
      activityType: activityType,
      calendarId: calendarId,
      calendarKeyword: calendarKeyword,
      calendarIncludeAllDay: calendarIncludeAllDay,
      calendarLookaheadHours: calendarLookaheadHours,
    );
  }
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
