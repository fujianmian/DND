import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/models/rule_trigger_draft.dart';
import 'package:dnd_auto_app/models/rule_trigger_summary.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('derives trigger priorities by type and driving activity', () {
    expect(priorityForTrigger(triggerType: 0), 50);
    expect(priorityForTrigger(triggerType: 1), 80);
    expect(priorityForTrigger(triggerType: 2), 70);
    expect(priorityForTrigger(triggerType: 3, activityType: 'WALKING'), 60);
    expect(priorityForTrigger(triggerType: 3, activityType: 'IN_VEHICLE'), 90);
    expect(priorityForTrigger(triggerType: 4), 65);
    expect(priorityForTrigger(triggerType: 99), 50);
  });

  test('maps priority values to display labels', () {
    expect(priorityLabel(50), 'Low');
    expect(priorityLabel(60), 'Standard');
    expect(priorityLabel(65), 'Standard');
    expect(priorityLabel(70), 'Medium');
    expect(priorityLabel(80), 'High');
    expect(priorityLabel(90), 'Critical');
    expect(priorityDescription(80), 'High priority');
  });

  test('derives draft priority from highest contained trigger', () {
    expect(
      priorityForDrafts(const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '17:00',
        ),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.location,
          latitude: 3.1,
          longitude: 101.6,
          radius: 100,
        ),
      ]),
      80,
    );
    expect(
      priorityForDrafts(const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '17:00',
        ),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.activity,
          activityType: 'IN_VEHICLE',
        ),
      ]),
      90,
    );
    expect(
      priorityForDrafts(const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '17:00',
        ),
        RuleTriggerDraft(triggerType: RuleTriggerDraft.calendar),
      ]),
      65,
    );
  });

  test('backfills legacy rules once without duplicating triggers', () async {
    final ruleId = await database.insertRule(
      RulesCompanion.insert(
        name: 'Focus',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );

    await database.backfillLegacyRuleTriggers();
    await database.backfillLegacyRuleTriggers();

    final triggers = await (database.select(
      database.ruleTriggers,
    )..where((trigger) => trigger.ruleId.equals(ruleId))).get();

    expect(triggers, hasLength(1));
    expect(triggers.single.triggerType, 0);
    expect(triggers.single.startTime, '09:00');
    expect(triggers.single.endTime, '17:00');
    expect(triggers.single.enabled, isTrue);
  });

  test('backfills default priority from triggers or legacy fields', () async {
    final multiId = await database
        .into(database.rules)
        .insert(
          RulesCompanion.insert(
            name: 'Library Focus',
            type: 0,
            priority: const d.Value(50),
          ),
        );
    await database
        .into(database.ruleTriggers)
        .insert(
          RuleTriggersCompanion.insert(
            ruleId: multiId,
            triggerType: 0,
            startTime: const d.Value('09:00'),
            endTime: const d.Value('17:00'),
          ),
        );
    await database
        .into(database.ruleTriggers)
        .insert(
          RuleTriggersCompanion.insert(
            ruleId: multiId,
            triggerType: 4,
            calendarId: const d.Value('primary'),
          ),
        );
    await database
        .into(database.ruleTriggers)
        .insert(
          RuleTriggersCompanion.insert(
            ruleId: multiId,
            triggerType: 1,
            latitude: const d.Value(3.1),
            longitude: const d.Value(101.6),
            radius: const d.Value(100),
          ),
        );

    final drivingId = await database
        .into(database.rules)
        .insert(
          RulesCompanion.insert(
            name: 'Driving',
            type: 3,
            activityType: const d.Value('IN_VEHICLE'),
            priority: const d.Value(50),
          ),
        );
    await database
        .into(database.ruleTriggers)
        .insert(
          RuleTriggersCompanion.insert(
            ruleId: drivingId,
            triggerType: 3,
            activityType: const d.Value('IN_VEHICLE'),
          ),
        );

    final legacyAppId = await database
        .into(database.rules)
        .insert(
          RulesCompanion.insert(
            name: 'Legacy App',
            type: 2,
            packageName: const d.Value('com.example.legacy'),
            priority: const d.Value(50),
          ),
        );

    await database.backfillRulePriorities();
    await database.backfillRulePriorities();

    final rules = await database.select(database.rules).get();
    expect(rules.where((rule) => rule.id == multiId).single.priority, 80);
    expect(rules.where((rule) => rule.id == drivingId).single.priority, 90);
    expect(rules.where((rule) => rule.id == legacyAppId).single.priority, 70);
  });

  test('creates one trigger row for each single-trigger rule type', () async {
    final timeId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Time',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );
    final locationId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Location',
        type: 1,
        latitude: const d.Value(3.1),
        longitude: const d.Value(101.6),
        radius: const d.Value(100),
      ),
    );
    final appId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'App',
        type: 2,
        packageName: const d.Value('com.example.app'),
      ),
    );
    final activityId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Activity',
        type: 3,
        activityType: const d.Value('WALKING'),
      ),
    );

    final triggers = await database.select(database.ruleTriggers).get();

    expect(triggers, hasLength(4));
    expect(
      triggers.where((trigger) => trigger.ruleId == timeId).single.startTime,
      '09:00',
    );
    expect(
      triggers.where((trigger) => trigger.ruleId == locationId).single.radius,
      100.0,
    );
    expect(
      triggers.where((trigger) => trigger.ruleId == appId).single.packageName,
      'com.example.app',
    );
    expect(
      triggers
          .where((trigger) => trigger.ruleId == activityId)
          .single
          .activityType,
      'WALKING',
    );

    final rules = await database.select(database.rules).get();
    expect(rules.where((rule) => rule.id == timeId).single.priority, 50);
    expect(rules.where((rule) => rule.id == locationId).single.priority, 80);
    expect(rules.where((rule) => rule.id == appId).single.priority, 70);
    expect(rules.where((rule) => rule.id == activityId).single.priority, 60);
  });

  test('updates and deletes the synchronized trigger row', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Original',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );
    final rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();

    await database.updateSingleTriggerRule(
      rule.copyWith(
        type: 2,
        startTime: const d.Value(null),
        endTime: const d.Value(null),
        packageName: const d.Value('com.example.updated'),
      ),
    );

    final updatedTriggers = await (database.select(
      database.ruleTriggers,
    )..where((trigger) => trigger.ruleId.equals(ruleId))).get();

    expect(updatedTriggers, hasLength(1));
    expect(updatedTriggers.single.triggerType, 2);
    expect(updatedTriggers.single.packageName, 'com.example.updated');
    expect(updatedTriggers.single.startTime, isNull);
    final updatedRule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    expect(updatedRule.priority, 70);

    await database.deleteRuleAndTriggers(ruleId);

    expect(await database.select(database.rules).get(), isEmpty);
    expect(await database.select(database.ruleTriggers).get(), isEmpty);
  });

  test('preserves selected priority when explicitly requested', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Manual Priority',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
        priority: const d.Value(90),
      ),
    );
    var rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    expect(rule.priority, 90);

    await database.updateSingleTriggerRule(
      rule.copyWith(
        type: 2,
        startTime: const d.Value(null),
        endTime: const d.Value(null),
        packageName: const d.Value('com.example.manual'),
        priority: 80,
      ),
      preservePriority: true,
    );

    rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    expect(rule.priority, 80);

    await database.updateRuleWithTriggers(
      ruleId: ruleId,
      rule: withFirstTriggerLegacyFields(
        const RulesCompanion(priority: d.Value(90)),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '10:00',
          endTime: '11:00',
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '10:00',
          endTime: '11:00',
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );

    rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    expect(rule.priority, 90);
  });

  test('watches rules grouped with triggers', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Grouped',
        type: 2,
        packageName: const d.Value('com.example.grouped'),
      ),
    );

    final grouped = await database.watchRulesWithTriggers().first;

    expect(grouped, hasLength(1));
    expect(grouped.single.rule.id, ruleId);
    expect(grouped.single.triggers, hasLength(1));
    expect(grouped.single.triggers.single.packageName, 'com.example.grouped');
  });

  test('formats single, multiple, and legacy fallback summaries', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Multi',
        type: 0,
        matchType: const d.Value(1),
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );
    await database
        .into(database.ruleTriggers)
        .insert(
          RuleTriggersCompanion.insert(
            ruleId: ruleId,
            triggerType: 2,
            packageName: const d.Value('com.example.multi'),
          ),
        );

    final grouped = await database.watchRulesWithTriggers().first;
    final multiSummary = RuleTriggerSummaryFormatter.ruleSummary(
      grouped.single,
      appLabelFor: (_) => 'Example App',
    );

    expect(multiSummary, 'All of 2 conditions');
    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        grouped.single.triggers.last,
        appLabelFor: (_) => 'Example App',
      ),
      'App: Example App',
    );
    expect(
      RuleTriggerSummaryFormatter.ruleSummary(
        RuleWithTriggers(rule: grouped.single.rule, triggers: const []),
        appLabelFor: (_) => 'Example App',
      ),
      'Time: 09:00 - 17:00',
    );
  });

  test('formats calendar trigger summaries', () async {
    final ruleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Meetings', type: 0),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.calendar,
          calendarKeyword: 'exam',
          calendarIncludeAllDay: true,
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.calendar,
          calendarKeyword: 'exam',
          calendarIncludeAllDay: true,
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );

    final trigger = (await database.getRuleTriggers(ruleId)).single;

    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        trigger,
        appLabelFor: (_) => 'Example App',
      ),
      "Calendar event matching 'exam', including all-day",
    );

    final plainId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Calendar', type: 0),
        const RuleTriggerDraft(triggerType: RuleTriggerDraft.calendar),
      ),
      triggers: const [
        RuleTriggerDraft(triggerType: RuleTriggerDraft.calendar),
      ].map((draft) => draft.toCompanion()).toList(),
    );
    final plainTrigger = (await database.getRuleTriggers(plainId)).single;

    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        plainTrigger,
        appLabelFor: (_) => 'Example App',
      ),
      'Calendar event',
    );
  });

  test(
    'stores simplified calendar busy windows without event details',
    () async {
      await database
          .into(database.calendarBusyWindowsCache)
          .insert(
            CalendarBusyWindowsCacheCompanion.insert(
              triggerId: '42',
              eventIdHash: const d.Value('hashed-event-id'),
              calendarId: const d.Value('primary'),
              startMillis: 1710000000000,
              endMillis: 1710003600000,
              fetchedAt: 1709990000000,
            ),
          );

      final windows = await database
          .select(database.calendarBusyWindowsCache)
          .get();

      expect(windows, hasLength(1));
      expect(windows.single.triggerId, '42');
      expect(windows.single.eventIdHash, 'hashed-event-id');
      expect(windows.single.calendarId, 'primary');
      expect(windows.single.startMillis, 1710000000000);
      expect(windows.single.endMillis, 1710003600000);
      expect(windows.single.isAllDay, isFalse);
      expect(windows.single.keywordMatched, isTrue);
      expect(windows.single.fetchedAt, 1709990000000);
    },
  );

  test(
    'saves calendar trigger fields through rule trigger companions',
    () async {
      const draft = RuleTriggerDraft(
        triggerType: RuleTriggerDraft.calendar,
        calendarKeyword: ' exam ',
        calendarIncludeAllDay: true,
      );

      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Calendar', type: 0),
          draft,
        ),
        triggers: [draft.toCompanion()],
      );

      final trigger = (await database.getRuleTriggers(ruleId)).single;
      expect(trigger.triggerType, RuleTriggerDraft.calendar);
      expect(trigger.calendarId, isNull);
      expect(trigger.calendarKeyword, 'exam');
      expect(trigger.calendarIncludeAllDay, isTrue);
      expect(trigger.calendarLookaheadHours, isNull);
    },
  );

  test(
    'creates and updates multi-trigger rule priority from max trigger',
    () async {
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Campus', type: 0),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
        ),
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.1,
            longitude: 101.6,
            radius: 100,
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );

      var rule = await (database.select(
        database.rules,
      )..where((rule) => rule.id.equals(ruleId))).getSingle();
      expect(rule.priority, 80);

      await database.updateRuleWithTriggers(
        ruleId: ruleId,
        rule: withFirstTriggerLegacyFields(
          const RulesCompanion(),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.activity,
            activityType: 'IN_VEHICLE',
          ),
        ),
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.activity,
            activityType: 'IN_VEHICLE',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.app,
            packageName: 'com.example.maps',
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );

      rule = await (database.select(
        database.rules,
      )..where((rule) => rule.id.equals(ruleId))).getSingle();
      expect(rule.priority, 90);
    },
  );
}
