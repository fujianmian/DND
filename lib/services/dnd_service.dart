import 'package:flutter/services.dart';

class DndService {
  // 1. Define the MethodChannel with a unique name
  static const platform = MethodChannel('com.example.dnd_auto_app/dnd');

  // 2. Method to enable DND
  static Future<void> enableDnd() async {
    try {
      await platform.invokeMethod('enableDnd');
    } on PlatformException catch (e) {
      print("Failed to enable DND: '${e.message}'.");
    }
  }

  // 3. Method to disable DND
  static Future<void> disableDnd() async {
    try {
      await platform.invokeMethod('disableDnd');
    } on PlatformException catch (e) {
      print("Failed to disable DND: '${e.message}'.");
    }
  }

  // 4. Method to check if we have permission (Policy Access)
  static Future<bool> isPermissionGranted() async {
    try {
      final bool result = await platform.invokeMethod('checkPermission');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check permission: '${e.message}'.");
      return false;
    }
  }

  // 5. Method to open the system settings for DND permission
  static Future<void> openDndSettings() async {
    try {
      await platform.invokeMethod('openDndSettings');
    } on PlatformException catch (e) {
      print("Failed to open settings: '${e.message}'.");
    }
  }

  Future<void> startForegroundService(int startHour, int endHour) async {
    try {
      // Pass the time parameters as a Map payload
      await platform.invokeMethod('startService', {
        'startHour': startHour,
        'endHour': endHour,
      });
      print('DND Foreground Service started successfully.');
    } on PlatformException catch (e) {
      print("Failed to start foreground service: '${e.message}'.");
    }
  }

  /// Stops the native Android Foreground Service.
  Future<void> stopForegroundService() async {
    try {
      await platform.invokeMethod('stopService');
      print('DND Foreground Service stopped successfully.');
    } on PlatformException catch (e) {
      print("Failed to stop foreground service: '${e.message}'.");
    }
  }
}
