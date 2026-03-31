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
}
