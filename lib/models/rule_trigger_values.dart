import 'package:drift/drift.dart' as d;

import 'rule.dart' as model;
import 'time_repeat.dart';

class RuleTriggerValues {
  final int type;
  final d.Value<String?> startTime;
  final d.Value<String?> endTime;
  final d.Value<int> timeRepeatMode;
  final d.Value<int> timeRepeatDaysMask;
  final d.Value<double?> latitude;
  final d.Value<double?> longitude;
  final d.Value<int?> radius;
  final d.Value<int?> savedLocationId;
  final d.Value<String?> locationLabel;
  final d.Value<String?> packageName;
  final d.Value<String?> activityType;

  const RuleTriggerValues({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.timeRepeatMode,
    required this.timeRepeatDaysMask,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.savedLocationId,
    required this.locationLabel,
    required this.packageName,
    required this.activityType,
  });
}

RuleTriggerValues cleanedRuleTriggerValues({
  required model.TriggerType triggerType,
  String? startTime,
  String? endTime,
  int? timeRepeatMode,
  int? timeRepeatDaysMask,
  double? latitude,
  double? longitude,
  int? radius,
  int? savedLocationId,
  String? locationLabel,
  String? packageName,
  String? activityType,
}) {
  switch (triggerType) {
    case model.TriggerType.time:
      final normalizedMode = normalizeTimeRepeatMode(timeRepeatMode);
      return RuleTriggerValues(
        type: 0,
        startTime: d.Value(startTime),
        endTime: d.Value(endTime),
        timeRepeatMode: d.Value(normalizedMode),
        timeRepeatDaysMask: d.Value(
          normalizeTimeRepeatDaysMask(
            timeRepeatDaysMask,
            repeatMode: normalizedMode,
          ),
        ),
        latitude: const d.Value<double?>(null),
        longitude: const d.Value<double?>(null),
        radius: const d.Value<int?>(null),
        savedLocationId: const d.Value<int?>(null),
        locationLabel: const d.Value<String?>(null),
        packageName: const d.Value<String?>(null),
        activityType: const d.Value<String?>(null),
      );
    case model.TriggerType.location:
      return RuleTriggerValues(
        type: 1,
        startTime: const d.Value<String?>(null),
        endTime: const d.Value<String?>(null),
        timeRepeatMode: const d.Value(timeRepeatEveryDay),
        timeRepeatDaysMask: const d.Value(timeRepeatEveryDayMask),
        latitude: d.Value(latitude),
        longitude: d.Value(longitude),
        radius: d.Value(radius),
        savedLocationId: d.Value(savedLocationId),
        locationLabel: d.Value(_cleanText(locationLabel)),
        packageName: const d.Value<String?>(null),
        activityType: const d.Value<String?>(null),
      );
    case model.TriggerType.app:
      return RuleTriggerValues(
        type: 2,
        startTime: const d.Value<String?>(null),
        endTime: const d.Value<String?>(null),
        timeRepeatMode: const d.Value(timeRepeatEveryDay),
        timeRepeatDaysMask: const d.Value(timeRepeatEveryDayMask),
        latitude: const d.Value<double?>(null),
        longitude: const d.Value<double?>(null),
        radius: const d.Value<int?>(null),
        savedLocationId: const d.Value<int?>(null),
        locationLabel: const d.Value<String?>(null),
        packageName: d.Value(packageName),
        activityType: const d.Value<String?>(null),
      );
    case model.TriggerType.activity:
      return RuleTriggerValues(
        type: 3,
        startTime: const d.Value<String?>(null),
        endTime: const d.Value<String?>(null),
        timeRepeatMode: const d.Value(timeRepeatEveryDay),
        timeRepeatDaysMask: const d.Value(timeRepeatEveryDayMask),
        latitude: const d.Value<double?>(null),
        longitude: const d.Value<double?>(null),
        radius: const d.Value<int?>(null),
        savedLocationId: const d.Value<int?>(null),
        locationLabel: const d.Value<String?>(null),
        packageName: const d.Value<String?>(null),
        activityType: d.Value(activityType),
      );
    case model.TriggerType.calendar:
      return const RuleTriggerValues(
        type: 4,
        startTime: d.Value<String?>(null),
        endTime: d.Value<String?>(null),
        timeRepeatMode: d.Value(timeRepeatEveryDay),
        timeRepeatDaysMask: d.Value(timeRepeatEveryDayMask),
        latitude: d.Value<double?>(null),
        longitude: d.Value<double?>(null),
        radius: d.Value<int?>(null),
        savedLocationId: d.Value<int?>(null),
        locationLabel: d.Value<String?>(null),
        packageName: d.Value<String?>(null),
        activityType: d.Value<String?>(null),
      );
  }
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
