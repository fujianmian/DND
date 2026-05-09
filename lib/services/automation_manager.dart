import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../main.dart';
import 'app_catalog.dart';
import 'dnd_service.dart';

class AutomationManager with WidgetsBindingObserver {
  Timer? _timer;
  bool _isObservingLifecycle = false;

  // UI State Notifiers
  final ValueNotifier<bool> isDndEnabled = ValueNotifier(false);
  final ValueNotifier<Rule?> activeRule = ValueNotifier(null);
  final ValueNotifier<List<String>> activeRuleDisplayNames = ValueNotifier(
    const [],
  );
  final ValueNotifier<String> activeStatusText = ValueNotifier(
    "No active rule",
  );
  final ValueNotifier<DateTime?> lastAutomationDndChangedAt = ValueNotifier(
    null,
  );
  final ValueNotifier<String> nextChangeText = ValueNotifier(
    "Waiting for next rule...",
  );

  void start() {
    if (!_isObservingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _isObservingLifecycle = true;
    }
    // Sync to Android immediately, then check every 30s to update the Flutter UI
    syncRulesToAndroid();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateFlutterUIState();
    });
  }

  void stop() {
    _timer?.cancel();
    if (_isObservingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _isObservingLifecycle = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshUiState();
    }
  }

  Future<void> refreshUiState() async {
    await _updateFlutterUIState();
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
      List<Map<String, dynamic>> appRulesMap = [];
      List<Map<String, dynamic>> activityRulesMap = [];

      for (var rule in activeRules) {
        if (rule.type == 0 && rule.startTime != null && rule.endTime != null) {
          final start = _parseTimeString(rule.startTime!);
          final end = _parseTimeString(rule.endTime!);
          if (start != null && end != null) {
            timeRulesMap.add({
              'id': rule.id.toString(),
              'name': rule.name,
              'startHour': start.hour,
              'startMinute': start.minute,
              'endHour': end.hour,
              'endMinute': end.minute,
              'allowStarredContacts': rule.allowStarredContacts,
              'allowRepeatCallers': rule.allowRepeatCallers,
            });
          }
        } else if (rule.type == 1 &&
            rule.latitude != null &&
            rule.longitude != null &&
            rule.radius != null) {
          locRulesMap.add({
            'id': rule.id.toString(),
            'name': rule.name,
            'lat': rule.latitude!,
            'lng': rule.longitude!,
            'rad': rule.radius!,
            'allowStarredContacts': rule.allowStarredContacts,
            'allowRepeatCallers': rule.allowRepeatCallers,
          });
        } else if (rule.type == 2 && rule.packageName != null) {
          // 🔹 FIX 2: Collect the App Packages
          appRulesMap.add({
            'id': rule.id.toString(),
            'name': rule.name,
            'packageName': rule.packageName!,
            'allowStarredContacts': rule.allowStarredContacts,
            'allowRepeatCallers': rule.allowRepeatCallers,
          });
        } else if (rule.type == 3 && rule.activityType != null) {
          activityRulesMap.add({
            'id': rule.id.toString(),
            'name': rule.name,
            'activityType': rule.activityType!,
            'allowStarredContacts': rule.allowStarredContacts,
            'allowRepeatCallers': rule.allowRepeatCallers,
          });
        }
      }

      // Send the separated rules to the Kotlin Execution Engine
      await DndService.syncRulesToService(
        timeRulesMap,
        locRulesMap,
        appRulesMap,
        activityRulesMap,
      );

      // Update UI immediately after syncing
      _updateFlutterUIState();
    } catch (e) {
      debugPrint("Automation Sync Error: ${e.toString()}");
    }
  }

  // --- Keeps your Status Screen UI updated ---
  Future<void> _updateFlutterUIState() async {
    try {
      final nativeStateApplied = await _applyNativeAutomationState();
      if (nativeStateApplied) return;

      await _updateFlutterUIStateFromLocalTimeRules();
    } catch (e) {
      debugPrint("UI Update Error: ${e.toString()}");
    }
  }

  Future<bool> _applyNativeAutomationState() async {
    final nativeState = await DndService.getAutomationDndState();
    if (nativeState == null) return false;

    final displayNames = nativeState.automationDndActive
        ? await _displayNamesForActiveRules(
            nativeState.activeAutomationRuleNames,
          )
        : const <String>[];
    final matchedRule = nativeState.automationDndActive
        ? await _firstEnabledRuleNamed(nativeState.activeAutomationRuleNames)
        : null;

    isDndEnabled.value = nativeState.automationDndActive;
    activeRule.value = matchedRule;
    activeRuleDisplayNames.value = displayNames;
    lastAutomationDndChangedAt.value = nativeState.lastAutomationDndChangedAt;
    activeStatusText.value = nativeState.automationDndActive
        ? _activeStatusFor(displayNames)
        : "No active rule";
    nextChangeText.value = _statusDetailFor(nativeState, matchedRule);
    return true;
  }

  Future<void> _updateFlutterUIStateFromLocalTimeRules() async {
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
      activeRuleDisplayNames.value = matchedRule == null
          ? const []
          : [matchedRule.name];
      activeStatusText.value = matchedRule == null
          ? "No active rule"
          : "Active: ${matchedRule.name}";
      lastAutomationDndChangedAt.value = null;

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

  Future<List<String>> _displayNamesForActiveRules(
    List<String> nativeRuleNames,
  ) async {
    if (nativeRuleNames.isEmpty) return const [];

    final enabledRules = await (database.select(
      database.rules,
    )..where((t) => t.isEnabled.equals(true))).get();

    final displayNames = <String>[];
    for (final nativeName in nativeRuleNames) {
      final rule = _ruleNamed(enabledRules, nativeName);
      if (rule == null) {
        displayNames.add(nativeName);
        continue;
      }

      displayNames.add(await _displayNameForRule(rule));
    }
    return displayNames;
  }

  Future<Rule?> _firstEnabledRuleNamed(List<String> nativeRuleNames) async {
    if (nativeRuleNames.isEmpty) return null;

    final enabledRules = await (database.select(
      database.rules,
    )..where((t) => t.isEnabled.equals(true))).get();

    for (final nativeName in nativeRuleNames) {
      final rule = _ruleNamed(enabledRules, nativeName);
      if (rule != null) return rule;
    }
    return null;
  }

  Rule? _ruleNamed(List<Rule> rules, String name) {
    for (final rule in rules) {
      if (rule.name == name) return rule;
    }
    return null;
  }

  Future<String> _displayNameForRule(Rule rule) async {
    if (rule.type != 2 || rule.packageName == null) return rule.name;

    final packageName = rule.packageName!;
    final entry =
        appCatalog.cachedEntry(packageName) ??
        await appCatalog.loadAppInfo(packageName);
    final appLabel = entry?.name ?? packageName;
    if (appLabel == packageName) return rule.name;

    return "${rule.name} ($appLabel)";
  }

  String _activeStatusFor(List<String> displayNames) {
    if (displayNames.isEmpty) return "Automation active";
    return "Active: ${displayNames.join(', ')}";
  }

  String _statusDetailFor(AutomationDndState nativeState, Rule? matchedRule) {
    if (!nativeState.automationDndActive) {
      final changedAt = nativeState.lastAutomationDndChangedAt;
      if (changedAt != null) {
        return "Inactive since ${_formatDateTime(changedAt)}";
      }
      return "Waiting for next rule...";
    }

    if (matchedRule?.type == 0 && matchedRule?.endTime != null) {
      return "Next change at ${matchedRule!.endTime}";
    }

    final changedAt = nativeState.lastAutomationDndChangedAt;
    if (changedAt != null) return "Active since ${_formatDateTime(changedAt)}";
    return "Automation active";
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
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
