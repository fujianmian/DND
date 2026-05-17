import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/time_repeat.dart';

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

String? validateProfileName(String value) {
  return value.trim().isEmpty ? 'Profile name is required' : null;
}

// 1. Define the Table
@TableIndex(name: 'rules_profile_id', columns: {#profileId})
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get matchType => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(50))();
  IntColumn get type => integer()(); // 0 for Time, 1 for Location
  IntColumn get profileId => integer().nullable()();

  // Time params
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
  IntColumn get timeRepeatMode =>
      integer().withDefault(const Constant(timeRepeatEveryDay))();
  IntColumn get timeRepeatDaysMask =>
      integer().withDefault(const Constant(timeRepeatEveryDayMask))();

  // Location params
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get radius => integer().nullable()(); // ADD THIS
  IntColumn get savedLocationId => integer().nullable()();
  TextColumn get locationLabel => text().nullable()();

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
  IntColumn get timeRepeatMode =>
      integer().withDefault(const Constant(timeRepeatEveryDay))();
  IntColumn get timeRepeatDaysMask =>
      integer().withDefault(const Constant(timeRepeatEveryDayMask))();

  // Location params
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get radius => real().nullable()();
  IntColumn get savedLocationId => integer().nullable()();
  TextColumn get locationLabel => text().nullable()();

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

class SavedLocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get radius =>
      integer().check(const CustomExpression<bool>('radius >= 50'))();
  TextColumn get address => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get allowStarredContacts =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get allowRepeatCallers =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class RuleWithTriggers {
  const RuleWithTriggers({required this.rule, required this.triggers});

  final Rule rule;
  final List<RuleTrigger> triggers;
}

class ProfileWithRuleCount {
  const ProfileWithRuleCount({required this.profile, required this.ruleCount});

  final Profile profile;
  final int ruleCount;
}

// 2. The Database Class
@DriftDatabase(
  tables: [
    Rules,
    RuleTriggers,
    CalendarBusyWindowsCache,
    SavedLocations,
    Profiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(rules, rules.allowStarredContacts);
        await m.addColumn(rules, rules.allowRepeatCallers);
      }
      if (from < 6) {
        await m.addColumn(rules, rules.timeRepeatMode);
        await m.addColumn(rules, rules.timeRepeatDaysMask);
      }
      if (from < 7) {
        await m.createTable(savedLocations);
        await m.addColumn(rules, rules.savedLocationId);
        await m.addColumn(rules, rules.locationLabel);
      }
      if (from < 8) {
        await m.createTable(profiles);
        await m.addColumn(rules, rules.profileId);
        await m.createIndex(rulesProfileId);
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
        if (from >= 3) {
          await m.addColumn(ruleTriggers, ruleTriggers.calendarId);
          await m.addColumn(ruleTriggers, ruleTriggers.calendarKeyword);
          await m.addColumn(ruleTriggers, ruleTriggers.calendarIncludeAllDay);
          await m.addColumn(ruleTriggers, ruleTriggers.calendarLookaheadHours);
        }
        await m.createTable(calendarBusyWindowsCache);
        await m.createIndex(calendarBusyWindowsTriggerId);
        await m.createIndex(calendarBusyWindowsStartMillis);
      }
      if (from >= 3 && from < 6) {
        await m.addColumn(ruleTriggers, ruleTriggers.timeRepeatMode);
        await m.addColumn(ruleTriggers, ruleTriggers.timeRepeatDaysMask);
      }
      if (from >= 3 && from < 7) {
        await m.addColumn(ruleTriggers, ruleTriggers.savedLocationId);
        await m.addColumn(ruleTriggers, ruleTriggers.locationLabel);
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
      _withoutRuleExceptions(
        _withPriorityIfAbsent(rule, _priorityForLegacyRuleCompanion(rule)),
      ),
    );
  }

  Future<int> createSingleTriggerRule(RulesCompanion rule) {
    return transaction(() async {
      final triggerType = _requiredValue(rule.type, 'type');
      final derivedPriority = priorityForTrigger(
        triggerType: triggerType,
        activityType: _nullableValue(rule.activityType),
      );
      final ruleId = await into(rules).insert(
        _withoutRuleExceptions(_withPriorityIfAbsent(rule, derivedPriority)),
      );
      await _replaceSingleTriggerForValues(
        ruleId: ruleId,
        triggerType: triggerType,
        startTime: rule.startTime,
        endTime: rule.endTime,
        timeRepeatMode: rule.timeRepeatMode,
        timeRepeatDaysMask: rule.timeRepeatDaysMask,
        latitude: rule.latitude,
        longitude: rule.longitude,
        radius: _realValueFromInt(rule.radius),
        savedLocationId: rule.savedLocationId,
        locationLabel: rule.locationLabel,
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
        _withoutRuleExceptions(
          _withPriorityIfAbsent(rule, _priorityForTriggerCompanions(triggers)),
        ),
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

  Stream<List<RuleWithTriggers>> watchStandaloneRulesWithTriggers() {
    final query = select(rules).join([
      leftOuterJoin(ruleTriggers, ruleTriggers.ruleId.equalsExp(rules.id)),
    ])..where(rules.profileId.isNull());

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
  Future<bool> updateRule(Rule rule) {
    return update(rules).replace(_withoutRuleExceptionsRow(rule));
  }

  Future<bool> updateSingleTriggerRule(
    Rule rule, {
    bool preservePriority = false,
  }) {
    return transaction(() async {
      final updated = await update(rules).replace(
        _withoutRuleExceptionsRow(
          preservePriority
              ? rule
              : rule.copyWith(
                  priority: priorityForTrigger(
                    triggerType: rule.type,
                    activityType: rule.activityType,
                  ),
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
            _withoutRuleExceptions(
              _withPriorityIfAbsent(
                rule,
                _priorityForTriggerCompanions(triggers),
              ),
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

  Future<int> createProfile(ProfilesCompanion profile) {
    final name = _normalizeProfileName(_requiredValue(profile.name, 'name'));
    return into(profiles).insert(
      profile.copyWith(
        name: Value(name),
        allowStarredContacts: const Value(false),
        allowRepeatCallers: const Value(false),
      ),
    );
  }

  Future<bool> updateProfile(Profile profile) {
    final name = _normalizeProfileName(profile.name);
    return update(profiles).replace(
      profile.copyWith(
        name: name,
        allowStarredContacts: false,
        allowRepeatCallers: false,
      ),
    );
  }

  Future<int> setProfileEnabled(int id, bool enabled, {int? updatedAt}) {
    return (update(profiles)..where((profile) => profile.id.equals(id))).write(
      ProfilesCompanion(
        isEnabled: Value(enabled),
        updatedAt: Value(updatedAt ?? DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> archiveProfile(int id, {int? updatedAt}) {
    return archiveProfileAndUnassignRules(id, updatedAt: updatedAt);
  }

  // Profiles are archived, not hard-deleted. Rules remain intact and become
  // unprofiled so existing automations are not silently removed.
  Future<int> archiveProfileAndUnassignRules(int id, {int? updatedAt}) {
    return transaction(() async {
      await (update(rules)..where((rule) => rule.profileId.equals(id))).write(
        const RulesCompanion(profileId: Value<int?>(null)),
      );

      return (update(
        profiles,
      )..where((profile) => profile.id.equals(id))).write(
        ProfilesCompanion(
          isArchived: const Value(true),
          updatedAt: Value(updatedAt ?? DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  Stream<List<Profile>> watchActiveProfiles() {
    return watchProfiles();
  }

  Stream<List<Profile>> watchProfiles({bool includeArchived = false}) {
    final query = select(profiles)
      ..orderBy([(profile) => OrderingTerm.asc(profile.name)]);
    if (!includeArchived) {
      query.where((profile) => profile.isArchived.equals(false));
    }
    return query.watch();
  }

  Future<Profile?> getProfile(int id) {
    return (select(
      profiles,
    )..where((profile) => profile.id.equals(id))).getSingleOrNull();
  }

  Future<int> assignRuleToProfile(int ruleId, int? profileId) {
    return (update(rules)..where((rule) => rule.id.equals(ruleId))).write(
      RulesCompanion(profileId: Value<int?>(profileId)),
    );
  }

  Future<List<RuleWithTriggers>> getRulesForProfile(int? profileId) async {
    final query = select(rules).join([
      leftOuterJoin(ruleTriggers, ruleTriggers.ruleId.equalsExp(rules.id)),
    ]);
    if (profileId == null) {
      query.where(rules.profileId.isNull());
    } else {
      query.where(rules.profileId.equals(profileId));
    }
    return _groupRuleTriggerRows(await query.get());
  }

  Stream<List<RuleWithTriggers>> watchRulesForProfile(int? profileId) {
    final query = select(rules).join([
      leftOuterJoin(ruleTriggers, ruleTriggers.ruleId.equalsExp(rules.id)),
    ]);
    if (profileId == null) {
      query.where(rules.profileId.isNull());
    } else {
      query.where(rules.profileId.equals(profileId));
    }
    return query.watch().map(_groupRuleTriggerRows);
  }

  Future<int> countRulesForProfile(int profileId) {
    final count = rules.id.count();
    final query = selectOnly(rules)..where(rules.profileId.equals(profileId));
    query.addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Stream<List<ProfileWithRuleCount>> watchProfilesWithRuleCounts({
    bool includeArchived = false,
  }) {
    final archivedClause = includeArchived ? '' : 'WHERE p.is_archived = 0';
    return customSelect(
      '''
SELECT
  p.id,
  p.name,
  p.description,
  p.is_enabled,
  p.allow_starred_contacts,
  p.allow_repeat_callers,
  p.created_at,
  p.updated_at,
  p.is_archived,
  COUNT(r.id) AS rule_count
FROM profiles p
LEFT JOIN rules r ON r.profile_id = p.id
$archivedClause
GROUP BY p.id
ORDER BY p.name
''',
      readsFrom: {profiles, rules},
    ).watch().map((rows) {
      return rows
          .map((row) {
            return ProfileWithRuleCount(
              profile: Profile(
                id: row.read<int>('id'),
                name: row.read<String>('name'),
                description: row.readNullable<String>('description'),
                isEnabled: row.read<bool>('is_enabled'),
                allowStarredContacts: row.read<bool>('allow_starred_contacts'),
                allowRepeatCallers: row.read<bool>('allow_repeat_callers'),
                createdAt: row.read<int>('created_at'),
                updatedAt: row.read<int>('updated_at'),
                isArchived: row.read<bool>('is_archived'),
              ),
              ruleCount: row.read<int>('rule_count'),
            );
          })
          .toList(growable: false);
    });
  }

  Future<int> createSavedLocation(SavedLocationsCompanion location) {
    final name = _normalizeSavedLocationName(
      _requiredValue(location.name, 'name'),
    );
    _requiredValue(location.latitude, 'latitude');
    _requiredValue(location.longitude, 'longitude');
    _validateSavedLocationRadius(_requiredValue(location.radius, 'radius'));
    return into(savedLocations).insert(location.copyWith(name: Value(name)));
  }

  Future<bool> updateSavedLocation(SavedLocation location) {
    final name = _normalizeSavedLocationName(location.name);
    _validateSavedLocationRadius(location.radius);
    final normalizedLocation = location.copyWith(name: name);
    return transaction(() async {
      final updated = await update(savedLocations).replace(normalizedLocation);
      await _refreshSavedLocationReferences(normalizedLocation);
      return updated;
    });
  }

  Future<int> archiveSavedLocation(int id, {int? updatedAt}) {
    return (update(
      savedLocations,
    )..where((location) => location.id.equals(id))).write(
      SavedLocationsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(updatedAt ?? DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Stream<List<SavedLocation>> watchActiveSavedLocations() {
    return (select(savedLocations)
          ..where((location) => location.isArchived.equals(false))
          ..orderBy([(location) => OrderingTerm.asc(location.name)]))
        .watch();
  }

  Future<SavedLocation?> getSavedLocation(int id) {
    return (select(
      savedLocations,
    )..where((location) => location.id.equals(id))).getSingleOrNull();
  }

  Future<List<SavedLocation>> getAllSavedLocations({
    bool includeArchived = false,
  }) {
    final query = select(savedLocations)
      ..orderBy([(location) => OrderingTerm.asc(location.name)]);
    if (!includeArchived) {
      query.where((location) => location.isArchived.equals(false));
    }
    return query.get();
  }

  Future<void> backfillLegacyRuleTriggers() async {
    await customStatement('''
INSERT INTO rule_triggers (
  rule_id,
  trigger_type,
  start_time,
  end_time,
  time_repeat_mode,
  time_repeat_days_mask,
  latitude,
  longitude,
  radius,
  saved_location_id,
  location_label,
  package_name,
  activity_type,
  enabled
)
SELECT
  rules.id,
  rules.type,
  CASE WHEN rules.type = 0 THEN rules.start_time ELSE NULL END,
  CASE WHEN rules.type = 0 THEN rules.end_time ELSE NULL END,
  CASE WHEN rules.type = 0 THEN rules.time_repeat_mode ELSE $timeRepeatEveryDay END,
  CASE WHEN rules.type = 0 THEN rules.time_repeat_days_mask ELSE $timeRepeatEveryDayMask END,
  CASE WHEN rules.type = 1 THEN rules.latitude ELSE NULL END,
  CASE WHEN rules.type = 1 THEN rules.longitude ELSE NULL END,
  CASE WHEN rules.type = 1 THEN CAST(rules.radius AS REAL) ELSE NULL END,
  CASE WHEN rules.type = 1 THEN rules.saved_location_id ELSE NULL END,
  CASE WHEN rules.type = 1 THEN rules.location_label ELSE NULL END,
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
      timeRepeatMode: Value(
        rule.type == 0 ? rule.timeRepeatMode : timeRepeatEveryDay,
      ),
      timeRepeatDaysMask: Value(
        rule.type == 0 ? rule.timeRepeatDaysMask : timeRepeatEveryDayMask,
      ),
      latitude: Value(rule.type == 1 ? rule.latitude : null),
      longitude: Value(rule.type == 1 ? rule.longitude : null),
      radius: Value(rule.type == 1 ? rule.radius?.toDouble() : null),
      savedLocationId: Value(rule.type == 1 ? rule.savedLocationId : null),
      locationLabel: Value(rule.type == 1 ? rule.locationLabel : null),
      packageName: Value(rule.type == 2 ? rule.packageName : null),
      activityType: Value(rule.type == 3 ? rule.activityType : null),
    );
  }

  Future<void> _replaceSingleTriggerForValues({
    required int ruleId,
    required int triggerType,
    required Value<String?> startTime,
    required Value<String?> endTime,
    required Value<int> timeRepeatMode,
    required Value<int> timeRepeatDaysMask,
    required Value<double?> latitude,
    required Value<double?> longitude,
    required Value<double?> radius,
    required Value<int?> savedLocationId,
    required Value<String?> locationLabel,
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
        timeRepeatMode: triggerType == 0
            ? timeRepeatMode
            : const Value(timeRepeatEveryDay),
        timeRepeatDaysMask: triggerType == 0
            ? timeRepeatDaysMask
            : const Value(timeRepeatEveryDayMask),
        latitude: triggerType == 1 ? latitude : const Value(null),
        longitude: triggerType == 1 ? longitude : const Value(null),
        radius: triggerType == 1 ? radius : const Value(null),
        savedLocationId: triggerType == 1 ? savedLocationId : const Value(null),
        locationLabel: triggerType == 1 ? locationLabel : const Value(null),
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

  String _normalizeProfileName(String name) {
    final validationError = validateProfileName(name);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
    return name.trim();
  }

  String _normalizeSavedLocationName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Saved location name is required');
    }
    return trimmed;
  }

  void _validateSavedLocationRadius(int radius) {
    if (radius < 50) {
      throw ArgumentError('Saved location radius must be at least 50m');
    }
  }

  Future<void> _refreshSavedLocationReferences(SavedLocation location) async {
    await (update(
      rules,
    )..where((rule) => rule.savedLocationId.equals(location.id))).write(
      RulesCompanion(
        latitude: Value(location.latitude),
        longitude: Value(location.longitude),
        radius: Value(location.radius),
        locationLabel: Value(location.name),
      ),
    );

    await (update(
      ruleTriggers,
    )..where((trigger) => trigger.savedLocationId.equals(location.id))).write(
      RuleTriggersCompanion(
        latitude: Value(location.latitude),
        longitude: Value(location.longitude),
        radius: Value(location.radius.toDouble()),
        locationLabel: Value(location.name),
      ),
    );
  }

  Value<double?> _realValueFromInt(Value<int?> value) {
    if (!value.present) return const Value.absent();
    return Value(value.value?.toDouble());
  }

  RulesCompanion _withPriorityIfAbsent(RulesCompanion rule, int priority) {
    if (rule.priority.present) return rule;
    return _withPriority(rule, priority);
  }

  RulesCompanion _withoutRuleExceptions(RulesCompanion rule) {
    return rule.copyWith(
      allowStarredContacts: const Value(false),
      allowRepeatCallers: const Value(false),
    );
  }

  Rule _withoutRuleExceptionsRow(Rule rule) {
    return rule.copyWith(
      allowStarredContacts: false,
      allowRepeatCallers: false,
    );
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
