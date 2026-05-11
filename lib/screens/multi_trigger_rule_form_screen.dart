import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database.dart';
import '../main.dart';
import '../models/rule.dart' as model;
import '../models/rule_trigger_draft.dart';
import '../services/app_catalog.dart';
import '../services/calendar_auth_service.dart';
import '../services/calendar_event_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_trigger_fields.dart';
import 'map_picker_screen.dart';

class MultiTriggerRuleFormScreen extends StatefulWidget {
  const MultiTriggerRuleFormScreen({super.key, required this.ruleWithTriggers});

  final RuleWithTriggers ruleWithTriggers;

  @override
  State<MultiTriggerRuleFormScreen> createState() =>
      _MultiTriggerRuleFormScreenState();
}

class _MultiTriggerRuleFormScreenState
    extends State<MultiTriggerRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  late final TextEditingController _nameController;
  late final int _ruleId;
  late int _matchType;
  late bool _isEnabled;
  late bool _allowStarredContacts;
  late bool _allowRepeatCallers;
  late int _priority;
  late List<_ConditionDraft> _conditions;

  List<AppCatalogEntry> _installedApps = [];
  bool _isLoadingApps = false;
  bool _isSaving = false;
  bool _isCalendarAuthBusy = false;
  CalendarConnectionMetadata _calendarMetadata =
      const CalendarConnectionMetadata(connected: false);

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
    final entry = widget.ruleWithTriggers;
    final rule = entry.rule;
    _ruleId = rule.id;
    _nameController = TextEditingController(text: rule.name);
    _matchType = rule.matchType == 1 ? 1 : 0;
    _isEnabled = rule.isEnabled;
    _allowStarredContacts = rule.allowStarredContacts;
    _allowRepeatCallers = rule.allowRepeatCallers;
    _priority = rule.priority;

    final drafts = entry.triggers.isEmpty
        ? [RuleTriggerDraft.fromLegacyRule(rule)]
        : entry.triggers.map(RuleTriggerDraft.fromRuleTrigger).toList();
    _conditions = drafts.map(_ConditionDraft.fromDraft).toList();

    if (_conditions.any((condition) => condition.triggerType == 2)) {
      _fetchInstalledApps();
    }
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
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Rule'),
        actions: [
          IconButton(
            tooltip: 'Delete rule',
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _showDeleteConfirmation,
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
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            _buildEnabledSwitch(),
            const SizedBox(height: AppTheme.sectionGap),
            _sectionTitle('Match type'),
            const SizedBox(height: 8),
            _buildMatchTypeSelector(),
            const SizedBox(height: 16),
            _buildMatchTypeHelper(),
            const SizedBox(height: AppTheme.sectionGap),
            _sectionTitle('Conditions'),
            const SizedBox(height: 12),
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
            const SizedBox(height: AppTheme.sectionGap),
            _sectionTitle('Priority'),
            const SizedBox(height: 8),
            _buildPrioritySelector(),
            const SizedBox(height: AppTheme.sectionGap),
            _buildExceptionControls(),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _isSaving ? null : _saveRule,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update rule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnabledSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Rule enabled'),
      value: _isEnabled,
      onChanged: (value) => setState(() => _isEnabled = value),
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
          style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.62)),
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
      style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.62)),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _conditionSummary(condition),
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
            const SizedBox(height: 8),
            DropdownButtonFormField<model.TriggerType>(
              initialValue: triggerType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trigger Type',
                border: OutlineInputBorder(),
              ),
              items: model.TriggerType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_triggerIcon(type), color: AppTheme.logoBlue),
                          const SizedBox(width: 12),
                          Text(_triggerTitle(type)),
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
      ],
    );
  }

  Widget _buildLocationConfiguration(int index, _ConditionDraft condition) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.map, color: AppTheme.logoBlue),
      title: Text(
        condition.latitude == null || condition.longitude == null
            ? 'Tap to select a location'
            : 'Lat: ${condition.latitude!.toStringAsFixed(4)}, Lng: ${condition.longitude!.toStringAsFixed(4)}',
      ),
      subtitle: condition.radius == null
          ? null
          : Text(
              condition.radius! < 100
                  ? 'Radius: ${condition.radius}m - 100m+ recommended for reliability'
                  : 'Radius: ${condition.radius}m',
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _selectLocationOnMap(index),
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
      decoration: const InputDecoration(
        labelText: 'Select App to Trigger DND',
        border: OutlineInputBorder(),
      ),
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
      decoration: const InputDecoration(
        labelText: 'Select an Activity',
        border: OutlineInputBorder(),
      ),
      items: _availableActivities.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
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

  Widget _buildExceptionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exceptions', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'These apply when this rule is the primary active rule.',
          style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.62)),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Allow starred contacts'),
                value: _allowStarredContacts,
                onChanged: (val) => setState(() => _allowStarredContacts = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Allow repeat callers'),
                subtitle: const Text('If they call twice in 15 mins'),
                value: _allowRepeatCallers,
                onChanged: (val) => setState(() => _allowRepeatCallers = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    final choices = {...rulePriorityChoices, _priority}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('priority-$_priority'),
          initialValue: _priority,
          decoration: const InputDecoration(
            labelText: 'Priority',
            border: OutlineInputBorder(),
          ),
          items: choices
              .map(
                (priority) => DropdownMenuItem<int>(
                  value: priority,
                  child: Text(priorityDescription(priority)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _priority = value);
          },
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
        return 'Time: $start - $end';
      case RuleTriggerDraft.location:
        if (condition.latitude == null || condition.longitude == null) {
          return 'Location not selected';
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

  Future<void> _handleConditionTypeChange(
    int index,
    model.TriggerType? val,
  ) async {
    if (val == null) return;

    if (val == model.TriggerType.app) {
      final hasPermission = await _ensureUsagePermission();
      if (!hasPermission) return;
      if (_installedApps.isEmpty) await _fetchInstalledApps();
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
      var apps = await appCatalog.loadInstalledApps();
      final selectedPackages = _conditions
          .map((condition) => condition.packageName)
          .whereType<String>()
          .where((packageName) => packageName.isNotEmpty)
          .toSet();

      for (final packageName in selectedPackages) {
        if (!apps.any((app) => app.packageName == packageName)) {
          final selectedApp = await appCatalog.loadAppInfo(packageName);
          apps = [
            ...apps,
            selectedApp ??
                AppCatalogEntry(packageName: packageName, name: packageName),
          ];
        }
      }

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
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _conditions[index]
          ..latitude = result['latitude']
          ..longitude = result['longitude']
          ..radius = result['radius'];
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
      final baseRule = const RulesCompanion().copyWith(
        name: d.Value(_nameController.text.trim()),
        isEnabled: d.Value(_isEnabled),
        matchType: d.Value(_matchType),
        priority: d.Value(_priority),
        allowStarredContacts: d.Value(_allowStarredContacts),
        allowRepeatCallers: d.Value(_allowRepeatCallers),
      );

      await database.updateRuleWithTriggers(
        ruleId: _ruleId,
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
      if (_installedApps.isEmpty) await _fetchInstalledApps();
    }

    if (drafts.any((draft) => draft.triggerType == RuleTriggerDraft.activity)) {
      final hasPermission = await _ensureActivityPermission();
      if (!hasPermission) return false;
    }

    if (drafts.any((draft) => draft.triggerType == RuleTriggerDraft.location)) {
      final hasLocationPermission = await _ensureForegroundLocationPermission();
      if (!hasLocationPermission) return false;

      if (_isEnabled) {
        final hasBackgroundLocation =
            await _ensureBackgroundLocationForActiveRule();
        if (!hasBackgroundLocation) return false;
      }
    }

    if (_isEnabled &&
        drafts.any((draft) => draft.triggerType == RuleTriggerDraft.calendar)) {
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
    if (!await calendarAuthService.isConnected()) {
      if (mounted) {
        _showSnackBar(
          'Calendar rule saved disabled. Connect Google Calendar before enabling it.',
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

  void _deleteRule() async {
    await database.deleteRuleAndTriggers(_ruleId);
    await automationManager.syncRulesToAndroid();
    if (mounted) Navigator.pop(context);
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRule();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
  _ConditionDraft({
    this.triggerType,
    this.startTime,
    this.endTime,
    this.latitude,
    this.longitude,
    this.radius,
    this.packageName,
    this.activityType,
    this.calendarId,
    this.calendarKeyword,
    this.calendarIncludeAllDay = false,
    this.calendarLookaheadHours,
  });

  factory _ConditionDraft.fromDraft(RuleTriggerDraft draft) {
    return _ConditionDraft(
      triggerType: draft.triggerType,
      startTime: _parseTimeStringStatic(draft.startTime),
      endTime: _parseTimeStringStatic(draft.endTime),
      latitude: draft.latitude,
      longitude: draft.longitude,
      radius: draft.radius?.round(),
      packageName: draft.packageName,
      activityType: draft.activityType,
      calendarId: draft.calendarId,
      calendarKeyword: draft.calendarKeyword,
      calendarIncludeAllDay: draft.calendarIncludeAllDay,
      calendarLookaheadHours: draft.calendarLookaheadHours,
    );
  }

  int? triggerType;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  double? latitude;
  double? longitude;
  int? radius;
  String? packageName;
  String? activityType;
  String? calendarId;
  String? calendarKeyword;
  bool calendarIncludeAllDay;
  int? calendarLookaheadHours;

  RuleTriggerDraft toDraft(BuildContext context) {
    return RuleTriggerDraft(
      triggerType: triggerType ?? -1,
      startTime: startTime?.format(context),
      endTime: endTime?.format(context),
      latitude: latitude,
      longitude: longitude,
      radius: radius?.toDouble(),
      packageName: packageName,
      activityType: activityType,
      calendarId: calendarId,
      calendarKeyword: calendarKeyword,
      calendarIncludeAllDay: calendarIncludeAllDay,
      calendarLookaheadHours: calendarLookaheadHours,
    );
  }

  static TimeOfDay? _parseTimeStringStatic(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final parts = timeStr.split(':');
      var hour = int.parse(parts[0]);
      final minuteParts = parts[1].split(' ');
      final minute = int.parse(minuteParts[0]);

      if (timeStr.contains('PM') && hour != 12) hour += 12;
      if (timeStr.contains('AM') && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}
