import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../main.dart';
import '../models/time_repeat.dart';
import 'app_catalog.dart';
import 'dnd_service.dart';

class AutomationSyncPayload {
  const AutomationSyncPayload({
    required this.enabledRuleCount,
    required this.enabledTriggerCount,
    required this.legacyFallbackCount,
    required this.flattenedMultiTriggerRuleCount,
    required this.groupedRuleCount,
    required this.groupedTriggerCount,
    required this.skippedInvalidGroupedTriggerCount,
    required this.automationRulesJson,
    required this.calendarBusyWindowsJson,
    required this.timeRules,
    required this.locationRules,
    required this.appRules,
    required this.activityRules,
  });

  final int enabledRuleCount;
  final int enabledTriggerCount;
  final int legacyFallbackCount;
  final int flattenedMultiTriggerRuleCount;
  final int groupedRuleCount;
  final int groupedTriggerCount;
  final int skippedInvalidGroupedTriggerCount;
  final String automationRulesJson;
  final String calendarBusyWindowsJson;
  final List<Map<String, dynamic>> timeRules;
  final List<Map<String, dynamic>> locationRules;
  final List<Map<String, dynamic>> appRules;
  final List<Map<String, dynamic>> activityRules;
}

class AutomationManager with WidgetsBindingObserver {
  Timer? _timer;
  bool _isObservingLifecycle = false;
  int _postSyncRefreshGeneration = 0;

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
  final ValueNotifier<AutomationPauseState> automationPauseState =
      ValueNotifier(
        const AutomationPauseState(
          automationPaused: false,
          pauseUntilMillis: 0,
          pausedAtMillis: 0,
          pauseReason: 'manual',
        ),
      );

  void start() {
    if (!_isObservingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _isObservingLifecycle = true;
    }
    // Sync to Android immediately, then check every 30s as a fallback.
    syncRulesToAndroid();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      refreshUiState();
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
    await Future.wait([_updateFlutterUIState(), _updatePauseState()]);
  }

  // --- NEW: Core Sync Method ---
  // Call this whenever a rule is created, updated, or deleted
  Future<void> syncRulesToAndroid() async {
    try {
      final activeRules = await database.getEnabledRulesWithTriggers();
      final profiles = await database
          .watchProfiles(includeArchived: true)
          .first;
      final effectiveRules = applyProfileAutomationPolicy(
        activeRules,
        profiles,
      );
      final calendarBusyWindowsJson = await buildCalendarBusyWindowsJson();
      final payload = buildSyncPayloadFromRuleTriggers(
        effectiveRules,
        calendarBusyWindowsJson: calendarBusyWindowsJson,
      );

      debugPrint(
        "Automation sync source: enabledRules=${payload.enabledRuleCount}, "
        "enabledTriggers=${payload.enabledTriggerCount}, "
        "legacyFallbackRules=${payload.legacyFallbackCount}",
      );
      debugPrint(
        "Automation sync payload: time=${payload.timeRules.length}, "
        "location=${payload.locationRules.length}, "
        "app=${payload.appRules.length}, "
        "activity=${payload.activityRules.length}",
      );
      debugPrint(
        "Automation grouped payload: rules=${payload.groupedRuleCount}, "
        "triggers=${payload.groupedTriggerCount}, "
        "skippedInvalidTriggers=${payload.skippedInvalidGroupedTriggerCount}, "
        "jsonLength=${payload.automationRulesJson.length}",
      );
      debugPrint(
        "Automation calendar payload: jsonLength=${payload.calendarBusyWindowsJson.length}",
      );
      if (payload.flattenedMultiTriggerRuleCount > 0) {
        debugPrint(
          "Automation sync compatibility payload: "
          "${payload.flattenedMultiTriggerRuleCount} multi-trigger rule(s) "
          "also sent as flat native entries for fallback support.",
        );
      }

      // Send the separated rules to the Kotlin Execution Engine
      await DndService.syncRulesToService(
        payload.timeRules,
        payload.locationRules,
        payload.appRules,
        payload.activityRules,
        payload.automationRulesJson,
        payload.calendarBusyWindowsJson,
      );

      // Update Home/status listeners immediately, then again after native
      // evaluation and the service's short disable grace have had time to run.
      await refreshUiState();
      _schedulePostSyncStateRefreshes();
    } catch (e) {
      debugPrint("Automation Sync Error: ${e.toString()}");
    }
  }

  void _schedulePostSyncStateRefreshes() {
    final generation = ++_postSyncRefreshGeneration;
    for (final delay in const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 3800),
    ]) {
      Timer(delay, () {
        if (generation != _postSyncRefreshGeneration) return;
        refreshUiState();
      });
    }
  }

  AutomationSyncPayload buildSyncPayloadFromRuleTriggers(
    List<RuleWithTriggers> rulesWithTriggers, {
    String calendarBusyWindowsJson = '[]',
  }) {
    final timeRulesMap = <Map<String, dynamic>>[];
    final locRulesMap = <Map<String, dynamic>>[];
    final appRulesMap = <Map<String, dynamic>>[];
    final activityRulesMap = <Map<String, dynamic>>[];

    var enabledTriggerCount = 0;
    var legacyFallbackCount = 0;
    var flattenedMultiTriggerRuleCount = 0;
    final groupedRules = <Map<String, dynamic>>[];
    var groupedTriggerCount = 0;
    var skippedInvalidGroupedTriggerCount = 0;

    for (final entry in rulesWithTriggers) {
      final rule = entry.rule;
      final enabledTriggers = entry.triggers
          .where((trigger) => trigger.enabled)
          .toList(growable: false);
      enabledTriggerCount += enabledTriggers.length;

      if (enabledTriggers.length > 1) {
        // Keep flat native entries available for fallback compatibility.
        flattenedMultiTriggerRuleCount += 1;
      }

      final groupedTriggers = <Map<String, dynamic>>[];
      for (final trigger in enabledTriggers) {
        final groupedTrigger = _groupedTriggerPayload(rule, trigger);
        if (groupedTrigger == null) {
          skippedInvalidGroupedTriggerCount += 1;
          continue;
        }
        groupedTriggers.add(groupedTrigger);
      }

      if (entry.triggers.isNotEmpty && groupedTriggers.isEmpty) {
        debugPrint(
          "Automation grouped payload skipped rule ${rule.id} (${rule.name}): no valid enabled triggers.",
        );
      } else if (groupedTriggers.isNotEmpty) {
        groupedTriggerCount += groupedTriggers.length;
        groupedRules.add({
          'id': rule.id.toString(),
          'name': rule.name,
          'enabled': rule.isEnabled,
          'matchType': rule.matchType,
          'priority': rule.priority,
          'allowStarredContacts': rule.allowStarredContacts,
          'allowRepeatCallers': rule.allowRepeatCallers,
          'triggers': groupedTriggers,
        });
      }

      if (entry.triggers.isEmpty) {
        legacyFallbackCount += 1;
        debugPrint(
          "Automation sync fallback: rule ${rule.id} (${rule.name}) has no RuleTriggers; using legacy Rules fields.",
        );
        _addLegacyRuleToPayload(
          rule,
          timeRulesMap,
          locRulesMap,
          appRulesMap,
          activityRulesMap,
        );
        continue;
      }

      for (final trigger in enabledTriggers) {
        _addTriggerToPayload(
          rule,
          trigger,
          timeRulesMap,
          locRulesMap,
          appRulesMap,
          activityRulesMap,
        );
      }
    }

    return AutomationSyncPayload(
      enabledRuleCount: rulesWithTriggers.length,
      enabledTriggerCount: enabledTriggerCount,
      legacyFallbackCount: legacyFallbackCount,
      flattenedMultiTriggerRuleCount: flattenedMultiTriggerRuleCount,
      groupedRuleCount: groupedRules.length,
      groupedTriggerCount: groupedTriggerCount,
      skippedInvalidGroupedTriggerCount: skippedInvalidGroupedTriggerCount,
      automationRulesJson: jsonEncode(groupedRules),
      calendarBusyWindowsJson: calendarBusyWindowsJson,
      timeRules: timeRulesMap,
      locationRules: locRulesMap,
      appRules: appRulesMap,
      activityRules: activityRulesMap,
    );
  }

  AutomationSyncPayload buildProfileAwareSyncPayloadFromRuleTriggers(
    List<RuleWithTriggers> rulesWithTriggers,
    List<Profile> profiles, {
    String calendarBusyWindowsJson = '[]',
  }) {
    return buildSyncPayloadFromRuleTriggers(
      applyProfileAutomationPolicy(rulesWithTriggers, profiles),
      calendarBusyWindowsJson: calendarBusyWindowsJson,
    );
  }

  List<RuleWithTriggers> applyProfileAutomationPolicy(
    List<RuleWithTriggers> rulesWithTriggers,
    List<Profile> profiles,
  ) {
    final profilesById = {for (final profile in profiles) profile.id: profile};
    final effectiveEntries = <RuleWithTriggers>[];

    for (final entry in rulesWithTriggers) {
      final rule = entry.rule;
      if (!rule.isEnabled) {
        debugPrint(
          "Automation profile filter skipped rule ${rule.id} (${rule.name}): rule disabled.",
        );
        continue;
      }

      final profileId = rule.profileId;
      if (profileId == null) {
        debugPrint(
          "Automation profile filter included unprofiled rule ${rule.id} (${rule.name}).",
        );
        effectiveEntries.add(entry);
        continue;
      }

      final profile = profilesById[profileId];
      if (profile == null) {
        debugPrint(
          "Automation profile filter skipped rule ${rule.id} (${rule.name}): profile $profileId missing.",
        );
        continue;
      }

      if (profile.isArchived) {
        debugPrint(
          "Automation profile filter skipped rule ${rule.id} (${rule.name}): profile ${profile.id} (${profile.name}) archived.",
        );
        continue;
      }

      if (!profile.isEnabled) {
        debugPrint(
          "Automation profile filter skipped rule ${rule.id} (${rule.name}): profile ${profile.id} (${profile.name}) disabled.",
        );
        continue;
      }

      debugPrint(
        "Automation profile filter included profiled rule ${rule.id} (${rule.name}) in profile ${profile.id} (${profile.name}).",
      );
      effectiveEntries.add(
        RuleWithTriggers(
          rule: rule.copyWith(
            allowStarredContacts:
                rule.allowStarredContacts || profile.allowStarredContacts,
            allowRepeatCallers:
                rule.allowRepeatCallers || profile.allowRepeatCallers,
          ),
          triggers: entry.triggers,
        ),
      );
    }

    return effectiveEntries;
  }

  Future<String> buildCalendarBusyWindowsJson([
    AppDatabase? sourceDatabase,
  ]) async {
    final db = sourceDatabase ?? database;
    final windows = await db.select(db.calendarBusyWindowsCache).get();
    return jsonEncode(
      windows
          .map(
            (window) => {
              'triggerId': window.triggerId,
              'startMillis': window.startMillis,
              'endMillis': window.endMillis,
              'isAllDay': window.isAllDay,
              'keywordMatched': window.keywordMatched,
              'fetchedAt': window.fetchedAt,
            },
          )
          .toList(growable: false),
    );
  }

  void _addTriggerToPayload(
    Rule rule,
    RuleTrigger trigger,
    List<Map<String, dynamic>> timeRulesMap,
    List<Map<String, dynamic>> locRulesMap,
    List<Map<String, dynamic>> appRulesMap,
    List<Map<String, dynamic>> activityRulesMap,
  ) {
    switch (trigger.triggerType) {
      case 0:
        _addTimePayload(
          rule,
          trigger.startTime,
          trigger.endTime,
          timeRulesMap,
          timeRepeatMode: trigger.timeRepeatMode,
          timeRepeatDaysMask: trigger.timeRepeatDaysMask,
        );
        break;
      case 1:
        _addLocationPayload(
          rule,
          trigger.latitude,
          trigger.longitude,
          trigger.radius,
          locRulesMap,
        );
        break;
      case 2:
        _addAppPayload(rule, trigger.packageName, appRulesMap);
        break;
      case 3:
        _addActivityPayload(rule, trigger.activityType, activityRulesMap);
        break;
    }
  }

  Map<String, dynamic>? _groupedTriggerPayload(Rule rule, RuleTrigger trigger) {
    final base = <String, dynamic>{
      'id': trigger.id.toString(),
      'triggerType': trigger.triggerType,
      'enabled': trigger.enabled,
    };

    switch (trigger.triggerType) {
      case 0:
        final startTime = trigger.startTime;
        final endTime = trigger.endTime;
        if (startTime == null || endTime == null) {
          debugPrint(
            "Automation grouped payload skipped invalid time trigger ${trigger.id} for rule ${rule.id}: missing start/end time.",
          );
          return null;
        }
        final start = _parseTimeString(startTime);
        final end = _parseTimeString(endTime);
        if (start == null || end == null) {
          debugPrint(
            "Automation grouped payload skipped invalid time trigger ${trigger.id} for rule ${rule.id}: failed to parse start/end time.",
          );
          return null;
        }
        return {
          ...base,
          'startHour': start.hour,
          'startMinute': start.minute,
          'endHour': end.hour,
          'endMinute': end.minute,
          'timeRepeatMode': normalizeTimeRepeatMode(trigger.timeRepeatMode),
          'timeRepeatDaysMask': normalizeTimeRepeatDaysMask(
            trigger.timeRepeatDaysMask,
            repeatMode: trigger.timeRepeatMode,
          ),
        };
      case 1:
        final latitude = trigger.latitude;
        final longitude = trigger.longitude;
        final radius = trigger.radius;
        if (latitude == null || longitude == null || radius == null) {
          debugPrint(
            "Automation grouped payload skipped invalid location trigger ${trigger.id} for rule ${rule.id}: missing latitude/longitude/radius.",
          );
          return null;
        }
        return {
          ...base,
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius.round(),
        };
      case 2:
        final packageName = trigger.packageName;
        if (packageName == null || packageName.isEmpty) {
          debugPrint(
            "Automation grouped payload skipped invalid app trigger ${trigger.id} for rule ${rule.id}: missing packageName.",
          );
          return null;
        }
        return {...base, 'packageName': packageName};
      case 3:
        final activityType = trigger.activityType;
        if (activityType == null || activityType.isEmpty) {
          debugPrint(
            "Automation grouped payload skipped invalid activity trigger ${trigger.id} for rule ${rule.id}: missing activityType.",
          );
          return null;
        }
        return {...base, 'activityType': activityType};
      case 4:
        return base;
      default:
        debugPrint(
          "Automation grouped payload skipped unknown trigger ${trigger.id} for rule ${rule.id}: triggerType=${trigger.triggerType}.",
        );
        return null;
    }
  }

  void _addLegacyRuleToPayload(
    Rule rule,
    List<Map<String, dynamic>> timeRulesMap,
    List<Map<String, dynamic>> locRulesMap,
    List<Map<String, dynamic>> appRulesMap,
    List<Map<String, dynamic>> activityRulesMap,
  ) {
    switch (rule.type) {
      case 0:
        _addTimePayload(
          rule,
          rule.startTime,
          rule.endTime,
          timeRulesMap,
          timeRepeatMode: rule.timeRepeatMode,
          timeRepeatDaysMask: rule.timeRepeatDaysMask,
        );
        break;
      case 1:
        _addLocationPayload(
          rule,
          rule.latitude,
          rule.longitude,
          rule.radius?.toDouble(),
          locRulesMap,
        );
        break;
      case 2:
        _addAppPayload(rule, rule.packageName, appRulesMap);
        break;
      case 3:
        _addActivityPayload(rule, rule.activityType, activityRulesMap);
        break;
    }
  }

  void _addTimePayload(
    Rule rule,
    String? startTime,
    String? endTime,
    List<Map<String, dynamic>> timeRulesMap, {
    required int timeRepeatMode,
    required int timeRepeatDaysMask,
  }) {
    if (startTime == null || endTime == null) return;

    final start = _parseTimeString(startTime);
    final end = _parseTimeString(endTime);
    if (start == null || end == null) return;
    final normalizedMode = normalizeTimeRepeatMode(timeRepeatMode);

    timeRulesMap.add({
      'id': rule.id.toString(),
      'name': rule.name,
      'startHour': start.hour,
      'startMinute': start.minute,
      'endHour': end.hour,
      'endMinute': end.minute,
      'timeRepeatMode': normalizedMode,
      'timeRepeatDaysMask': normalizeTimeRepeatDaysMask(
        timeRepeatDaysMask,
        repeatMode: normalizedMode,
      ),
      'allowStarredContacts': rule.allowStarredContacts,
      'allowRepeatCallers': rule.allowRepeatCallers,
    });
  }

  void _addLocationPayload(
    Rule rule,
    double? latitude,
    double? longitude,
    double? radius,
    List<Map<String, dynamic>> locRulesMap,
  ) {
    if (latitude == null || longitude == null || radius == null) return;

    locRulesMap.add({
      'id': rule.id.toString(),
      'name': rule.name,
      'lat': latitude,
      'lng': longitude,
      'rad': radius.round(),
      'allowStarredContacts': rule.allowStarredContacts,
      'allowRepeatCallers': rule.allowRepeatCallers,
    });
  }

  void _addAppPayload(
    Rule rule,
    String? packageName,
    List<Map<String, dynamic>> appRulesMap,
  ) {
    if (packageName == null || packageName.isEmpty) return;

    appRulesMap.add({
      'id': rule.id.toString(),
      'name': rule.name,
      'packageName': packageName,
      'allowStarredContacts': rule.allowStarredContacts,
      'allowRepeatCallers': rule.allowRepeatCallers,
    });
  }

  void _addActivityPayload(
    Rule rule,
    String? activityType,
    List<Map<String, dynamic>> activityRulesMap,
  ) {
    if (activityType == null || activityType.isEmpty) return;

    activityRulesMap.add({
      'id': rule.id.toString(),
      'name': rule.name,
      'activityType': activityType,
      'allowStarredContacts': rule.allowStarredContacts,
      'allowRepeatCallers': rule.allowRepeatCallers,
    });
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

  Future<void> _updatePauseState() async {
    try {
      automationPauseState.value = await DndService.getAutomationPauseState();
    } catch (e) {
      debugPrint("Pause State Update Error: ${e.toString()}");
    }
  }

  Future<bool> _applyNativeAutomationState() async {
    final nativeState = await DndService.getAutomationDndState();
    if (nativeState == null) return false;

    if (!nativeState.automationDndActive) {
      isDndEnabled.value = false;
      activeRule.value = null;
      activeRuleDisplayNames.value = const [];
      lastAutomationDndChangedAt.value = nativeState.lastAutomationDndChangedAt;
      activeStatusText.value = "No active rule";
      nextChangeText.value = _statusDetailFor(nativeState, null);
      return true;
    }

    final activeRuleNames = nativeState.activeAutomationRuleNames;
    final effectiveRules = await _effectiveEnabledRules();
    final matchedRules = _rulesNamed(effectiveRules, activeRuleNames);

    if (activeRuleNames.isNotEmpty && matchedRules.isEmpty) {
      debugPrint(
        "Automation UI state ignored stale native active names: "
        "${activeRuleNames.join(', ')}",
      );
      isDndEnabled.value = false;
      activeRule.value = null;
      activeRuleDisplayNames.value = const [];
      lastAutomationDndChangedAt.value = nativeState.lastAutomationDndChangedAt;
      activeStatusText.value = "No active rule";
      nextChangeText.value = "Waiting for next rule...";
      return true;
    }

    final displayNames = matchedRules.isEmpty
        ? const <String>[]
        : await Future.wait(matchedRules.map(_displayNameForRule));
    final matchedRule = matchedRules.isEmpty ? null : matchedRules.first;

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
      final activeRules = applyProfileAutomationPolicy(
        await database.getEnabledRulesWithTriggers(),
        await database.watchProfiles(includeArchived: true).first,
      ).map((entry) => entry.rule).toList(growable: false);
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

  Future<List<Rule>> _effectiveEnabledRules() async {
    return applyProfileAutomationPolicy(
      await database.getEnabledRulesWithTriggers(),
      await database.watchProfiles(includeArchived: true).first,
    ).map((entry) => entry.rule).toList(growable: false);
  }

  List<Rule> _rulesNamed(List<Rule> rules, List<String> names) {
    if (names.isEmpty) return const [];

    final remainingNames = [...names];
    final matches = <Rule>[];
    for (final rule in rules) {
      final index = remainingNames.indexOf(rule.name);
      if (index == -1) continue;

      matches.add(rule);
      remainingNames.removeAt(index);
    }
    return matches;
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
