import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
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

  test(
    'dual-write keeps one trigger row for each single-trigger rule type',
    () async {
      final timeId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Work Hours',
          type: 0,
          startTime: const d.Value('09:00'),
          endTime: const d.Value('17:00'),
        ),
      );
      final locationId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Campus',
          type: 1,
          latitude: const d.Value(3.139),
          longitude: const d.Value(101.6869),
          radius: const d.Value(100),
        ),
      );
      final appId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Study App',
          type: 2,
          packageName: const d.Value('com.example.study'),
        ),
      );
      final activityId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Walking',
          type: 3,
          activityType: const d.Value('WALKING'),
        ),
      );

      expect(await database.select(database.rules).get(), hasLength(4));
      expect(await database.select(database.ruleTriggers).get(), hasLength(4));

      await database.updateSingleTriggerRule(
        (await _rule(database, timeId)).copyWith(
          startTime: const d.Value('10:15'),
          endTime: const d.Value('18:30'),
        ),
      );
      await database.updateSingleTriggerRule(
        (await _rule(database, locationId)).copyWith(
          latitude: const d.Value(3.15),
          longitude: const d.Value(101.7),
          radius: const d.Value(250),
        ),
      );
      await database.updateSingleTriggerRule(
        (await _rule(
          database,
          appId,
        )).copyWith(packageName: const d.Value('com.example.updated')),
      );
      await database.updateSingleTriggerRule(
        (await _rule(
          database,
          activityId,
        )).copyWith(activityType: const d.Value('RUNNING')),
      );

      expect(await database.select(database.ruleTriggers).get(), hasLength(4));
      expect(
        (await database.getRuleTriggers(timeId)).single.startTime,
        '10:15',
      );
      expect((await database.getRuleTriggers(locationId)).single.radius, 250.0);
      expect(
        (await database.getRuleTriggers(appId)).single.packageName,
        'com.example.updated',
      );
      expect(
        (await database.getRuleTriggers(activityId)).single.activityType,
        'RUNNING',
      );

      for (final id in [timeId, locationId, appId, activityId]) {
        await database.deleteRuleAndTriggers(id);
        expect(await database.getRuleTriggers(id), isEmpty);
      }
      expect(await database.select(database.rules).get(), isEmpty);
      expect(await database.select(database.ruleTriggers).get(), isEmpty);
    },
  );

  test(
    'backfill remains idempotent across repeated startup-style calls',
    () async {
      final ruleId = await database.insertRule(
        RulesCompanion.insert(
          name: 'Legacy Location',
          type: 1,
          latitude: const d.Value(3.139),
          longitude: const d.Value(101.6869),
          radius: const d.Value(150),
        ),
      );

      await database.backfillLegacyRuleTriggers();
      await database.backfillLegacyRuleTriggers();
      await database.backfillLegacyRuleTriggers();

      final triggers = await database.getRuleTriggers(ruleId);

      expect(triggers, hasLength(1));
      expect(triggers.single.triggerType, 1);
      expect(triggers.single.latitude, 3.139);
      expect(triggers.single.longitude, 101.6869);
      expect(triggers.single.radius, 150.0);
    },
  );

  test(
    'sync payload preserves single-trigger values and suppresses exception flags',
    () async {
      final timeId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Work Hours',
          type: 0,
          startTime: const d.Value('09:05'),
          endTime: const d.Value('17:45'),
          allowStarredContacts: const d.Value(true),
        ),
      );
      final locationId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Campus',
          type: 1,
          latitude: const d.Value(3.139),
          longitude: const d.Value(101.6869),
          radius: const d.Value(125),
          allowRepeatCallers: const d.Value(true),
        ),
      );
      final appId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Study App',
          type: 2,
          packageName: const d.Value('com.example.study'),
          allowStarredContacts: const d.Value(true),
          allowRepeatCallers: const d.Value(true),
        ),
      );
      final activityId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Walking',
          type: 3,
          activityType: const d.Value('WALKING'),
        ),
      );

      final payload = automationManager.buildSyncPayloadFromRuleTriggers(
        await database.getEnabledRulesWithTriggers(),
      );

      expect(payload.enabledRuleCount, 4);
      expect(payload.enabledTriggerCount, 4);
      expect(payload.legacyFallbackCount, 0);

      expect(payload.timeRules.single['id'], timeId.toString());
      expect(payload.timeRules.single['name'], 'Work Hours');
      expect(payload.timeRules.single['startHour'], 9);
      expect(payload.timeRules.single['startMinute'], 5);
      expect(payload.timeRules.single['endHour'], 17);
      expect(payload.timeRules.single['endMinute'], 45);
      expect(payload.timeRules.single['allowStarredContacts'], isFalse);

      expect(payload.locationRules.single['id'], locationId.toString());
      expect(payload.locationRules.single['name'], 'Campus');
      expect(payload.locationRules.single['lat'], 3.139);
      expect(payload.locationRules.single['lng'], 101.6869);
      expect(payload.locationRules.single['rad'], 125);
      expect(payload.locationRules.single['allowRepeatCallers'], isFalse);

      expect(payload.appRules.single['id'], appId.toString());
      expect(payload.appRules.single['name'], 'Study App');
      expect(payload.appRules.single['packageName'], 'com.example.study');
      expect(payload.appRules.single['allowStarredContacts'], isFalse);
      expect(payload.appRules.single['allowRepeatCallers'], isFalse);

      expect(payload.activityRules.single['id'], activityId.toString());
      expect(payload.activityRules.single['name'], 'Walking');
      expect(payload.activityRules.single['activityType'], 'WALKING');
    },
  );

  test(
    'multi-trigger rules are flattened without enforcing matchType',
    () async {
      final ruleId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Temporary Multi',
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

      final payload = automationManager.buildSyncPayloadFromRuleTriggers(
        await database.getEnabledRulesWithTriggers(),
      );

      expect(payload.flattenedMultiTriggerRuleCount, 1);
      expect(payload.timeRules, hasLength(1));
      expect(payload.appRules, hasLength(1));
      expect(payload.timeRules.single['id'], ruleId.toString());
      expect(payload.appRules.single['id'], ruleId.toString());
    },
  );
}

Future<Rule> _rule(AppDatabase database, int id) {
  return (database.select(
    database.rules,
  )..where((rule) => rule.id.equals(id))).getSingle();
}
