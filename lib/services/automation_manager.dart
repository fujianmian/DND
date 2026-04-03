import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../main.dart';
import 'dnd_service.dart';

class AutomationManager {
  Timer? _timer;

  // UI State Notifiers
  final ValueNotifier<bool> isDndEnabled = ValueNotifier(false);
  final ValueNotifier<Rule?> activeRule = ValueNotifier(null);
  final ValueNotifier<String> nextChangeText = ValueNotifier(
    "Waiting for next rule...",
  );

  void start() {
    // Sync to Android immediately, then check every 30s to update the Flutter UI
    syncRulesToAndroid();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateFlutterUIState();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  // --- NEW: Core Sync Method ---
  // Call this whenever a rule is created, updated, or deleted
  Future<void> syncRulesToAndroid() async {
    try {
      final activeRules = await (database.select(
        database.rules,
      )..where((t) => t.isEnabled.equals(true))).get();

      List<Map<String, dynamic>> timeRulesMap = [];
      List<Map<String, dynamic>> locRulesMap = [];

      for (var rule in activeRules) {
        if (rule.type == 0 && rule.startTime != null && rule.endTime != null) {
          final start = _parseTimeString(rule.startTime!);
          final end = _parseTimeString(rule.endTime!);
          if (start != null && end != null) {
            timeRulesMap.add({
              'startHour': start.hour,
              'startMinute': start.minute,
              'endHour': end.hour,
              'endMinute': end.minute,
            });
          }
        } else if (rule.type == 1 &&
            rule.latitude != null &&
            rule.longitude != null &&
            rule.radius != null) {
          locRulesMap.add({
            'id': rule.id.toString(),
            'lat': rule.latitude!,
            'lng': rule.longitude!,
            'rad': rule.radius!,
          });
        }
      }

      // Send the separated rules to the Kotlin Execution Engine
      await DndService.syncRulesToService(timeRulesMap, locRulesMap);

      // Update UI immediately after syncing
      _updateFlutterUIState();
    } catch (e) {
      debugPrint("Automation Sync Error: ${e.toString()}");
    }
  }

  // --- Keeps your Status Screen UI updated ---
  Future<void> _updateFlutterUIState() async {
    try {
      final activeRules = await (database.select(
        database.rules,
      )..where((t) => t.isEnabled.equals(true))).get();
      final now = TimeOfDay.now();

      bool ruleMatchFound = false;
      Rule? matchedRule;

      for (var rule in activeRules) {
        if (rule.type == 0 && rule.startTime != null && rule.endTime != null) {
          final start = _parseTimeString(rule.startTime!);
          final end = _parseTimeString(rule.endTime!);

          if (start != null &&
              end != null &&
              _isCurrentTimeInWindow(now, start, end)) {
            ruleMatchFound = true;
            matchedRule = rule;
            break;
          }
        }
      }

      isDndEnabled.value = ruleMatchFound;
      activeRule.value = matchedRule;

      if (ruleMatchFound && matchedRule != null) {
        nextChangeText.value = "Next change at ${matchedRule.endTime}";
      } else {
        nextChangeText.value = "Waiting for next rule...";
      }

      // Note: We no longer call DndService.enableDnd() here. Kotlin handles it via syncRulesToAndroid().
    } catch (e) {
      debugPrint("UI Update Error: ${e.toString()}");
    }
  }

  bool _isCurrentTimeInWindow(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowDouble = now.hour + now.minute / 60.0;
    final startDouble = start.hour + start.minute / 60.0;
    final endDouble = end.hour + end.minute / 60.0;

    if (startDouble <= endDouble) {
      return nowDouble >= startDouble && nowDouble <= endDouble;
    } else {
      return nowDouble >= startDouble || nowDouble <= endDouble;
    }
  }

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
}
