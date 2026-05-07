import 'package:drift/drift.dart' as d;

import 'rule.dart' as model;

class RuleTriggerValues {
  final int type;
  final d.Value<String?> startTime;
  final d.Value<String?> endTime;
  final d.Value<double?> latitude;
  final d.Value<double?> longitude;
  final d.Value<int?> radius;
  final d.Value<String?> packageName;
  final d.Value<String?> activityType;

  const RuleTriggerValues({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.packageName,
    required this.activityType,
  });
}

RuleTriggerValues cleanedRuleTriggerValues({
  required model.TriggerType triggerType,
  String? startTime,
  String? endTime,
  double? latitude,
  double? longitude,
  int? radius,
  String? packageName,
  String? activityType,
}) {
  switch (triggerType) {
    case model.TriggerType.time:
      return RuleTriggerValues(
        type: 0,
        startTime: d.Value(startTime),
        endTime: d.Value(endTime),
        latitude: const d.Value<double?>(null),
        longitude: const d.Value<double?>(null),
        radius: const d.Value<int?>(null),
        packageName: const d.Value<String?>(null),
        activityType: const d.Value<String?>(null),
      );
    case model.TriggerType.location:
      return RuleTriggerValues(
        type: 1,
        startTime: const d.Value<String?>(null),
        endTime: const d.Value<String?>(null),
        latitude: d.Value(latitude),
        longitude: d.Value(longitude),
        radius: d.Value(radius),
        packageName: const d.Value<String?>(null),
        activityType: const d.Value<String?>(null),
      );
    case model.TriggerType.app:
      return RuleTriggerValues(
        type: 2,
        startTime: const d.Value<String?>(null),
        endTime: const d.Value<String?>(null),
        latitude: const d.Value<double?>(null),
        longitude: const d.Value<double?>(null),
        radius: const d.Value<int?>(null),
        packageName: d.Value(packageName),
        activityType: const d.Value<String?>(null),
      );
    case model.TriggerType.activity:
      return RuleTriggerValues(
        type: 3,
        startTime: const d.Value<String?>(null),
        endTime: const d.Value<String?>(null),
        latitude: const d.Value<double?>(null),
        longitude: const d.Value<double?>(null),
        radius: const d.Value<int?>(null),
        packageName: const d.Value<String?>(null),
        activityType: d.Value(activityType),
      );
  }
}
