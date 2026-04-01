import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../main.dart';
import 'dnd_service.dart';

class AutomationManager {
  Timer? _timer;

  // --- NEW: UI State Notifiers ---
  // These allow the Status Screen to listen for real-time updates.
  final ValueNotifier<bool> isDndEnabled = ValueNotifier(false);
  final ValueNotifier<Rule?> activeRule = ValueNotifier(null);

  // MVP approach for next change: Just a simple string to display
  final ValueNotifier<String> nextChangeText = ValueNotifier(
    "Waiting for next rule...",
  );

  // Optimization: Track the state to prevent redundant DND calls every minute
  bool? _isDndCurrentlyEnabled = false;

  void start() {
    // Check every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkRulesAndToggleDnd();
    });

    // Immediate initial check
    _checkRulesAndToggleDnd();
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> _checkRulesAndToggleDnd() async {
    try {
      // 1. Optimize: Only fetch ENABLED rules from the database
      final activeRules = await (database.select(
        database.rules,
      )..where((t) => t.isEnabled.equals(true))).get();

      final now = TimeOfDay.now();
      bool ruleMatchFound = false;
      Rule? matchedRule;

      for (var rule in activeRules) {
        // Only process Time-based rules (type 0)
        if (rule.type == 0 && rule.startTime != null && rule.endTime != null) {
          final start = _parseTimeString(rule.startTime!);
          final end = _parseTimeString(rule.endTime!);

          if (start != null && end != null) {
            if (_isCurrentTimeInWindow(now, start, end)) {
              ruleMatchFound = true;
              matchedRule = rule;
              break;
            }
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

      // 2. State Change Logic: Only call DndService if the target state is different
      if (ruleMatchFound) {
        if (_isDndCurrentlyEnabled != true) {
          await DndService.enableDnd();
          _isDndCurrentlyEnabled = true;
          debugPrint("Automation: State changed - DND Enabled.");
        }
      } else {
        if (_isDndCurrentlyEnabled != false) {
          await DndService.disableDnd();
          _isDndCurrentlyEnabled = false;
          debugPrint("Automation: State changed - DND Disabled.");
        }
      }
    } catch (e) {
      // 3. Error Handling: Prevent app crashes if MethodChannel or DB fails
      debugPrint("Automation Error: ${e.toString()}");
    }
  }

  bool _isCurrentTimeInWindow(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowDouble = now.hour + now.minute / 60.0;
    final startDouble = start.hour + start.minute / 60.0;
    final endDouble = end.hour + end.minute / 60.0;

    if (startDouble <= endDouble) {
      return nowDouble >= startDouble && nowDouble <= endDouble;
    } else {
      // Overnight support (e.g., 11 PM to 7 AM)
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
