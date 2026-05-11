import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_catalog.dart';
import '../services/calendar_auth_service.dart';
import '../services/calendar_event_sync_service.dart';
import '../services/dnd_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _keywordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _keywordBypassEnabled = false;
  bool _dndAccessGranted = false;
  bool _notificationListenerEnabled = false;
  bool _notificationPermissionGranted = false;
  bool _usageAccessGranted = false;
  bool _locationPermissionGranted = false;
  bool _backgroundLocationPermissionGranted = false;
  bool _activityRecognitionPermissionGranted = false;
  bool _isCalendarAuthBusy = false;
  bool _isCalendarSyncBusy = false;
  CalendarConnectionMetadata _calendarMetadata =
      const CalendarConnectionMetadata(connected: false);
  CalendarEventSyncResult? _lastCalendarSyncResult;
  List<String> _keywords = const ['urgent', 'emergency', 'asap'];
  Set<String> _selectedPackages = {};
  List<AppCatalogEntry> _installedApps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keywordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStates();
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final settings = await DndService.getKeywordBypassSettings();
    final permissions = await _readPermissionStates();
    final calendarMetadata = await calendarAuthService.getConnectionMetadata();
    final apps = await appCatalog.loadInstalledApps();

    if (!mounted) return;
    setState(() {
      _keywordBypassEnabled = settings.enabled;
      _keywords = settings.keywords;
      _selectedPackages = settings.packages.toSet();
      _applyPermissionStates(permissions);
      _calendarMetadata = calendarMetadata;
      _installedApps = apps;
      _isLoading = false;
    });
  }

  Future<_PermissionStates> _readPermissionStates() async {
    return _PermissionStates(
      dndAccessGranted: await DndService.isPermissionGranted(),
      notificationListenerEnabled:
          await DndService.isNotificationListenerEnabled(),
      notificationPermissionGranted:
          await DndService.isNotificationPermissionGranted(),
      usageAccessGranted: await DndService.isUsagePermissionGranted(),
      locationPermissionGranted: await DndService.isLocationPermissionGranted(),
      backgroundLocationPermissionGranted:
          await DndService.isBackgroundLocationPermissionGranted(),
      activityRecognitionPermissionGranted:
          await DndService.isActivityRecognitionPermissionGranted(),
    );
  }

  void _applyPermissionStates(_PermissionStates permissions) {
    _dndAccessGranted = permissions.dndAccessGranted;
    _notificationListenerEnabled = permissions.notificationListenerEnabled;
    _notificationPermissionGranted = permissions.notificationPermissionGranted;
    _usageAccessGranted = permissions.usageAccessGranted;
    _locationPermissionGranted = permissions.locationPermissionGranted;
    _backgroundLocationPermissionGranted =
        permissions.backgroundLocationPermissionGranted;
    _activityRecognitionPermissionGranted =
        permissions.activityRecognitionPermissionGranted;
  }

  Future<void> _refreshPermissionStates() async {
    final hadLocationPermission = _locationPermissionGranted;
    final hadBackgroundLocationPermission =
        _backgroundLocationPermissionGranted;
    final permissions = await _readPermissionStates();
    if (!mounted) return;
    setState(() => _applyPermissionStates(permissions));

    final locationWasJustGranted =
        !hadLocationPermission && permissions.locationPermissionGranted;
    final backgroundLocationWasJustGranted =
        !hadBackgroundLocationPermission &&
        permissions.backgroundLocationPermissionGranted;
    if (locationWasJustGranted || backgroundLocationWasJustGranted) {
      await automationManager.syncRulesToAndroid();
      if (mounted) {
        _showSnackBar('Location permission updated. Rules synced.');
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await DndService.saveKeywordBypassSettings(
      enabled: _keywordBypassEnabled,
      keywords: _keywords,
      packages: _selectedPackages.toList(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _setKeywordBypassEnabled(bool value) async {
    setState(() => _keywordBypassEnabled = value);
    await _saveSettings();
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    final alreadyExists = _keywords.any(
      (existing) => existing.toLowerCase() == keyword.toLowerCase(),
    );
    if (alreadyExists) {
      _showSnackBar('Keyword already exists.');
      return;
    }

    setState(() {
      _keywords = [..._keywords, keyword];
      _keywordController.clear();
    });
    await _saveSettings();
  }

  Future<void> _removeKeyword(String keyword) async {
    setState(() {
      _keywords = _keywords.where((item) => item != keyword).toList();
    });
    await _saveSettings();
  }

  Future<void> _togglePackage(String packageName, bool selected) async {
    setState(() {
      if (selected) {
        _selectedPackages = {..._selectedPackages, packageName};
      } else {
        _selectedPackages = _selectedPackages
            .where((value) => value != packageName)
            .toSet();
      }
    });
    await _saveSettings();
  }

  Future<void> _openNotificationAccessSettings() async {
    await DndService.openNotificationListenerSettings();
    await _refreshPermissionStates();
  }

  Future<void> _openDndAccessSettings() async {
    await DndService.openDndSettings();
    await _refreshPermissionStates();
  }

  Future<void> _openUsageAccessSettings() async {
    await DndService.openUsageSettings();
    await _refreshPermissionStates();
  }

  Future<void> _requestNotificationPermission() async {
    await DndService.requestNotificationPermission();
    await _refreshPermissionStates();
  }

  Future<void> _requestLocationPermission() async {
    await DndService.requestLocationPermission();
    await _refreshPermissionStates();
  }

  Future<void> _requestBackgroundLocationPermission() async {
    await DndService.requestBackgroundLocationPermission();
    await _refreshPermissionStates();
  }

  Future<void> _requestActivityRecognitionPermission() async {
    await DndService.requestActivityRecognitionPermission();
    await _refreshPermissionStates();
  }

  Future<void> _connectCalendar() async {
    setState(() => _isCalendarAuthBusy = true);
    final result = await calendarAuthService.connect();
    final metadata = await calendarAuthService.getConnectionMetadata();

    if (!mounted) return;
    setState(() {
      _calendarMetadata = metadata;
      _isCalendarAuthBusy = false;
      _lastCalendarSyncResult = null;
    });
    _showSnackBar(
      result.connected
          ? 'Google Calendar connected as ${result.email}.'
          : result.message,
    );
  }

  Future<void> _disconnectCalendar() async {
    setState(() => _isCalendarAuthBusy = true);
    try {
      await calendarAuthService.disconnect();
      final metadata = await calendarAuthService.getConnectionMetadata();
      if (!mounted) return;
      setState(() {
        _calendarMetadata = metadata;
        _isCalendarAuthBusy = false;
        _lastCalendarSyncResult = null;
      });
      _showSnackBar('Google Calendar disconnected.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCalendarAuthBusy = false);
      _showSnackBar('Google Calendar could not be disconnected.');
    }
  }

  Future<void> _refreshCalendarBusyWindows() async {
    setState(() => _isCalendarSyncBusy = true);
    final result = await CalendarEventSyncService(
      database: database,
    ).syncAllCalendarTriggerBusyWindows();

    if (!mounted) return;
    setState(() {
      _lastCalendarSyncResult = result;
      _isCalendarSyncBusy = false;
    });
    _showSnackBar(result.message);
  }

  String _calendarSyncStatusText() {
    final result = _lastCalendarSyncResult;
    if (result == null) {
      return 'Ready to cache busy windows when Calendar triggers exist.';
    }
    if (result.fetchedAt != null) {
      return 'Last refreshed ${_formatDateTime(result.fetchedAt!)}. '
          '${result.insertedCount} cached, ${result.skippedCount} skipped.';
    }
    return result.message;
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _appLabel(String packageName) {
    return appCatalog.labelFor(packageName);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  AppTheme.pagePadding,
                  AppTheme.pagePadding,
                  AppTheme.sectionGap + bottomSafePadding,
                ),
                children: [
                  _buildPrivacyHeader(),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildPermissionsSection(),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildCalendarConnectionSection(),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildKeywordBypassSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacyHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Privacy note',
          'Quietly keeps automation settings on this device.',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          decoration: BoxDecoration(
            color: AppTheme.logoBlue.withValues(alpha: 0.1),
            borderRadius: AppTheme.cardBorderRadius,
            border: Border.all(color: AppTheme.logoBlue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.logoBlue),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Rules, keywords, and monitored apps are stored locally. Notification text is checked on this device only.',
                  style: TextStyle(
                    color: AppTheme.pureBlack.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection() {
    final rows = <Widget>[
      _buildPermissionRow(
        icon: Icons.do_not_disturb_on,
        title: 'Do Not Disturb Access',
        description: 'Required for DND automation and DND policy exceptions.',
        granted: _dndAccessGranted,
        onPressed: _openDndAccessSettings,
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.notifications_active,
        title: 'Notification Listener Access',
        description: 'Required for emergency keyword bypass detection.',
        granted: _notificationListenerEnabled,
        onPressed: _openNotificationAccessSettings,
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.notification_important,
        title: 'Notification Permission',
        description: 'Required to show Quietly emergency alerts.',
        granted: _notificationPermissionGranted,
        onPressed: _requestNotificationPermission,
        actionLabel: 'Grant',
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.query_stats,
        title: 'Usage Access',
        description: 'Required for app foreground triggers.',
        granted: _usageAccessGranted,
        onPressed: _openUsageAccessSettings,
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.location_on,
        title: 'Location Permission',
        description: 'Needed to choose places for location rules.',
        granted: _locationPermissionGranted,
        onPressed: _requestLocationPermission,
        actionLabel: 'Grant',
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.my_location,
        title: 'Background Location',
        description: 'Lets geofence rules activate when Quietly is not open.',
        granted: _backgroundLocationPermissionGranted,
        onPressed: _requestBackgroundLocationPermission,
        actionLabel: 'Grant',
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.directions_walk,
        title: 'Activity Recognition',
        description: 'Required for activity and driving triggers.',
        granted: _activityRecognitionPermissionGranted,
        onPressed: _requestActivityRecognitionPermission,
        actionLabel: 'Grant',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Permissions',
          'Required access for automation, emergency bypass, and trigger detection.',
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: rows)),
      ],
    );
  }

  Widget _permissionDivider() {
    return Divider(height: 1, color: AppTheme.pureBlack.withValues(alpha: 0.1));
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onPressed,
    String actionLabel = 'Open',
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: granted ? AppTheme.logoBlue : AppTheme.logoPurple,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.pureBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _statusPill(granted),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(description),
      ),
      trailing: granted
          ? const Icon(Icons.check_circle, color: AppTheme.logoCyan)
          : TextButton(onPressed: onPressed, child: Text(actionLabel)),
      onTap: granted ? _refreshPermissionStates : onPressed,
    );
  }

  Widget _buildCalendarConnectionSection() {
    final connected = _calendarMetadata.connected;
    final email = _calendarMetadata.email;
    final statusText = connected && email != null
        ? 'Connected as $email'
        : connected
        ? 'Connected'
        : 'Not connected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Google Calendar',
          'Connect Google Calendar only if you want meeting-based DND automation.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.event_available,
                  color: connected ? AppTheme.logoBlue : AppTheme.logoPurple,
                ),
                title: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Calendar connection',
                        style: TextStyle(
                          color: AppTheme.pureBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _connectionPill(connected),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(statusText),
                ),
                trailing: TextButton(
                  onPressed: _isCalendarAuthBusy
                      ? null
                      : connected
                      ? _disconnectCalendar
                      : _connectCalendar,
                  child: _isCalendarAuthBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(connected ? 'Disconnect' : 'Connect'),
                ),
              ),
              Divider(
                height: 1,
                color: AppTheme.pureBlack.withValues(alpha: 0.1),
              ),
              ListTile(
                leading: const Icon(Icons.sync, color: AppTheme.logoBlue),
                title: const Text(
                  'Busy window cache',
                  style: TextStyle(
                    color: AppTheme.pureBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_calendarSyncStatusText()),
                ),
                trailing: connected
                    ? TextButton(
                        onPressed: _isCalendarSyncBusy
                            ? null
                            : _refreshCalendarBusyWindows,
                        child: _isCalendarSyncBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Refresh'),
                      )
                    : null,
              ),
              Divider(
                height: 1,
                color: AppTheme.pureBlack.withValues(alpha: 0.1),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPadding),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppTheme.logoBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quietly uses calendar access to detect meeting times. Event details are not stored.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.pureBlack.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordBypassSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Emergency Keyword Bypass',
          'Let selected urgent messages break through automation DND.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Emergency keyword bypass'),
                subtitle: const Text(
                  'Detect selected keywords from monitored app notifications while automation DND is active.',
                ),
                value: _keywordBypassEnabled,
                onChanged: _isSaving ? null : _setKeywordBypassEnabled,
              ),
              Divider(
                height: 1,
                color: AppTheme.pureBlack.withValues(alpha: 0.1),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPadding),
                child: Text(
                  'Notification text is checked locally. Message content is not stored or uploaded.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.pureBlack.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildKeywordEditor(),
        const SizedBox(height: 16),
        _buildMonitoredAppSelector(),
      ],
    );
  }

  Widget _buildKeywordEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keywords',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Words that can trigger an emergency bypass alert.',
              style: TextStyle(
                color: AppTheme.pureBlack.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _keywords.map((keyword) {
                return InputChip(
                  label: Text(keyword),
                  onDeleted: _isSaving ? null : () => _removeKeyword(keyword),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      labelText: 'Add keyword',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSaving ? null : _addKeyword,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add keyword',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoredAppSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monitored apps',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedPackages.isEmpty
                  ? 'No apps selected'
                  : '${_selectedPackages.length} apps selected',
              style: TextStyle(
                color: AppTheme.pureBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedPackages.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedPackages.map((packageName) {
                  return InputChip(
                    label: Text(_appLabel(packageName)),
                    onDeleted: _isSaving
                        ? null
                        : () => _togglePackage(packageName, false),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (_installedApps.isEmpty)
              const Text('Installed apps could not be loaded.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _installedApps.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AppTheme.pureBlack.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final app = _installedApps[index];
                    final packageName = app.packageName;
                    final appName = app.name;
                    final Uint8List? iconBytes = app.iconBytes;
                    final selected = _selectedPackages.contains(packageName);

                    return CheckboxListTile(
                      value: selected,
                      onChanged: _isSaving
                          ? null
                          : (value) =>
                                _togglePackage(packageName, value ?? false),
                      secondary: iconBytes == null
                          ? const Icon(Icons.android, color: Colors.green)
                          : Image.memory(iconBytes, width: 28, height: 28),
                      title: Text(appName, overflow: TextOverflow.ellipsis),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.pureBlack,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppTheme.pureBlack.withValues(alpha: 0.62)),
        ),
      ],
    );
  }

  Widget _statusPill(bool granted) {
    final color = granted ? AppTheme.logoCyan : AppTheme.logoPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        granted ? 'Granted' : 'Missing',
        style: TextStyle(
          color: granted ? AppTheme.pureBlack : AppTheme.logoPurple,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _connectionPill(bool connected) {
    final color = connected ? AppTheme.logoCyan : AppTheme.logoPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        connected ? 'Connected' : 'Not connected',
        style: TextStyle(
          color: connected ? AppTheme.pureBlack : AppTheme.logoPurple,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PermissionStates {
  const _PermissionStates({
    required this.dndAccessGranted,
    required this.notificationListenerEnabled,
    required this.notificationPermissionGranted,
    required this.usageAccessGranted,
    required this.locationPermissionGranted,
    required this.backgroundLocationPermissionGranted,
    required this.activityRecognitionPermissionGranted,
  });

  final bool dndAccessGranted;
  final bool notificationListenerEnabled;
  final bool notificationPermissionGranted;
  final bool usageAccessGranted;
  final bool locationPermissionGranted;
  final bool backgroundLocationPermissionGranted;
  final bool activityRecognitionPermissionGranted;
}
