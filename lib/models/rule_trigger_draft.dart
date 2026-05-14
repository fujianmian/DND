import 'package:drift/drift.dart' as d;

import '../database/database.dart';
import 'rule.dart' as model;
import 'rule_trigger_values.dart';
import 'time_repeat.dart';

class RuleTriggerDraft {
  static const time = 0;
  static const location = 1;
  static const app = 2;
  static const activity = 3;
  static const calendar = 4;

  const RuleTriggerDraft({
    required this.triggerType,
    this.startTime,
    this.endTime,
    this.timeRepeatMode = timeRepeatEveryDay,
    this.timeRepeatDaysMask = timeRepeatEveryDayMask,
    this.latitude,
    this.longitude,
    this.radius,
    this.savedLocationId,
    this.locationLabel,
    this.packageName,
    this.activityType,
    this.calendarId,
    this.calendarKeyword,
    this.calendarIncludeAllDay = false,
    this.calendarLookaheadHours,
    this.enabled = true,
  });

  final int triggerType;
  final String? startTime;
  final String? endTime;
  final int timeRepeatMode;
  final int timeRepeatDaysMask;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final int? savedLocationId;
  final String? locationLabel;
  final String? packageName;
  final String? activityType;
  final String? calendarId;
  final String? calendarKeyword;
  final bool calendarIncludeAllDay;
  final int? calendarLookaheadHours;
  final bool enabled;

  factory RuleTriggerDraft.fromRuleTrigger(RuleTrigger trigger) {
    return RuleTriggerDraft(
      triggerType: trigger.triggerType,
      startTime: trigger.startTime,
      endTime: trigger.endTime,
      timeRepeatMode: trigger.timeRepeatMode,
      timeRepeatDaysMask: trigger.timeRepeatDaysMask,
      latitude: trigger.latitude,
      longitude: trigger.longitude,
      radius: trigger.radius,
      savedLocationId: trigger.savedLocationId,
      locationLabel: trigger.locationLabel,
      packageName: trigger.packageName,
      activityType: trigger.activityType,
      calendarId: trigger.calendarId,
      calendarKeyword: trigger.calendarKeyword,
      calendarIncludeAllDay: trigger.calendarIncludeAllDay,
      calendarLookaheadHours: trigger.calendarLookaheadHours,
      enabled: trigger.enabled,
    );
  }

  factory RuleTriggerDraft.fromLegacyRule(Rule rule) {
    return RuleTriggerDraft(
      triggerType: rule.type,
      startTime: rule.type == time ? rule.startTime : null,
      endTime: rule.type == time ? rule.endTime : null,
      timeRepeatMode: rule.type == time
          ? rule.timeRepeatMode
          : timeRepeatEveryDay,
      timeRepeatDaysMask: rule.type == time
          ? rule.timeRepeatDaysMask
          : timeRepeatEveryDayMask,
      latitude: rule.type == location ? rule.latitude : null,
      longitude: rule.type == location ? rule.longitude : null,
      radius: rule.type == location ? rule.radius?.toDouble() : null,
      savedLocationId: rule.type == location ? rule.savedLocationId : null,
      locationLabel: rule.type == location ? rule.locationLabel : null,
      packageName: rule.type == app ? rule.packageName : null,
      activityType: rule.type == activity ? rule.activityType : null,
    );
  }

  RuleTriggersCompanion toCompanion({int ruleId = 0}) {
    final normalizedMode = normalizeTimeRepeatMode(timeRepeatMode);
    final normalizedDaysMask = normalizeTimeRepeatDaysMask(
      timeRepeatDaysMask,
      repeatMode: normalizedMode,
    );
    return RuleTriggersCompanion.insert(
      ruleId: ruleId,
      triggerType: triggerType,
      startTime: triggerType == time ? d.Value(startTime) : const d.Value(null),
      endTime: triggerType == time ? d.Value(endTime) : const d.Value(null),
      timeRepeatMode: triggerType == time
          ? d.Value(normalizedMode)
          : const d.Value(timeRepeatEveryDay),
      timeRepeatDaysMask: triggerType == time
          ? d.Value(normalizedDaysMask)
          : const d.Value(timeRepeatEveryDayMask),
      latitude: triggerType == location
          ? d.Value(latitude)
          : const d.Value(null),
      longitude: triggerType == location
          ? d.Value(longitude)
          : const d.Value(null),
      radius: triggerType == location ? d.Value(radius) : const d.Value(null),
      savedLocationId: triggerType == location
          ? d.Value(savedLocationId)
          : const d.Value(null),
      locationLabel: triggerType == location
          ? d.Value(_cleanText(locationLabel))
          : const d.Value(null),
      packageName: triggerType == app
          ? d.Value(_cleanText(packageName))
          : const d.Value(null),
      activityType: triggerType == activity
          ? d.Value(_cleanText(activityType))
          : const d.Value(null),
      calendarId: triggerType == calendar
          ? d.Value(_cleanText(calendarId))
          : const d.Value(null),
      calendarKeyword: triggerType == calendar
          ? d.Value(_cleanText(calendarKeyword))
          : const d.Value(null),
      calendarIncludeAllDay: triggerType == calendar
          ? d.Value(calendarIncludeAllDay)
          : const d.Value(false),
      calendarLookaheadHours: triggerType == calendar
          ? d.Value(calendarLookaheadHours)
          : const d.Value(null),
      enabled: d.Value(enabled),
    );
  }

  RuleTriggerValues toLegacyValues() {
    return cleanedRuleTriggerValues(
      triggerType: _modelTriggerType(triggerType),
      startTime: startTime,
      endTime: endTime,
      timeRepeatMode: timeRepeatMode,
      timeRepeatDaysMask: timeRepeatDaysMask,
      latitude: latitude,
      longitude: longitude,
      radius: radius?.round(),
      savedLocationId: savedLocationId,
      locationLabel: locationLabel,
      packageName: _cleanText(packageName),
      activityType: _cleanText(activityType),
    );
  }
}

RulesCompanion withFirstTriggerLegacyFields(
  RulesCompanion rule,
  RuleTriggerDraft firstTrigger,
) {
  final values = firstTrigger.toLegacyValues();
  return rule.copyWith(
    type: d.Value(values.type),
    startTime: values.startTime,
    endTime: values.endTime,
    timeRepeatMode: values.timeRepeatMode,
    timeRepeatDaysMask: values.timeRepeatDaysMask,
    latitude: values.latitude,
    longitude: values.longitude,
    radius: values.radius,
    savedLocationId: values.savedLocationId,
    locationLabel: values.locationLabel,
    packageName: values.packageName,
    activityType: values.activityType,
  );
}

int priorityForDrafts(Iterable<RuleTriggerDraft> drafts) {
  return drafts.fold<int>(rulePriorityTime, (highest, draft) {
    final priority = priorityForTrigger(
      triggerType: draft.triggerType,
      activityType: draft.activityType,
    );
    return priority > highest ? priority : highest;
  });
}

String? validateRuleTriggerDrafts({
  required String ruleName,
  required int? matchType,
  required List<RuleTriggerDraft> triggers,
}) {
  if (ruleName.trim().isEmpty) return 'Enter a rule name.';
  if (matchType != 0 && matchType != 1) return 'Please choose a match type.';
  if (triggers.isEmpty) return 'Please add at least one condition.';

  final appPackages = <String>{};
  final activityTypes = <String>{};
  final timeRanges = <String>{};
  final locations = <String>{};
  final calendars = <String>{};

  for (var i = 0; i < triggers.length; i += 1) {
    final trigger = triggers[i];
    final label = 'Condition ${i + 1}';

    switch (trigger.triggerType) {
      case RuleTriggerDraft.time:
        final start = _cleanText(trigger.startTime);
        final end = _cleanText(trigger.endTime);
        if (start == null || end == null) {
          return '$label: please select start and end times.';
        }
        final repeatMode = normalizeTimeRepeatMode(trigger.timeRepeatMode);
        if (repeatMode != trigger.timeRepeatMode) {
          return '$label: please choose a valid repeat setting.';
        }
        if (repeatMode == timeRepeatCustom &&
            !isValidCustomDaysMask(trigger.timeRepeatDaysMask)) {
          return '$label: please select at least one repeat day.';
        }
        final repeatDaysMask = normalizeTimeRepeatDaysMask(
          trigger.timeRepeatDaysMask,
          repeatMode: repeatMode,
        );
        final key = '$start->$end|$repeatMode|$repeatDaysMask';
        if (!timeRanges.add(key)) {
          return '$label duplicates an existing time range.';
        }
        break;
      case RuleTriggerDraft.location:
        final radius = trigger.radius;
        if (trigger.latitude == null ||
            trigger.longitude == null ||
            radius == null) {
          return '$label: please select a location and radius.';
        }
        if (radius < 50) {
          return '$label: please select a radius of at least 50m.';
        }
        final key =
            '${trigger.latitude}|${trigger.longitude}|${radius.toStringAsFixed(2)}';
        if (!locations.add(key)) {
          return '$label duplicates an existing location.';
        }
        break;
      case RuleTriggerDraft.app:
        final packageName = _cleanText(trigger.packageName);
        if (packageName == null) return '$label: please select an application.';
        if (!appPackages.add(packageName)) {
          return '$label duplicates an existing application.';
        }
        break;
      case RuleTriggerDraft.activity:
        final activityType = _cleanText(trigger.activityType);
        if (activityType == null) return '$label: please select an activity.';
        if (!activityTypes.add(activityType)) {
          return '$label duplicates an existing activity.';
        }
        break;
      case RuleTriggerDraft.calendar:
        final lookaheadHours = trigger.calendarLookaheadHours;
        if (lookaheadHours != null && lookaheadHours <= 0) {
          return '$label: calendar lookahead hours must be positive.';
        }
        final calendarId = _cleanText(trigger.calendarId) ?? 'primary';
        final keyword = _cleanText(trigger.calendarKeyword) ?? '';
        final key =
            '$calendarId|${keyword.toLowerCase()}|${trigger.calendarIncludeAllDay}';
        if (!calendars.add(key)) {
          return '$label duplicates an existing calendar condition.';
        }
        break;
      default:
        return '$label: please choose a trigger type.';
    }
  }

  return null;
}

model.TriggerType _modelTriggerType(int triggerType) {
  switch (triggerType) {
    case RuleTriggerDraft.time:
      return model.TriggerType.time;
    case RuleTriggerDraft.location:
      return model.TriggerType.location;
    case RuleTriggerDraft.app:
      return model.TriggerType.app;
    case RuleTriggerDraft.activity:
      return model.TriggerType.activity;
    case RuleTriggerDraft.calendar:
      return model.TriggerType.calendar;
    default:
      throw ArgumentError.value(triggerType, 'triggerType');
  }
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
