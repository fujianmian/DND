import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// This line is required for code generation
part 'database.g.dart';

const int rulePriorityDriving = 90;
const int rulePriorityLocation = 80;
const int rulePriorityApp = 70;
const int rulePriorityCalendar = 65;
const int rulePriorityActivity = 60;
const int rulePriorityTime = 50;

const List<int> rulePriorityChoices = [
  rulePriorityTime,
  rulePriorityActivity,
  rulePriorityCalendar,
  rulePriorityApp,
  rulePriorityLocation,
  rulePriorityDriving,
];

String priorityLabel(int priority) {
  if (priority >= rulePriorityDriving) return 'Critical';
  if (priority >= rulePriorityLocation) return 'High';
  if (priority >= rulePriorityApp) return 'Medium';
  if (priority >= rulePriorityActivity) return 'Standard';
  return 'Low';
}

String priorityDescription(int priority) {
  return '${priorityLabel(priority)} priority';
}

int priorityForTrigger({required int triggerType, String? activityType}) {
  switch (triggerType) {
    case 0:
      return rulePriorityTime;
    case 1:
      return rulePriorityLocation;
    case 2:
      return rulePriorityApp;
    case 3:
      return _isDrivingActivity(activityType)
          ? rulePriorityDriving
          : rulePriorityActivity;
    case 4:
      return rulePriorityCalendar;
    default:
      return rulePriorityTime;
  }
}

int priorityForRuleTriggers(Iterable<RuleTrigger> triggers) {
  final priorities = triggers.map(
    (trigger) => priorityForTrigger(
      triggerType: trigger.triggerType,
      activityType: trigger.activityType,
    ),
  );
  return priorities.fold<int>(
    rulePriorityTime,
    (highest, priority) => priority > highest ? priority : highest,
  );
}

bool _isDrivingActivity(String? activityType) {
  final normalized = activityType?.trim().toUpperCase();
  return normalized == 'IN_VEHICLE' ||
      normalized == 'DRIVING' ||
      normalized == 'VEHICLE';
}

// 1. Define the Table
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get matchType => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(50))();
  IntColumn get type => integer()(); // 0 for Time, 1 for Location

  // Time params
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();

  // Location params
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get radius => integer().nullable()(); // ADD THIS

  // App Usage params (for future expansion)
  TextColumn get packageName => text().nullable()();

  TextColumn get activityType => text().nullable()();

  // DND exception settings
  BoolColumn get allowStarredContacts =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get allowRepeatCallers =>
      boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'rule_triggers_rule_id', columns: {#ruleId})
class RuleTriggers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ruleId => integer()();
  IntColumn get triggerType => integer()();

  // Time params
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();

  // Location params
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get radius => real().nullable()();

  // App Usage params
  TextColumn get packageName => text().nullable()();

  // Activity params
  TextColumn get activityType => text().nullable()();

  // Calendar params
  TextColumn get calendarId => text().nullable()();
  TextColumn get calendarKeyword => text().nullable()();
  BoolColumn get calendarIncludeAllDay =>
      boolean().withDefault(const Constant(false))();
  IntColumn get calendarLookaheadHours => integer().nullable()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

@TableIndex(name: 'calendar_busy_windows_trigger_id', columns: {#triggerId})
@TableIndex(name: 'calendar_busy_windows_start_millis', columns: {#startMillis})
class CalendarBusyWindowsCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get triggerId => text()();
  TextColumn get eventIdHash => text().nullable()();
  TextColumn get calendarId => text().nullable()();
  IntColumn get startMillis => integer()();
  IntColumn get endMillis => integer()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  BoolColumn get keywordMatched =>
      boolean().withDefault(const Constant(true))();
  IntColumn get fetchedAt => integer()();
}

class RuleWithTriggers {
  const RuleWithTriggers({required this.rule, required this.triggers});

  final Rule rule;
  final List<RuleTrigger> triggers;
}

// 2. The Database Class
@DriftDatabase(tables: [Rules, RuleTriggers, CalendarBusyWindowsCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(rules, rules.allowStarredContacts);
        await m.addColumn(rules, rules.allowRepeatCallers);
      }
      if (from < 3) {
        await m.addColumn(rules, rules.matchType);
        await m.createTable(ruleTriggers);
        await m.createIndex(ruleTriggersRuleId);
        await backfillLegacyRuleTriggers();
      }
      if (from < 4) {
        await m.addColumn(rules, rules.priority);
        await backfillRulePriorities();
      }
      if (from < 5) {
        await m.addColumn(ruleTriggers, ruleTriggers.calendarId);
        await m.addColumn(ruleTriggers, ruleTriggers.calendarKeyword);
        await m.addColumn(ruleTriggers, ruleTriggers.calendarIncludeAllDay);
        await m.addColumn(ruleTriggers, ruleTriggers.calendarLookaheadHours);
        await m.createTable(calendarBusyWindowsCache);
        await m.createIndex(calendarBusyWindowsTriggerId);
        await m.createIndex(calendarBusyWindowsStartMillis);
      }
    },
    beforeOpen: (_) async {
      await backfillLegacyRuleTriggers();
    },
  );

  // Simple Queries for MVP
  // 1. CREATE: Insert a new rule
  Future<int> insertRule(RulesCompanion rule) {
    return into(rules).insert(
      _withPriorityIfAbsent(rule, _priorityForLegacyRuleCompanion(rule)),
    );
  }

  Future<int> createSingleTriggerRule(RulesCompanion rule) {
    return transaction(() async {
      final triggerType = _requiredValue(rule.type, 'type');
      final derivedPriority = priorityForTrigger(
        triggerType: triggerType,
        activityType: _nullableValue(rule.activityType),
      );
      final ruleId = await into(
        rules,
      ).insert(_withPriorityIfAbsent(rule, derivedPriority));
      await _replaceSingleTriggerForValues(
        ruleId: ruleId,
        triggerType: triggerType,
        startTime: rule.startTime,
        endTime: rule.endTime,
        latitude: rule.latitude,
        longitude: rule.longitude,
        radius: _realValueFromInt(rule.radius),
        packageName: rule.packageName,
        activityType: rule.activityType,
      );
      return ruleId;
    });
  }

  Future<int> createRuleWithTriggers({
    required RulesCompanion rule,
    required List<RuleTriggersCompanion> triggers,
  }) {
    if (triggers.isEmpty) {
      throw ArgumentError('At least one trigger is required');
    }

    return transaction(() async {
      final ruleId = await into(rules).insert(
        _withPriorityIfAbsent(rule, _priorityForTriggerCompanions(triggers)),
      );
      await _insertTriggersForRule(ruleId, triggers);
      return ruleId;
    });
  }

  // 2. READ: Watch rules (returns a Stream for reactive UI updates)
  Stream<List<Rule>> watchAllRules() => select(rules).watch();

  Stream<List<RuleWithTriggers>> watchRulesWithTriggers() {
    final query = select(rules).join([
      leftOuterJoin(ruleTriggers, ruleTriggers.ruleId.equalsExp(rules.id)),
    ]);

    return query.watch().map(_groupRuleTriggerRows);
  }

  Future<List<RuleTrigger>> getRuleTriggers(int ruleId) {
    return (select(ruleTriggers)
          ..where((trigger) => trigger.ruleId.equals(ruleId))
          ..orderBy([(trigger) => OrderingTerm.asc(trigger.id)]))
        .get();
  }

  Stream<RuleWithTriggers?> watchRuleWithTriggers(int ruleId) {
    final query = select(rules).join([
      leftOuterJoin(ruleTriggers, ruleTriggers.ruleId.equalsExp(rules.id)),
    ])..where(rules.id.equals(ruleId));

    return query.watch().map((rows) {
      final grouped = _groupRuleTriggerRows(rows);
      if (grouped.isEmpty) return null;
      return grouped.single;
    });
  }

  Future<List<RuleWithTriggers>> getEnabledRulesWithTriggers() async {
    final query = select(rules).join([
      leftOuterJoin(ruleTriggers, ruleTriggers.ruleId.equalsExp(rules.id)),
    ])..where(rules.isEnabled.equals(true));

    return _groupRuleTriggerRows(await query.get());
  }

  // 3. UPDATE: Toggle enable/disable or edit rule
  Future<bool> updateRule(Rule rule) => update(rules).replace(rule);

  Future<bool> updateSingleTriggerRule(
    Rule rule, {
    bool preservePriority = false,
  }) {
    return transaction(() async {
      final updated = await update(rules).replace(
        preservePriority
            ? rule
            : rule.copyWith(
                priority: priorityForTrigger(
                  triggerType: rule.type,
                  activityType: rule.activityType,
                ),
              ),
      );
      await _replaceSingleTriggerForRule(rule);
      return updated;
    });
  }

  Future<int> updateRuleWithTriggers({
    required int ruleId,
    required RulesCompanion rule,
    required List<RuleTriggersCompanion> triggers,
  }) {
    if (triggers.isEmpty) {
      throw ArgumentError('At least one trigger is required');
    }

    return transaction(() async {
      final updated =
          await (update(rules)..where((rule) => rule.id.equals(ruleId))).write(
            _withPriorityIfAbsent(
              rule,
              _priorityForTriggerCompanions(triggers),
            ),
          );
      await (delete(
        ruleTriggers,
      )..where((trigger) => trigger.ruleId.equals(ruleId))).go();
      await _insertTriggersForRule(ruleId, triggers);
      return updated;
    });
  }

  // 4. DELETE: Remove a rule
  Future<int> deleteRule(Rule rule) => deleteRuleAndTriggers(rule.id);

  Future<int> deleteRuleAndTriggers(int ruleId) {
    return transaction(() async {
      await (delete(
        ruleTriggers,
      )..where((trigger) => trigger.ruleId.equals(ruleId))).go();
      return (delete(rules)..where((rule) => rule.id.equals(ruleId))).go();
    });
  }

  Future<void> backfillLegacyRuleTriggers() async {
    await customStatement('''
INSERT INTO rule_triggers (
  rule_id,
  trigger_type,
  start_time,
  end_time,
  latitude,
  longitude,
  radius,
  package_name,
  activity_type,
  enabled
)
SELECT
  rules.id,
  rules.type,
  CASE WHEN rules.type = 0 THEN rules.start_time ELSE NULL END,
  CASE WHEN rules.type = 0 THEN rules.end_time ELSE NULL END,
  CASE WHEN rules.type = 1 THEN rules.latitude ELSE NULL END,
  CASE WHEN rules.type = 1 THEN rules.longitude ELSE NULL END,
  CASE WHEN rules.type = 1 THEN CAST(rules.radius AS REAL) ELSE NULL END,
  CASE WHEN rules.type = 2 THEN rules.package_name ELSE NULL END,
  CASE WHEN rules.type = 3 THEN rules.activity_type ELSE NULL END,
  1
FROM rules
WHERE NOT EXISTS (
  SELECT 1
  FROM rule_triggers
  WHERE rule_triggers.rule_id = rules.id
)
''');
  }

  Future<void> backfillRulePriorities() async {
    await customStatement('''
UPDATE rules
SET priority = COALESCE(
  (
    SELECT MAX(
      CASE
        WHEN rule_triggers.trigger_type = 3
          AND UPPER(COALESCE(rule_triggers.activity_type, '')) IN ('IN_VEHICLE', 'DRIVING', 'VEHICLE')
          THEN $rulePriorityDriving
        WHEN rule_triggers.trigger_type = 1 THEN $rulePriorityLocation
        WHEN rule_triggers.trigger_type = 2 THEN $rulePriorityApp
        WHEN rule_triggers.trigger_type = 4 THEN $rulePriorityCalendar
        WHEN rule_triggers.trigger_type = 3 THEN $rulePriorityActivity
        WHEN rule_triggers.trigger_type = 0 THEN $rulePriorityTime
        ELSE $rulePriorityTime
      END
    )
    FROM rule_triggers
    WHERE rule_triggers.rule_id = rules.id
  ),
  CASE
    WHEN rules.type = 3
      AND UPPER(COALESCE(rules.activity_type, '')) IN ('IN_VEHICLE', 'DRIVING', 'VEHICLE')
      THEN $rulePriorityDriving
    WHEN rules.type = 1 THEN $rulePriorityLocation
    WHEN rules.type = 2 THEN $rulePriorityApp
    WHEN rules.type = 4 THEN $rulePriorityCalendar
    WHEN rules.type = 3 THEN $rulePriorityActivity
    WHEN rules.type = 0 THEN $rulePriorityTime
    ELSE $rulePriorityTime
  END
)
WHERE priority = $rulePriorityTime
''');
  }

  Future<void> _replaceSingleTriggerForRule(Rule rule) async {
    await _replaceSingleTriggerForValues(
      ruleId: rule.id,
      triggerType: rule.type,
      startTime: Value(rule.type == 0 ? rule.startTime : null),
      endTime: Value(rule.type == 0 ? rule.endTime : null),
      latitude: Value(rule.type == 1 ? rule.latitude : null),
      longitude: Value(rule.type == 1 ? rule.longitude : null),
      radius: Value(rule.type == 1 ? rule.radius?.toDouble() : null),
      packageName: Value(rule.type == 2 ? rule.packageName : null),
      activityType: Value(rule.type == 3 ? rule.activityType : null),
    );
  }

  Future<void> _replaceSingleTriggerForValues({
    required int ruleId,
    required int triggerType,
    required Value<String?> startTime,
    required Value<String?> endTime,
    required Value<double?> latitude,
    required Value<double?> longitude,
    required Value<double?> radius,
    required Value<String?> packageName,
    required Value<String?> activityType,
  }) async {
    await (delete(
      ruleTriggers,
    )..where((trigger) => trigger.ruleId.equals(ruleId))).go();
    await into(ruleTriggers).insert(
      RuleTriggersCompanion.insert(
        ruleId: ruleId,
        triggerType: triggerType,
        startTime: triggerType == 0 ? startTime : const Value(null),
        endTime: triggerType == 0 ? endTime : const Value(null),
        latitude: triggerType == 1 ? latitude : const Value(null),
        longitude: triggerType == 1 ? longitude : const Value(null),
        radius: triggerType == 1 ? radius : const Value(null),
        packageName: triggerType == 2 ? packageName : const Value(null),
        activityType: triggerType == 3 ? activityType : const Value(null),
        enabled: const Value(true),
      ),
    );
  }

  Future<void> _insertTriggersForRule(
    int ruleId,
    List<RuleTriggersCompanion> triggers,
  ) async {
    for (final trigger in triggers) {
      await into(ruleTriggers).insert(
        trigger.copyWith(id: const Value.absent(), ruleId: Value(ruleId)),
      );
    }
  }

  T _requiredValue<T>(Value<T> value, String fieldName) {
    if (!value.present) {
      throw ArgumentError(
        'Missing required $fieldName for single trigger rule',
      );
    }
    return value.value;
  }

  T? _nullableValue<T>(Value<T?> value) {
    if (!value.present) return null;
    return value.value;
  }

  Value<double?> _realValueFromInt(Value<int?> value) {
    if (!value.present) return const Value.absent();
    return Value(value.value?.toDouble());
  }

  RulesCompanion _withPriorityIfAbsent(RulesCompanion rule, int priority) {
    if (rule.priority.present) return rule;
    return _withPriority(rule, priority);
  }

  RulesCompanion _withPriority(RulesCompanion rule, int priority) {
    return rule.copyWith(priority: Value(priority));
  }

  int _priorityForLegacyRuleCompanion(RulesCompanion rule) {
    if (!rule.type.present) return rulePriorityTime;
    return priorityForTrigger(
      triggerType: rule.type.value,
      activityType: _nullableValue(rule.activityType),
    );
  }

  int _priorityForTriggerCompanions(Iterable<RuleTriggersCompanion> triggers) {
    return triggers.fold<int>(rulePriorityTime, (highest, trigger) {
      if (!trigger.triggerType.present) return highest;
      final priority = priorityForTrigger(
        triggerType: trigger.triggerType.value,
        activityType: _nullableValue(trigger.activityType),
      );
      return priority > highest ? priority : highest;
    });
  }

  List<RuleWithTriggers> _groupRuleTriggerRows(List<TypedResult> rows) {
    final grouped = <int, _MutableRuleWithTriggers>{};

    for (final row in rows) {
      final rule = row.readTable(rules);
      final trigger = row.readTableOrNull(ruleTriggers);
      final entry = grouped.putIfAbsent(
        rule.id,
        () => _MutableRuleWithTriggers(rule),
      );
      if (trigger != null) entry.triggers.add(trigger);
    }

    for (final entry in grouped.values) {
      entry.triggers.sort((a, b) => a.id.compareTo(b.id));
    }

    return grouped.values
        .map(
          (entry) => RuleWithTriggers(
            rule: entry.rule,
            triggers: List.unmodifiable(entry.triggers),
          ),
        )
        .toList();
  }
}

class _MutableRuleWithTriggers {
  _MutableRuleWithTriggers(this.rule);

  final Rule rule;
  final List<RuleTrigger> triggers = [];
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
