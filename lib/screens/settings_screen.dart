import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as d;

import '../database/database.dart';
import '../main.dart';
import '../services/app_catalog.dart';
import '../services/calendar_auth_service.dart';
import '../services/calendar_event_sync_service.dart';
import '../services/dnd_service.dart';
import '../theme/app_theme.dart';
import '../utils/saved_location_validation.dart';
import 'map_picker_screen.dart';
import 'settings/calendar_settings_screen.dart';
import 'settings/keyword_bypass_settings_screen.dart';
import 'settings/permissions_settings_screen.dart';
import 'settings/priority_app_alerts_settings_screen.dart';
import 'settings/saved_locations_settings_screen.dart';

enum SettingsSection {
  permissions,
  calendar,
  keywordBypass,
  priorityAppAlerts,
  savedLocations,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.section});

  final SettingsSection? section;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _keywordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _keywordBypassEnabled = false;
  bool _priorityAppAlertsEnabled = false;
  bool _dndAccessGranted = false;
  bool _notificationListenerEnabled = false;
  bool _notificationPermissionGranted = false;
  bool _usageAccessGranted = false;
  bool _locationPermissionGranted = false;
  bool _backgroundLocationPermissionGranted = false;
  bool _activityRecognitionPermissionGranted = false;
  bool _isCalendarAuthBusy = false;
  bool _isCalendarSyncBusy = false;
  bool _isCalendarDebugInfoLoading = false;
  bool _showCalendarDebugInfo = false;
  bool _isSavingSavedLocation = false;
  CalendarConnectionMetadata _calendarMetadata =
      const CalendarConnectionMetadata(connected: false);
  CalendarAuthDebugConfigurationInfo? _calendarDebugInfo;
  CalendarEventSyncResult? _lastCalendarSyncResult;
  List<String> _keywords = const ['urgent', 'emergency', 'asap'];
  Set<String> _selectedPackages = {};
  Set<String> _priorityAppAlertPackages = {};
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
    final priorityAppSettings = await DndService.getSelectedAppBypassSettings();
    final permissions = await _readPermissionStates();
    final calendarMetadata = await calendarAuthService.getConnectionMetadata();
    final apps = await appCatalog.loadInstalledApps();

    if (!mounted) return;
    setState(() {
      _keywordBypassEnabled = settings.enabled;
      _keywords = settings.keywords;
      _selectedPackages = settings.packages.toSet();
      _priorityAppAlertsEnabled = priorityAppSettings.enabled;
      _priorityAppAlertPackages = priorityAppSettings.packages.toSet();
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

  Future<void> _saveKeywordBypassSettings() async {
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
    if (value) {
      final canEnable = await _confirmAlertBypassSetup('Keyword bypass');
      if (!canEnable) return;
    }
    setState(() => _keywordBypassEnabled = value);
    await _saveKeywordBypassSettings();
    if (value && mounted) {
      await _showKeywordBypassChannelReminder();
    }
  }

  Future<bool> _confirmAlertBypassSetup(String featureName) async {
    final permissions = await _readPermissionStates();
    if (!mounted) return false;
    setState(() => _applyPermissionStates(permissions));

    final missing = <String>[];
    if (!permissions.notificationListenerEnabled) {
      missing.add('Notification access');
    }
    if (!permissions.notificationPermissionGranted) {
      missing.add('Notifications');
    }
    if (!permissions.dndAccessGranted) {
      missing.add('DND access');
    }

    if (missing.isEmpty) return true;

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$featureName setup'),
          content: Text(
            '$featureName needs ${missing.join(', ')} before it can reliably alert during automation DND.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );

    if (openSettings != true || !mounted) return false;

    if (!permissions.notificationListenerEnabled) {
      await _openNotificationAccessSettings();
    } else if (!permissions.notificationPermissionGranted) {
      await _requestNotificationPermission();
    } else if (!permissions.dndAccessGranted) {
      await _openDndAccessSettings();
    }
    return false;
  }

  Future<void> _showKeywordBypassChannelReminder() async {
    final channelStatus = await DndService.getEmergencyAlertChannelStatus();
    if (!mounted || channelStatus.canBypassDnd) return;

    await _showAlertChannelReminder(
      'To let Quietly emergency alerts make sound during DND, open Android notification settings and enable sound / Allow in Do Not Disturb for Quietly emergency alerts.',
    );
  }

  Future<void> _showPriorityAppAlertChannelReminder() async {
    final channelStatus = await DndService.getPriorityAppAlertChannelStatus();
    if (!mounted || channelStatus.canBypassDnd) return;

    await _showAlertChannelReminder(
      'To let Quietly priority app alerts make sound during DND, open Android notification settings and enable sound / Allow in Do Not Disturb for Quietly priority app alerts.',
    );
  }

  Future<void> _showAlertChannelReminder(String message) async {
    final openNotificationSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Allow alerts in DND'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open notifications'),
            ),
          ],
        );
      },
    );

    if (openNotificationSettings == true && mounted) {
      await DndService.openAppNotificationSettings();
    }
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
    await _saveKeywordBypassSettings();
  }

  Future<void> _removeKeyword(String keyword) async {
    setState(() {
      _keywords = _keywords.where((item) => item != keyword).toList();
    });
    await _saveKeywordBypassSettings();
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
    await _saveKeywordBypassSettings();
  }

  Future<void> _savePriorityAppAlertSettings() async {
    setState(() => _isSaving = true);
    await DndService.saveSelectedAppBypassSettings(
      enabled: _priorityAppAlertsEnabled,
      packages: _priorityAppAlertPackages.toList(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _setPriorityAppAlertsEnabled(bool value) async {
    if (value) {
      final canEnable = await _confirmAlertBypassSetup('Priority app alerts');
      if (!canEnable) return;
    }
    setState(() => _priorityAppAlertsEnabled = value);
    await _savePriorityAppAlertSettings();
    if (value && mounted) {
      await _showPriorityAppAlertChannelReminder();
    }
  }

  Future<void> _togglePriorityAppPackage(
    String packageName,
    bool selected,
  ) async {
    setState(() {
      if (selected) {
        _priorityAppAlertPackages = {..._priorityAppAlertPackages, packageName};
      } else {
        _priorityAppAlertPackages = _priorityAppAlertPackages
            .where((value) => value != packageName)
            .toSet();
      }
    });
    await _savePriorityAppAlertSettings();
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
    if (_showCalendarDebugInfo) {
      await _loadCalendarDebugInfo();
    }
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
      if (_showCalendarDebugInfo) {
        await _loadCalendarDebugInfo();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCalendarAuthBusy = false);
      _showSnackBar('Google Calendar could not be disconnected.');
    }
  }

  Future<void> _loadCalendarDebugInfo() async {
    if (kReleaseMode) return;
    setState(() => _isCalendarDebugInfoLoading = true);
    final debugInfo = await calendarAuthService.getDebugConfigurationInfo();
    if (!mounted) return;
    setState(() {
      _calendarDebugInfo = debugInfo;
      _isCalendarDebugInfoLoading = false;
    });
  }

  Future<void> _copyCalendarDebugInfo() async {
    final debugInfo =
        _calendarDebugInfo ??
        await calendarAuthService.getDebugConfigurationInfo();
    await Clipboard.setData(ClipboardData(text: debugInfo.toDebugText()));
    if (!mounted) return;
    _showSnackBar('Calendar sign-in debug info copied.');
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
    final section = widget.section;

    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle(section))),
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
                children: _pageChildren(section),
              ),
            ),
    );
  }

  String _pageTitle(SettingsSection? section) {
    return switch (section) {
      SettingsSection.permissions => 'Permissions',
      SettingsSection.calendar => 'Google Calendar',
      SettingsSection.keywordBypass => 'Emergency keyword bypass',
      SettingsSection.priorityAppAlerts => 'Priority app alerts',
      SettingsSection.savedLocations => 'Saved locations',
      null => 'Settings',
    };
  }

  List<Widget> _pageChildren(SettingsSection? section) {
    return switch (section) {
      SettingsSection.permissions => [_buildPermissionsSection()],
      SettingsSection.calendar => [_buildCalendarConnectionSection()],
      SettingsSection.keywordBypass => [_buildKeywordBypassSection()],
      SettingsSection.priorityAppAlerts => [_buildPriorityAppAlertsSection()],
      SettingsSection.savedLocations => [_buildSavedLocationsSection()],
      null => [_buildSettingsHub()],
    };
  }

  Widget _buildSettingsHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsHubCard(
          icon: Icons.verified_user_outlined,
          title: 'Permissions',
          description:
              'Manage DND, notification, usage, location, and activity access.',
          summary: _permissionSummary(),
          onTap: () => _openSettingsSection(SettingsSection.permissions),
        ),
        _settingsHubCard(
          icon: Icons.calendar_month_outlined,
          title: 'Google Calendar',
          description: 'Connect Calendar for meeting-based automation.',
          summary: _calendarSummary(),
          onTap: () => _openSettingsSection(SettingsSection.calendar),
        ),
        _settingsHubCard(
          icon: Icons.notification_important_outlined,
          title: 'Emergency keyword bypass',
          description: 'Alert when selected apps contain urgent keywords.',
          summary: _keywordBypassSummary(),
          onTap: () => _openSettingsSection(SettingsSection.keywordBypass),
        ),
        _settingsHubCard(
          icon: Icons.apps_outlined,
          title: 'Priority app alerts',
          description: 'Quietly alerts for notifications from selected apps.',
          summary: _priorityAppAlertsSummary(),
          onTap: () => _openSettingsSection(SettingsSection.priorityAppAlerts),
        ),
        StreamBuilder<List<SavedLocation>>(
          stream: database.watchActiveSavedLocations(),
          builder: (context, snapshot) {
            return _settingsHubCard(
              icon: Icons.place_outlined,
              title: 'Saved locations',
              description:
                  'Manage reusable places like Home, Office, or Library.',
              summary: _savedLocationsSummary(snapshot.data),
              onTap: () => _openSettingsSection(SettingsSection.savedLocations),
            );
          },
        ),
      ],
    );
  }

  Widget _settingsHubCard({
    required IconData icon,
    required String title,
    required String description,
    required String summary,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPadding,
          vertical: 10,
        ),
        leading: Icon(icon, color: AppTheme.logoBlue),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.pureBlack,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.pureBlack.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openSettingsSection(SettingsSection section) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _settingsSectionPage(section)),
    );
    if (mounted) {
      await _loadSettings();
    }
  }

  Widget _settingsSectionPage(SettingsSection section) {
    return switch (section) {
      SettingsSection.permissions => const PermissionsSettingsScreen(),
      SettingsSection.calendar => const CalendarSettingsScreen(),
      SettingsSection.keywordBypass => const KeywordBypassSettingsScreen(),
      SettingsSection.priorityAppAlerts =>
        const PriorityAppAlertsSettingsScreen(),
      SettingsSection.savedLocations => const SavedLocationsSettingsScreen(),
    };
  }

  String _permissionSummary() {
    final grantedCount = [
      _dndAccessGranted,
      _notificationListenerEnabled,
      _notificationPermissionGranted,
      _usageAccessGranted,
      _locationPermissionGranted,
      _backgroundLocationPermissionGranted,
      _activityRecognitionPermissionGranted,
    ].where((granted) => granted).length;
    if (grantedCount == 7) return '7/7 granted';
    return 'Some permissions missing';
  }

  String _calendarSummary() {
    if (_calendarMetadata.connected) {
      final email = _calendarMetadata.email;
      return email == null || email.isEmpty
          ? 'Connected'
          : 'Connected as $email';
    }
    return 'Not connected';
  }

  String _keywordBypassSummary() {
    if (!_keywordBypassEnabled) return 'Disabled';
    final keywordText = _keywords.length == 1
        ? '1 keyword'
        : '${_keywords.length} keywords';
    return 'Enabled, $keywordText';
  }

  String _priorityAppAlertsSummary() {
    if (!_priorityAppAlertsEnabled) return 'Disabled';
    final appText = _priorityAppAlertPackages.length == 1
        ? '1 app'
        : '${_priorityAppAlertPackages.length} apps';
    return 'Enabled, $appText';
  }

  String _savedLocationsSummary(List<SavedLocation>? locations) {
    final count = locations?.length;
    if (count == null) return 'Tap to manage';
    if (count == 0) return 'None saved';
    if (count == 1) return '1 saved location';
    return '$count saved locations';
  }

  Widget _buildPermissionsSection() {
    final rows = <Widget>[
      _buildPermissionRow(
        icon: Icons.do_not_disturb_on,
        title: 'DND access',
        description: 'Required for DND automation and DND policy exceptions.',
        granted: _dndAccessGranted,
        onPressed: _openDndAccessSettings,
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.notifications_active,
        title: 'Notification access',
        description:
            'Required for emergency keyword bypass and priority app alerts.',
        granted: _notificationListenerEnabled,
        onPressed: _openNotificationAccessSettings,
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.notification_important,
        title: 'Notifications',
        description: 'Required to show Quietly alert notifications.',
        granted: _notificationPermissionGranted,
        onPressed: _requestNotificationPermission,
        actionLabel: 'Grant',
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.query_stats,
        title: 'Usage access',
        description: 'Required for app foreground triggers.',
        granted: _usageAccessGranted,
        onPressed: _openUsageAccessSettings,
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.location_on,
        title: 'Location',
        description: 'Needed to choose places for location rules.',
        granted: _locationPermissionGranted,
        onPressed: _requestLocationPermission,
        actionLabel: 'Grant',
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.my_location,
        title: 'Background location',
        description: 'Lets geofence rules activate when Quietly is not open.',
        granted: _backgroundLocationPermissionGranted,
        onPressed: _requestBackgroundLocationPermission,
        actionLabel: 'Grant',
      ),
      _permissionDivider(),
      _buildPermissionRow(
        icon: Icons.directions_walk,
        title: 'Activity recognition',
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

  Widget _buildSavedLocationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Saved locations',
          'Save places like Home, Office, or Library so you can reuse them in location rules.',
        ),
        const SizedBox(height: 8),
        Card(
          child: StreamBuilder<List<SavedLocation>>(
            stream: database.watchActiveSavedLocations(),
            builder: (context, snapshot) {
              final locations = snapshot.data ?? const <SavedLocation>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(AppTheme.cardPadding),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return Column(
                children: [
                  if (locations.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.place_outlined),
                      title: Text('No saved locations yet.'),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: locations.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppTheme.pureBlack.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        return _buildSavedLocationTile(locations[index]);
                      },
                    ),
                  Divider(
                    height: 1,
                    color: AppTheme.pureBlack.withValues(alpha: 0.1),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.cardPadding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _isSavingSavedLocation
                            ? null
                            : _addSavedLocation,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add location'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedLocationTile(SavedLocation location) {
    final subtitleLines = <String>[];
    final address = _cleanText(location.address);
    if (address != null) {
      subtitleLines.add(address);
    } else {
      subtitleLines.add(
        '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
      );
    }
    subtitleLines.add('Radius: ${location.radius}m');

    return ListTile(
      leading: const Icon(Icons.place, color: AppTheme.logoBlue),
      title: Text(
        location.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitleLines.join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Edit location',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editSavedLocation(location),
          ),
          IconButton(
            tooltip: 'Remove location',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmArchiveSavedLocation(location),
          ),
        ],
      ),
    );
  }

  Future<void> _addSavedLocation() async {
    _logSavedLocationDebug('Add saved location flow started.');
    final name = await _promptSavedLocationName(title: 'Add location');
    if (!mounted) return;
    if (name == null) {
      _logSavedLocationDebug('Add saved location cancelled at name step.');
      return;
    }
    _logSavedLocationDebug('Add saved location name accepted: "$name".');

    final picked = await _pickSavedLocation();
    if (!mounted) return;
    if (picked == null) {
      _logSavedLocationDebug('Add saved location cancelled at map step.');
      return;
    }

    final validationError = _validatePickedLocation(picked);
    if (validationError != null) {
      _logSavedLocationDebug(
        'Add saved location validation failed: $validationError',
      );
      _showSnackBar(validationError);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _logSavedLocationDebug(
      'createSavedLocation starting: name="$name", '
      'lat=${picked.latitude}, lng=${picked.longitude}, '
      'radius=${picked.radius}, hasAddress=${picked.address != null}.',
    );
    if (mounted) {
      setState(() => _isSavingSavedLocation = true);
    }
    try {
      await database.createSavedLocation(
        SavedLocationsCompanion.insert(
          name: name,
          latitude: picked.latitude,
          longitude: picked.longitude,
          radius: picked.radius,
          address: d.Value(picked.address),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      _showSnackBar('Saved location added.');
      _logSavedLocationDebug('createSavedLocation succeeded.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      _logSavedLocationDebug('createSavedLocation validation error: $error');
      _showSnackBar(error.message?.toString() ?? 'Saved location is invalid.');
    } catch (error, stackTrace) {
      debugPrint('[SavedLocations] createSavedLocation failed: $error');
      debugPrintStack(
        label: '[SavedLocations] createSavedLocation stack trace',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('Saved location could not be saved.');
    } finally {
      if (mounted) {
        setState(() => _isSavingSavedLocation = false);
      }
    }
  }

  Future<void> _editSavedLocation(SavedLocation location) async {
    _logSavedLocationDebug(
      'Edit saved location flow started: id=${location.id}.',
    );
    final name = await _promptSavedLocationName(
      title: 'Edit location',
      initialName: location.name,
    );
    if (!mounted) return;
    if (name == null) {
      _logSavedLocationDebug('Edit saved location cancelled at name step.');
      return;
    }
    _logSavedLocationDebug('Edit saved location name accepted: "$name".');

    final picked = await _pickSavedLocation(initialLocation: location);
    if (!mounted) return;
    if (picked == null) {
      _logSavedLocationDebug('Edit saved location cancelled at map step.');
      return;
    }

    final validationError = _validatePickedLocation(picked);
    if (validationError != null) {
      _logSavedLocationDebug(
        'Edit saved location validation failed: $validationError',
      );
      _showSnackBar(validationError);
      return;
    }

    _logSavedLocationDebug(
      'updateSavedLocation starting: id=${location.id}, name="$name", '
      'lat=${picked.latitude}, lng=${picked.longitude}, '
      'radius=${picked.radius}, hasAddress=${picked.address != null}.',
    );
    if (mounted) {
      setState(() => _isSavingSavedLocation = true);
    }
    try {
      await database.updateSavedLocation(
        location.copyWith(
          name: name,
          latitude: picked.latitude,
          longitude: picked.longitude,
          radius: picked.radius,
          address: d.Value(picked.address),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await automationManager.syncRulesToAndroid();
      if (!mounted) return;
      _showSnackBar('Saved location updated.');
      _logSavedLocationDebug(
        'updateSavedLocation succeeded: id=${location.id}.',
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      _logSavedLocationDebug('updateSavedLocation validation error: $error');
      _showSnackBar(error.message?.toString() ?? 'Saved location is invalid.');
    } catch (error, stackTrace) {
      debugPrint('[SavedLocations] updateSavedLocation failed: $error');
      debugPrintStack(
        label: '[SavedLocations] updateSavedLocation stack trace',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('Saved location could not be updated.');
    } finally {
      if (mounted) {
        setState(() => _isSavingSavedLocation = false);
      }
    }
  }

  Future<void> _confirmArchiveSavedLocation(SavedLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove saved location?'),
          content: const Text(
            'Existing rules using this place will keep working because they store a copy of the coordinates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      _logSavedLocationDebug(
        'archiveSavedLocation starting: id=${location.id}.',
      );
      await database.archiveSavedLocation(location.id);
      if (!mounted) return;
      _showSnackBar('Saved location removed.');
      _logSavedLocationDebug(
        'archiveSavedLocation succeeded: id=${location.id}.',
      );
    } catch (error, stackTrace) {
      debugPrint('[SavedLocations] archiveSavedLocation failed: $error');
      debugPrintStack(
        label: '[SavedLocations] archiveSavedLocation stack trace',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('Saved location could not be removed.');
    }
  }

  Future<String?> _promptSavedLocationName({
    required String title,
    String? initialName,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _SavedLocationNameDialog(title: title, initialName: initialName),
    );
  }

  Future<_PickedSavedLocation?> _pickSavedLocation({
    SavedLocation? initialLocation,
  }) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: initialLocation?.latitude,
          initialLongitude: initialLocation?.longitude,
          initialRadius: initialLocation?.radius.toDouble(),
          initialAddress: initialLocation?.address,
        ),
      ),
    );
    if (result == null) {
      _logSavedLocationDebug('MapPicker returned null.');
      return null;
    }
    if (result is! Map) {
      _logSavedLocationDebug(
        'MapPicker returned unexpected result type: ${result.runtimeType}.',
      );
      return const _PickedSavedLocation.invalid();
    }

    final latitude = result['latitude'];
    final longitude = result['longitude'];
    final radius = result['radius'];
    _logSavedLocationDebug(
      'MapPicker returned keys=${result.keys.join(',')}, '
      'latType=${latitude.runtimeType}, lngType=${longitude.runtimeType}, '
      'radiusType=${radius.runtimeType}, addressType=${result['address'].runtimeType}.',
    );
    if (latitude is! num || longitude is! num || radius is! num) {
      _logSavedLocationDebug(
        'MapPicker result invalid: missing numeric latitude/longitude/radius.',
      );
      return const _PickedSavedLocation.invalid();
    }

    final parsed = _PickedSavedLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      radius: radius.round(),
      address: _cleanText(result['address']?.toString()),
    );
    _logSavedLocationDebug(
      'MapPicker parsed result: lat=${parsed.latitude}, '
      'lng=${parsed.longitude}, radius=${parsed.radius}, '
      'hasAddress=${parsed.address != null}.',
    );
    return parsed;
  }

  String? _validatePickedLocation(_PickedSavedLocation picked) {
    if (!picked.isValid) return 'Please select a location and radius.';
    if (!picked.latitude.isFinite || !picked.longitude.isFinite) {
      return 'Please select a valid map location.';
    }
    if (picked.radius < 50) {
      return 'Please select a radius of at least 50m.';
    }
    return null;
  }

  void _logSavedLocationDebug(String message) {
    debugPrint('[SavedLocations] $message');
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
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.pureBlack,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            _statusPill(granted),
          ],
        ),
      ),
      trailing: granted
          ? const Icon(Icons.check_circle, color: AppTheme.logoCyan)
          : TextButton(
              onPressed: onPressed,
              child: Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      onTap: granted ? _refreshPermissionStates : onPressed,
    );
  }

  Widget _buildCalendarConnectionSection() {
    final connected = _calendarMetadata.connected;
    final email = _calendarMetadata.email;

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
                title: const Text(
                  'Google Calendar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.pureBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _calendarConnectionStatusText(connected, email),
                      const SizedBox(height: 6),
                      _connectionPill(connected),
                    ],
                  ),
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
                      : Text(
                          connected ? 'Disconnect' : 'Connect',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.pureBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _calendarSyncStatusText(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
              if (!kReleaseMode) ...[
                Divider(
                  height: 1,
                  color: AppTheme.pureBlack.withValues(alpha: 0.1),
                ),
                _buildCalendarDebugInfoTile(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _calendarConnectionStatusText(bool connected, String? email) {
    final cleanEmail = _cleanText(email);
    if (!connected) {
      return const Text('Not connected');
    }
    if (cleanEmail == null) {
      return const Text('Connected');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Connected as'),
        Text(
          cleanEmail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ],
    );
  }

  Widget _buildCalendarDebugInfoTile() {
    final debugInfo = _calendarDebugInfo;

    return ExpansionTile(
      title: const Text('Calendar sign-in debug info'),
      subtitle: const Text('Development diagnostics'),
      initiallyExpanded: _showCalendarDebugInfo,
      onExpansionChanged: (expanded) {
        setState(() => _showCalendarDebugInfo = expanded);
        if (expanded) {
          _loadCalendarDebugInfo();
        }
      },
      childrenPadding: const EdgeInsets.fromLTRB(
        AppTheme.cardPadding,
        0,
        AppTheme.cardPadding,
        AppTheme.cardPadding,
      ),
      children: [
        if (_isCalendarDebugInfoLoading && debugInfo == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _isCalendarDebugInfoLoading
                      ? null
                      : _loadCalendarDebugInfo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                TextButton.icon(
                  onPressed: debugInfo == null ? null : _copyCalendarDebugInfo,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy debug info'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.pureBlack.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.pureBlack.withValues(alpha: 0.08),
              ),
            ),
            child: SelectableText(
              debugInfo?.toDebugText() ?? 'Debug info unavailable.',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
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
          child: SwitchListTile(
            title: const Text('Emergency keyword bypass'),
            subtitle: const Text(
              'Detect selected keywords from monitored app notifications while automation DND is active.',
            ),
            value: _keywordBypassEnabled,
            onChanged: _isSaving ? null : _setKeywordBypassEnabled,
          ),
        ),
        const SizedBox(height: 16),
        _buildKeywordEditor(),
        const SizedBox(height: 16),
        _buildMonitoredAppSelector(),
      ],
    );
  }

  Widget _buildPriorityAppAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Priority app alerts',
          'When Quietly automation DND is active, notifications from selected apps can trigger a Quietly alert.',
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            title: const Text('Priority app alerts'),
            subtitle: const Text(
              'Post a Quietly alert when selected apps notify during automation DND.',
            ),
            value: _priorityAppAlertsEnabled,
            onChanged: _isSaving ? null : _setPriorityAppAlertsEnabled,
          ),
        ),
        if (!_notificationListenerEnabled) ...[
          const SizedBox(height: 12),
          _buildNotificationListenerWarning(),
        ],
        const SizedBox(height: 16),
        _buildPriorityAppSelector(),
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
                  label: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 128,
                    ),
                    child: Text(
                      keyword,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
    return _buildAppSelectorCard(
      title: 'Monitored apps',
      selectedPackages: _selectedPackages,
      onChanged: _togglePackage,
    );
  }

  Widget _buildPriorityAppSelector() {
    return _buildAppSelectorCard(
      title: 'Selected apps',
      selectedPackages: _priorityAppAlertPackages,
      onChanged: _togglePriorityAppPackage,
    );
  }

  Widget _buildNotificationListenerWarning() {
    return Card(
      color: AppTheme.logoCyan.withValues(alpha: 0.14),
      child: ListTile(
        leading: const Icon(Icons.notifications_active),
        title: const Text(
          'Notification access needed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text(
          'Quietly needs notification listener access to detect selected app notifications.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: _openNotificationAccessSettings,
          child: const Text('Open'),
        ),
      ),
    );
  }

  Widget _buildAppSelectorCard({
    required String title,
    required Set<String> selectedPackages,
    required Future<void> Function(String packageName, bool selected) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              selectedPackages.isEmpty
                  ? 'No apps selected'
                  : '${selectedPackages.length} apps selected',
              style: TextStyle(
                color: AppTheme.pureBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            if (selectedPackages.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedPackages.map((packageName) {
                  return InputChip(
                    label: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 128,
                      ),
                      child: Text(
                        _appLabel(packageName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onDeleted: _isSaving
                        ? null
                        : () => onChanged(packageName, false),
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
                    final selected = selectedPackages.contains(packageName);

                    return CheckboxListTile(
                      value: selected,
                      onChanged: _isSaving
                          ? null
                          : (value) => onChanged(packageName, value ?? false),
                      secondary: iconBytes == null
                          ? const Icon(Icons.android, color: Colors.green)
                          : Image.memory(iconBytes, width: 28, height: 28),
                      title: Text(
                        appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.pureBlack,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: connected ? AppTheme.pureBlack : AppTheme.logoPurple,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PickedSavedLocation {
  const _PickedSavedLocation({
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.address,
  }) : isValid = true;

  const _PickedSavedLocation.invalid()
    : latitude = 0,
      longitude = 0,
      radius = 0,
      address = null,
      isValid = false;

  final double latitude;
  final double longitude;
  final int radius;
  final String? address;
  final bool isValid;
}

class _SavedLocationNameDialog extends StatefulWidget {
  const _SavedLocationNameDialog({required this.title, this.initialName});

  final String title;
  final String? initialName;

  @override
  State<_SavedLocationNameDialog> createState() =>
      _SavedLocationNameDialogState();
}

class _SavedLocationNameDialogState extends State<_SavedLocationNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText == null) return;
    setState(() => _errorText = null);
  }

  void _submit() {
    final cleaned = cleanSavedLocationName(_controller.text);
    if (cleaned == null) {
      setState(() => _errorText = 'Enter a name.');
      return;
    }
    Navigator.of(context).pop(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Location name',
          hintText: 'Home, Office, Library',
          errorText: _errorText,
        ),
        textInputAction: TextInputAction.done,
        onChanged: (_) => _clearError(),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Next')),
      ],
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

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
