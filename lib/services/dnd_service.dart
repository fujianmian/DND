import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class KeywordBypassSettings {
  const KeywordBypassSettings({
    required this.enabled,
    required this.keywords,
    required this.packages,
  });

  final bool enabled;
  final List<String> keywords;
  final List<String> packages;
}

class SelectedAppBypassSettings {
  const SelectedAppBypassSettings({
    required this.enabled,
    required this.packages,
  });

  final bool enabled;
  final List<String> packages;
}

class AutomationDndState {
  const AutomationDndState({
    required this.automationDndActive,
    required this.activeAutomationRuleNames,
    required this.lastAutomationDndChangedAt,
  });

  final bool automationDndActive;
  final List<String> activeAutomationRuleNames;
  final DateTime? lastAutomationDndChangedAt;
}

class AutomationPauseState {
  const AutomationPauseState({
    required this.automationPaused,
    required this.pauseUntilMillis,
    required this.pausedAtMillis,
    required this.pauseReason,
  });

  factory AutomationPauseState.fromPlatformMap(Map<dynamic, dynamic>? map) {
    return AutomationPauseState(
      automationPaused: map?['automationPaused'] as bool? ?? false,
      pauseUntilMillis: _intValue(map?['pauseUntilMillis']),
      pausedAtMillis: _intValue(map?['pausedAtMillis']),
      pauseReason: map?['pauseReason']?.toString() ?? 'manual',
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  final bool automationPaused;
  final int pauseUntilMillis;
  final int pausedAtMillis;
  final String pauseReason;

  bool get isIndefinite => automationPaused && pauseUntilMillis <= 0;

  bool get isExpired {
    if (!automationPaused || pauseUntilMillis <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch >= pauseUntilMillis;
  }

  DateTime? get pauseUntil {
    if (pauseUntilMillis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(pauseUntilMillis);
  }

  DateTime? get pausedAt {
    if (pausedAtMillis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(pausedAtMillis);
  }
}

class DndService {
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  // --- DND Permissions ---
  static Future<bool> isPermissionGranted() async {
    try {
      final bool result = await platform.invokeMethod('checkPermission');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> openDndSettings() async {
    try {
      await platform.invokeMethod('openDndSettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open DND settings: '${e.message}'.");
    }
  }

  static Future<bool> isNotificationListenerEnabled() async {
    try {
      final bool result = await platform.invokeMethod(
        'isNotificationListenerEnabled',
      );
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationListenerSettings() async {
    try {
      await platform.invokeMethod('openNotificationListenerSettings');
    } on PlatformException catch (e) {
      debugPrint(
        "Failed to open Notification Listener settings: '${e.message}'.",
      );
    }
  }

  static Future<bool> isNotificationPermissionGranted() async {
    try {
      final bool result = await platform.invokeMethod(
        'checkNotificationPermission',
      );
      return result;
    } on PlatformException catch (_) {
      return Permission.notification.isGranted;
    }
  }

  static Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  static Future<bool> isLocationPermissionGranted() async {
    return Permission.location.isGranted;
  }

  static Future<void> requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  static Future<bool> isBackgroundLocationPermissionGranted() async {
    return Permission.locationAlways.isGranted;
  }

  static Future<void> requestBackgroundLocationPermission() async {
    final status = await Permission.locationAlways.request();
    if (!status.isGranted) {
      await openAppSettings();
    }
  }

  static Future<bool> isActivityRecognitionPermissionGranted() async {
    return Permission.activityRecognition.isGranted;
  }

  static Future<void> requestActivityRecognitionPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  static Future<KeywordBypassSettings> getKeywordBypassSettings() async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getKeywordBypassSettings',
      );
      return KeywordBypassSettings(
        enabled: result?['enabled'] as bool? ?? false,
        keywords:
            (result?['keywords'] as List<dynamic>?)
                ?.map((value) => value.toString())
                .toList() ??
            const ['urgent', 'emergency', 'asap'],
        packages:
            (result?['packages'] as List<dynamic>?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to load keyword bypass settings: '${e.message}'.");
      return const KeywordBypassSettings(
        enabled: false,
        keywords: ['urgent', 'emergency', 'asap'],
        packages: [],
      );
    }
  }

  static Future<void> saveKeywordBypassSettings({
    required bool enabled,
    required List<String> keywords,
    required List<String> packages,
  }) async {
    try {
      await platform.invokeMethod('saveKeywordBypassSettings', {
        'enabled': enabled,
        'keywords': keywords,
        'packages': packages,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to save keyword bypass settings: '${e.message}'.");
    }
  }

  static Future<SelectedAppBypassSettings>
  getSelectedAppBypassSettings() async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getSelectedAppBypassSettings',
      );
      return SelectedAppBypassSettings(
        enabled: result?['enabled'] as bool? ?? false,
        packages:
            (result?['packages'] as List<dynamic>?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
      );
    } on PlatformException catch (e) {
      debugPrint(
        "Failed to load selected app bypass settings: '${e.message}'.",
      );
      return const SelectedAppBypassSettings(enabled: false, packages: []);
    }
  }

  static Future<void> saveSelectedAppBypassSettings({
    required bool enabled,
    required List<String> packages,
  }) async {
    try {
      await platform.invokeMethod('saveSelectedAppBypassSettings', {
        'enabled': enabled,
        'packages': packages,
      });
    } on PlatformException catch (e) {
      debugPrint(
        "Failed to save selected app bypass settings: '${e.message}'.",
      );
    }
  }

  static Future<void> enableDnd() async {
    try {
      await platform.invokeMethod('enableDnd');
    } on PlatformException catch (e) {
      debugPrint("Failed to enable DND: '${e.message}'.");
    }
  }

  static Future<void> disableDnd() async {
    try {
      await platform.invokeMethod('disableDnd');
    } on PlatformException catch (e) {
      debugPrint("Failed to disable DND: '${e.message}'.");
    }
  }

  // --- Usage Stats Permissions ---
  static Future<bool> isUsagePermissionGranted() async {
    try {
      final bool result = await platform.invokeMethod('checkUsagePermission');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await platform.invokeMethod('openUsageSettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open Usage settings: '${e.message}'.");
    }
  }

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final List<dynamic> apps = await platform.invokeMethod(
        'getInstalledApps',
      );
      return apps.map((app) => Map<String, dynamic>.from(app)).toList();
    } on PlatformException catch (e) {
      debugPrint("Failed to get installed apps: '${e.message}'.");
      return [];
    }
  }

  // --- Fetch Individual App Details (Name & Icon) ---
  static Future<Map<String, dynamic>?> getAppInfo(String packageName) async {
    try {
      final result = await platform.invokeMethod('getAppInfo', {
        'packageName': packageName,
      });
      if (result != null) {
        return {
          'name': result['name'] as String,
          'icon': result['icon'] as Uint8List?,
        };
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get app info: '${e.message}'.");
    }
    return null;
  }

  static Future<AutomationDndState?> getAutomationDndState() async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getAutomationDndState',
      );
      if (result == null) return null;

      final ruleNamesText =
          result['activeAutomationRuleNames'] as String? ?? '';
      final changedAtMillis =
          (result['lastAutomationDndChangedAt'] as num?)?.toInt() ?? 0;

      return AutomationDndState(
        automationDndActive: result['automationDndActive'] as bool? ?? false,
        activeAutomationRuleNames: ruleNamesText
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toList(),
        lastAutomationDndChangedAt: changedAtMillis <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(changedAtMillis),
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to load automation DND state: '${e.message}'.");
    } catch (e) {
      debugPrint("Failed to load automation DND state: '$e'.");
    }
    return null;
  }

  static Future<AutomationPauseState> getAutomationPauseState() async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getAutomationPauseState',
      );
      return AutomationPauseState.fromPlatformMap(result);
    } on PlatformException catch (e) {
      debugPrint("Failed to load automation pause state: '${e.message}'.");
    } catch (e) {
      debugPrint("Failed to load automation pause state: '$e'.");
    }
    return const AutomationPauseState(
      automationPaused: false,
      pauseUntilMillis: 0,
      pausedAtMillis: 0,
      pauseReason: 'manual',
    );
  }

  static Future<AutomationPauseState> pauseAutomation(
    Duration? duration,
  ) async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'pauseAutomation',
        {'durationMillis': duration?.inMilliseconds},
      );
      return AutomationPauseState.fromPlatformMap(result);
    } on PlatformException catch (e) {
      debugPrint("Failed to pause automation: '${e.message}'.");
    } catch (e) {
      debugPrint("Failed to pause automation: '$e'.");
    }
    return getAutomationPauseState();
  }

  static Future<AutomationPauseState> resumeAutomation() async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'resumeAutomation',
      );
      return AutomationPauseState.fromPlatformMap(result);
    } on PlatformException catch (e) {
      debugPrint("Failed to resume automation: '${e.message}'.");
    } catch (e) {
      debugPrint("Failed to resume automation: '$e'.");
    }
    return getAutomationPauseState();
  }

  static Future<Map<String, dynamic>> getAppDebugInfo() async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getAppDebugInfo',
      );
      return Map<String, dynamic>.from(result ?? const {});
    } on PlatformException catch (e) {
      debugPrint(
        "Failed to load app debug info: code='${e.code}', "
        "message='${e.message}', details='${e.details}'.",
      );
      return <String, dynamic>{
        'platformError': '${e.code}: ${e.message ?? 'unknown platform error'}',
      };
    }
  }

  // --- Foreground Service Sync ---
  static Future<void> syncRulesToService(
    List<Map<String, dynamic>> timeRules,
    List<Map<String, dynamic>> locRules,
    List<Map<String, dynamic>> appRules,
    List<Map<String, dynamic>> activityRules,
    String automationRulesJson,
    String calendarBusyWindowsJson,
  ) async {
    try {
      final timeRuleIds = timeRules.map((e) => e['id'] as String).toList();
      final timeRuleNames = timeRules.map((e) => e['name'] as String).toList();
      final startHours = timeRules.map((e) => e['startHour'] as int).toList();
      final startMinutes = timeRules
          .map((e) => e['startMinute'] as int)
          .toList();
      final endHours = timeRules.map((e) => e['endHour'] as int).toList();
      final endMinutes = timeRules.map((e) => e['endMinute'] as int).toList();
      final timeRepeatModes = timeRules
          .map((e) => e['timeRepeatMode'] as int? ?? 0)
          .toList();
      final timeRepeatDaysMasks = timeRules
          .map((e) => e['timeRepeatDaysMask'] as int? ?? 127)
          .toList();
      final timeAllowStarredContacts = timeRules
          .map((e) => e['allowStarredContacts'] as bool)
          .toList();
      final timeAllowRepeatCallers = timeRules
          .map((e) => e['allowRepeatCallers'] as bool)
          .toList();

      final locIds = locRules.map((e) => e['id'] as String).toList();
      final locNames = locRules.map((e) => e['name'] as String).toList();
      final lats = locRules.map((e) => e['lat'] as double).toList();
      final lngs = locRules.map((e) => e['lng'] as double).toList();
      final rads = locRules.map((e) => e['rad'] as int).toList();
      final locAllowStarredContacts = locRules
          .map((e) => e['allowStarredContacts'] as bool)
          .toList();
      final locAllowRepeatCallers = locRules
          .map((e) => e['allowRepeatCallers'] as bool)
          .toList();

      final appRuleIds = appRules.map((e) => e['id'] as String).toList();
      final appRuleNames = appRules.map((e) => e['name'] as String).toList();
      final appPackages = appRules
          .map((e) => e['packageName'] as String)
          .toList();
      final appAllowStarredContacts = appRules
          .map((e) => e['allowStarredContacts'] as bool)
          .toList();
      final appAllowRepeatCallers = appRules
          .map((e) => e['allowRepeatCallers'] as bool)
          .toList();

      final activityRuleIds = activityRules
          .map((e) => e['id'] as String)
          .toList();
      final activityRuleNames = activityRules
          .map((e) => e['name'] as String)
          .toList();
      final activityTypes = activityRules
          .map((e) => e['activityType'] as String)
          .toList();
      final activityAllowStarredContacts = activityRules
          .map((e) => e['allowStarredContacts'] as bool)
          .toList();
      final activityAllowRepeatCallers = activityRules
          .map((e) => e['allowRepeatCallers'] as bool)
          .toList();

      await platform.invokeMethod('startService', {
        'timeRuleIds': timeRuleIds,
        'timeRuleNames': timeRuleNames,
        'startHours': startHours,
        'startMinutes': startMinutes,
        'endHours': endHours,
        'endMinutes': endMinutes,
        'timeRepeatModes': timeRepeatModes,
        'timeRepeatDaysMasks': timeRepeatDaysMasks,
        'timeAllowStarredContacts': timeAllowStarredContacts,
        'timeAllowRepeatCallers': timeAllowRepeatCallers,
        'locIds': locIds,
        'locNames': locNames,
        'lats': lats,
        'lngs': lngs,
        'rads': rads,
        'locAllowStarredContacts': locAllowStarredContacts,
        'locAllowRepeatCallers': locAllowRepeatCallers,
        'appRuleIds': appRuleIds,
        'appRuleNames': appRuleNames,
        'appPackages': appPackages,
        'appAllowStarredContacts': appAllowStarredContacts,
        'appAllowRepeatCallers': appAllowRepeatCallers,
        'activityRuleIds': activityRuleIds,
        'activityRuleNames': activityRuleNames,
        'activityTypes': activityTypes,
        'activityAllowStarredContacts': activityAllowStarredContacts,
        'activityAllowRepeatCallers': activityAllowRepeatCallers,
        'automationRulesJson': automationRulesJson,
        'calendarBusyWindowsJson': calendarBusyWindowsJson,
      });
      debugPrint("Successfully synced ALL rules to Android Service.");
    } on PlatformException catch (e) {
      debugPrint("Failed to start service: '${e.message}'.");
    }
  }

  static Future<void> stopService() async {
    try {
      await platform.invokeMethod('stopService');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop service: '${e.message}'.");
    }
  }
}
