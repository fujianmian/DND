import 'dart:convert';

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/models/rule_trigger_draft.dart';
import 'package:dnd_auto_app/services/automation_manager.dart';

void main() {
  late AppDatabase database;
  late AutomationManager automationManager;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    automationManager = AutomationManager();
  });

  tearDown(() async {
    await database.close();
  });

  test('builds single-trigger time payload from RuleTriggers', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Focus',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
        allowStarredContacts: const d.Value(true),
      ),
    );
    final rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();

    await database.updateRule(
      rule.copyWith(
        startTime: const d.Value('01:00'),
        endTime: const d.Value('02:00'),
      ),
    );

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.timeRules, hasLength(1));
    expect(payload.timeRules.single['startHour'], 9);
    expect(payload.timeRules.single['endHour'], 17);
    expect(payload.timeRules.single['allowStarredContacts'], isTrue);
    expect(payload.legacyFallbackCount, 0);
    expect(payload.groupedRuleCount, 1);
    expect(payload.groupedTriggerCount, 1);
    expect(payload.skippedInvalidGroupedTriggerCount, 0);

    final groupedRules = jsonDecode(payload.automationRulesJson) as List;
    final groupedRule = groupedRules.single as Map<String, dynamic>;
    expect(groupedRule['id'], ruleId.toString());
    expect(groupedRule['name'], 'Focus');
    expect(groupedRule['enabled'], isTrue);
    expect(groupedRule['matchType'], 0);
    expect(groupedRule['priority'], 50);
    expect(groupedRule['allowStarredContacts'], isTrue);
    expect(groupedRule['allowRepeatCallers'], isFalse);

    final triggers = groupedRule['triggers'] as List;
    final trigger = triggers.single as Map<String, dynamic>;
    expect(trigger['triggerType'], 0);
    expect(trigger['enabled'], isTrue);
    expect(trigger['startHour'], 9);
    expect(trigger['startMinute'], 0);
    expect(trigger['endHour'], 17);
    expect(trigger['endMinute'], 0);
  });

  test('falls back to legacy Rules fields when triggers are missing', () async {
    await database.insertRule(
      RulesCompanion.insert(
        name: 'Legacy App',
        type: 2,
        packageName: const d.Value('com.example.legacy'),
        allowRepeatCallers: const d.Value(true),
      ),
    );

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.appRules, hasLength(1));
    expect(payload.appRules.single['packageName'], 'com.example.legacy');
    expect(payload.appRules.single['allowRepeatCallers'], isTrue);
    expect(payload.legacyFallbackCount, 1);
    expect(payload.groupedRuleCount, 0);
    expect(payload.groupedTriggerCount, 0);
    expect(jsonDecode(payload.automationRulesJson), isEmpty);
  });

  test('flattens multiple triggers with parent rule metadata', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Hybrid',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
        allowStarredContacts: const d.Value(true),
        allowRepeatCallers: const d.Value(true),
      ),
    );
    await database
        .into(database.ruleTriggers)
        .insert(
          RuleTriggersCompanion.insert(
            ruleId: ruleId,
            triggerType: 2,
            packageName: const d.Value('com.example.hybrid'),
          ),
        );

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.timeRules, hasLength(1));
    expect(payload.appRules, hasLength(1));
    expect(payload.flattenedMultiTriggerRuleCount, 1);
    expect(payload.timeRules.single['id'], ruleId.toString());
    expect(payload.appRules.single['id'], ruleId.toString());
    expect(payload.appRules.single['name'], 'Hybrid');
    expect(payload.appRules.single['allowStarredContacts'], isTrue);
    expect(payload.appRules.single['allowRepeatCallers'], isTrue);
  });

  test(
    'flattens three-condition ALL rule without enforcing matchType',
    () async {
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'All Saved',
            type: 0,
            matchType: const d.Value(1),
            startTime: const d.Value('09:00'),
            endTime: const d.Value('17:00'),
            allowStarredContacts: const d.Value(true),
          ),
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
            triggerType: RuleTriggerDraft.app,
            packageName: 'com.example.all',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.activity,
            activityType: 'WALKING',
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );

      final payload = automationManager.buildSyncPayloadFromRuleTriggers(
        await database.getEnabledRulesWithTriggers(),
      );

      expect(payload.flattenedMultiTriggerRuleCount, 1);
      expect(payload.timeRules, hasLength(1));
      expect(payload.appRules, hasLength(1));
      expect(payload.activityRules, hasLength(1));
      expect(payload.groupedRuleCount, 1);
      expect(payload.groupedTriggerCount, 3);
      expect(payload.skippedInvalidGroupedTriggerCount, 0);
      for (final entry in [
        payload.timeRules.single,
        payload.appRules.single,
        payload.activityRules.single,
      ]) {
        expect(entry['id'], ruleId.toString());
        expect(entry['name'], 'All Saved');
        expect(entry['allowStarredContacts'], isTrue);
      }

      final groupedRules = jsonDecode(payload.automationRulesJson) as List;
      final groupedRule = groupedRules.single as Map<String, dynamic>;
      expect(groupedRule['id'], ruleId.toString());
      expect(groupedRule['name'], 'All Saved');
      expect(groupedRule['matchType'], 1);
      expect(groupedRule['priority'], 70);
      expect(groupedRule['allowStarredContacts'], isTrue);

      final triggers = groupedRule['triggers'] as List;
      expect(triggers, hasLength(3));
      expect(
        triggers.map((trigger) => (trigger as Map)['triggerType']),
        containsAll([0, 2, 3]),
      );
      expect(
        triggers.where(
          (trigger) => (trigger as Map)['packageName'] == 'com.example.all',
        ),
        hasLength(1),
      );
      expect(
        triggers.where(
          (trigger) => (trigger as Map)['activityType'] == 'WALKING',
        ),
        hasLength(1),
      );
    },
  );

  test('skips disabled trigger rows without legacy fallback', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Disabled Trigger',
        type: 2,
        packageName: const d.Value('com.example.disabled'),
      ),
    );
    final trigger = await (database.select(
      database.ruleTriggers,
    )..where((trigger) => trigger.ruleId.equals(ruleId))).getSingle();
    await database
        .update(database.ruleTriggers)
        .replace(trigger.copyWith(enabled: false));

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.appRules, isEmpty);
    expect(payload.enabledTriggerCount, 0);
    expect(payload.legacyFallbackCount, 0);
    expect(payload.groupedRuleCount, 0);
    expect(payload.groupedTriggerCount, 0);
    expect(jsonDecode(payload.automationRulesJson), isEmpty);
  });

  test('skips invalid grouped triggers safely', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Invalid Time',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );
    final trigger = await (database.select(
      database.ruleTriggers,
    )..where((trigger) => trigger.ruleId.equals(ruleId))).getSingle();
    await database
        .update(database.ruleTriggers)
        .replace(trigger.copyWith(startTime: const d.Value('bad-time')));

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.timeRules, isEmpty);
    expect(payload.enabledTriggerCount, 1);
    expect(payload.groupedRuleCount, 0);
    expect(payload.groupedTriggerCount, 0);
    expect(payload.skippedInvalidGroupedTriggerCount, 1);
    expect(jsonDecode(payload.automationRulesJson), isEmpty);
  });

  test('includes calendar triggers in grouped payload', () async {
    final ruleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Meeting', type: 0),
        const RuleTriggerDraft(triggerType: RuleTriggerDraft.calendar),
      ),
      triggers: const [
        RuleTriggerDraft(triggerType: RuleTriggerDraft.calendar),
      ].map((draft) => draft.toCompanion()).toList(),
    );

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    final groupedRules = jsonDecode(payload.automationRulesJson) as List;
    final groupedRule = groupedRules.single as Map<String, dynamic>;
    expect(groupedRule['id'], ruleId.toString());

    final triggers = groupedRule['triggers'] as List;
    final trigger = triggers.single as Map<String, dynamic>;
    expect(trigger['triggerType'], RuleTriggerDraft.calendar);
    expect(trigger.containsKey('packageName'), isFalse);
    expect(trigger.containsKey('startHour'), isFalse);
  });

  test('calendar busy windows serialize without event details', () async {
    await database
        .into(database.calendarBusyWindowsCache)
        .insert(
          CalendarBusyWindowsCacheCompanion.insert(
            triggerId: '12',
            eventIdHash: const d.Value('hashed-only'),
            calendarId: const d.Value('primary'),
            startMillis: 1760000000000,
            endMillis: 1760003600000,
            isAllDay: const d.Value(false),
            keywordMatched: const d.Value(true),
            fetchedAt: 1760000000000,
          ),
        );

    final decoded =
        jsonDecode(
              await automationManager.buildCalendarBusyWindowsJson(database),
            )
            as List;

    expect(decoded, hasLength(1));
    final window = decoded.single as Map<String, dynamic>;
    expect(window, {
      'triggerId': '12',
      'startMillis': 1760000000000,
      'endMillis': 1760003600000,
      'isAllDay': false,
      'keywordMatched': true,
      'fetchedAt': 1760000000000,
    });
    expect(window.containsKey('eventIdHash'), isFalse);
    expect(window.containsKey('title'), isFalse);
    expect(window.containsKey('description'), isFalse);
    expect(window.containsKey('attendees'), isFalse);
    expect(window.containsKey('location'), isFalse);
  });

  test('empty calendar busy window cache serializes as empty array', () async {
    expect(
      jsonDecode(
        await automationManager.buildCalendarBusyWindowsJson(database),
      ),
      isEmpty,
    );
  });
}
