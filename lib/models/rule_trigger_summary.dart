import '../database/database.dart';
import 'time_repeat.dart';

typedef AppLabelResolver = String Function(String? packageName);

class RuleTriggerSummaryFormatter {
  static const anyMatchType = 0;
  static const allMatchType = 1;

  static const Map<String, String> activityLabels = {
    'IN_VEHICLE': 'In Vehicle',
    'ON_BICYCLE': 'On Bicycle',
    'WALKING': 'Walking / On Foot',
    'RUNNING': 'Running',
    'STILL': 'Still / Not Moving',
    'TILTING': 'Tilting Device',
  };

  const RuleTriggerSummaryFormatter._();

  static String ruleSummary(
    RuleWithTriggers ruleWithTriggers, {
    required AppLabelResolver appLabelFor,
  }) {
    final triggers = ruleWithTriggers.triggers;
    if (triggers.isEmpty) {
      return legacyRuleSummary(ruleWithTriggers.rule, appLabelFor: appLabelFor);
    }

    if (triggers.length == 1) {
      return triggerSummary(triggers.single, appLabelFor: appLabelFor);
    }

    final count = triggers.length;
    switch (ruleWithTriggers.rule.matchType) {
      case allMatchType:
        return 'All of $count conditions';
      case anyMatchType:
      default:
        return 'Any of $count conditions';
    }
  }

  static String triggerSummary(
    RuleTrigger trigger, {
    required AppLabelResolver appLabelFor,
  }) {
    switch (trigger.triggerType) {
      case 0:
        final start = trigger.startTime ?? '--';
        final end = trigger.endTime ?? '--';
        final repeat = repeatLabel(
          trigger.timeRepeatMode,
          daysMask: trigger.timeRepeatDaysMask,
        );
        return 'Time: $start-$end, $repeat';
      case 1:
        return _locationSummary(trigger.locationLabel, trigger.radius);
      case 2:
        return 'App: ${appLabelFor(trigger.packageName)}';
      case 3:
        return 'Activity: ${activityLabels[trigger.activityType] ?? trigger.activityType ?? 'Not selected'}';
      case 4:
        return _calendarSummary(
          trigger.calendarKeyword,
          trigger.calendarIncludeAllDay,
        );
      default:
        return 'Unknown trigger';
    }
  }

  static String legacyRuleSummary(
    Rule rule, {
    required AppLabelResolver appLabelFor,
  }) {
    switch (rule.type) {
      case 0:
        final start = rule.startTime ?? '--';
        final end = rule.endTime ?? '--';
        final repeat = repeatLabel(
          rule.timeRepeatMode,
          daysMask: rule.timeRepeatDaysMask,
        );
        return 'Time: $start-$end, $repeat';
      case 1:
        return _locationSummary(rule.locationLabel, rule.radius?.toDouble());
      case 2:
        return 'App: ${appLabelFor(rule.packageName)}';
      case 3:
        return 'Activity: ${activityLabels[rule.activityType] ?? rule.activityType ?? 'Not selected'}';
      case 4:
        return 'Calendar event';
      default:
        return 'Unknown trigger';
    }
  }

  static String _calendarSummary(String? keyword, bool includeAllDay) {
    final cleanedKeyword = keyword?.trim();
    final hasKeyword = cleanedKeyword != null && cleanedKeyword.isNotEmpty;
    final base = hasKeyword
        ? "Calendar event matching '$cleanedKeyword'"
        : 'Calendar event';
    return includeAllDay ? '$base, including all-day' : base;
  }

  static String _locationSummary(String? locationLabel, double? radius) {
    final cleanedLabel = locationLabel?.trim();
    final radiusText = _formatRadius(radius);
    if (cleanedLabel != null && cleanedLabel.isNotEmpty) {
      if (radiusText == null) return 'Location: $cleanedLabel';
      return 'Location: $cleanedLabel, $radiusText';
    }
    if (radiusText == null) return 'Location';
    return 'Location, $radiusText';
  }

  static String? _formatRadius(double? radius) {
    if (radius == null) return null;
    final value = radius == radius.roundToDouble()
        ? radius.toInt().toString()
        : radius.toStringAsFixed(1);
    return '${value}m';
  }
}
