import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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

  // --- NEW: Usage Stats Permissions ---
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

  // --- Foreground Service Sync ---
  static Future<void> syncRulesToService(
    List<Map<String, dynamic>> timeRules,
    List<Map<String, dynamic>> locRules,
    List<String> appPackages, // 🔹 NEW: Add App Packages
  ) async {
    try {
      List<int> startHours = timeRules
          .map((e) => e['startHour'] as int)
          .toList();
      List<int> startMinutes = timeRules
          .map((e) => e['startMinute'] as int)
          .toList();
      List<int> endHours = timeRules.map((e) => e['endHour'] as int).toList();
      List<int> endMinutes = timeRules
          .map((e) => e['endMinute'] as int)
          .toList();

      List<String> locIds = locRules.map((e) => e['id'] as String).toList();
      List<double> lats = locRules.map((e) => e['lat'] as double).toList();
      List<double> lngs = locRules.map((e) => e['lng'] as double).toList();
      List<int> rads = locRules.map((e) => e['rad'] as int).toList();

      await platform.invokeMethod('startService', {
        'startHours': startHours,
        'startMinutes': startMinutes,
        'endHours': endHours,
        'endMinutes': endMinutes,

        'locIds': locIds,
        'lats': lats,
        'lngs': lngs,
        'rads': rads,

        // 🔹 Pass App Packages to Kotlin
        'appPackages': appPackages,
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
