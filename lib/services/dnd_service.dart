import 'package:flutter/services.dart';

class DndService {
  // 1. Define the MethodChannel with a unique name
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  // Method to enable DND (kept for manual overrides if needed)
  static Future<void> enableDnd() async {
    try {
      await platform.invokeMethod('enableDnd');
    } on PlatformException catch (e) {
      print("Failed to enable DND: '${e.message}'.");
    }
  }

  // Method to disable DND (kept for manual overrides if needed)
  static Future<void> disableDnd() async {
    try {
      await platform.invokeMethod('disableDnd');
    } on PlatformException catch (e) {
      print("Failed to disable DND: '${e.message}'.");
    }
  }

  // Method to check if we have permission (Policy Access)
  static Future<bool> isPermissionGranted() async {
    try {
      final bool result = await platform.invokeMethod('checkPermission');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check permission: '${e.message}'.");
      return false;
    }
  }

  // Method to open the system settings for DND permission
  static Future<void> openDndSettings() async {
    try {
      await platform.invokeMethod('openDndSettings');
    } on PlatformException catch (e) {
      print("Failed to open settings: '${e.message}'.");
    }
  }

  // NEW: Sync all rules to the Android Foreground Service via arrays
  static Future<void> syncRulesToService(
    List<Map<String, dynamic>> timeRules,
    List<Map<String, dynamic>> locationRules,
  ) async {
    try {
      await platform.invokeMethod('startService', {
        // Time rules arrays
        "startHours": timeRules.map((r) => r['startHour'] as int).toList(),
        "startMinutes": timeRules.map((r) => r['startMinute'] as int).toList(),
        "endHours": timeRules.map((r) => r['endHour'] as int).toList(),
        "endMinutes": timeRules.map((r) => r['endMinute'] as int).toList(),

        // Location rules arrays
        "locIds": locationRules.map((r) => r['id'].toString()).toList(),
        "lats": locationRules.map((r) => r['lat'] as double).toList(),
        "lngs": locationRules.map((r) => r['lng'] as double).toList(),
        "rads": locationRules.map((r) => r['rad'] as int).toList(),
      });
      print(
        'Successfully synced ${timeRules.length} time rules and ${locationRules.length} location rules to Android.',
      );
    } on PlatformException catch (e) {
      print("Failed to sync rules to foreground service: '${e.message}'.");
    }
  }
}
