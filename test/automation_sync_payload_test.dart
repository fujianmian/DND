import 'dart:convert';

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/models/rule_trigger_draft.dart';
import 'package:dnd_auto_app/models/time_repeat.dart';
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
    expect(payload.timeRules.single['timeRepeatMode'], timeRepeatEveryDay);
    expect(
      payload.timeRules.single['timeRepeatDaysMask'],
      timeRepeatEveryDayMask,
    );
    expect(payload.timeRules.single['allowStarredContacts'], isFalse);
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
    expect(groupedRule['allowStarredContacts'], isFalse);
    expect(groupedRule['allowRepeatCallers'], isFalse);

    final triggers = groupedRule['triggers'] as List;
    final trigger = triggers.single as Map<String, dynamic>;
    expect(trigger['triggerType'], 0);
    expect(trigger['enabled'], isTrue);
    expect(trigger['startHour'], 9);
    expect(trigger['startMinute'], 0);
    expect(trigger['endHour'], 17);
    expect(trigger['endMinute'], 0);
    expect(trigger['timeRepeatMode'], timeRepeatEveryDay);
    expect(trigger['timeRepeatDaysMask'], timeRepeatEveryDayMask);
  });

  test('builds single-trigger activity payload from RuleTriggers', () async {
    final ruleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(
          name: 'Driving',
          type: RuleTriggerDraft.activity,
          allowRepeatCallers: const d.Value(true),
        ),
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
      ].map((draft) => draft.toCompanion()).toList(),
    );

    final savedTriggers = await database.getRuleTriggers(ruleId);
    expect(savedTriggers, hasLength(1));
    expect(savedTriggers.single.triggerType, RuleTriggerDraft.activity);
    expect(savedTriggers.single.activityType, 'IN_VEHICLE');
    expect(savedTriggers.single.enabled, isTrue);

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.activityRules, hasLength(1));
    expect(payload.activityRules.single['id'], ruleId.toString());
    expect(payload.activityRules.single['name'], 'Driving');
    expect(payload.activityRules.single['activityType'], 'IN_VEHICLE');
    expect(
      payload.activityRules.single['confidenceThreshold'],
      defaultActivityConfidenceThreshold,
    );
    expect(payload.activityRules.single['allowRepeatCallers'], isFalse);
    expect(payload.legacyFallbackCount, 0);
    expect(payload.groupedRuleCount, 1);
    expect(payload.groupedTriggerCount, 1);

    final groupedRules = jsonDecode(payload.automationRulesJson) as List;
    final groupedRule = groupedRules.single as Map<String, dynamic>;
    expect(groupedRule['id'], ruleId.toString());
    expect(groupedRule['name'], 'Driving');
    expect(groupedRule['allowRepeatCallers'], isFalse);

    final trigger = (groupedRule['triggers'] as List).single as Map;
    expect(trigger['triggerType'], RuleTriggerDraft.activity);
    expect(trigger['activityType'], 'IN_VEHICLE');
    expect(trigger['confidenceThreshold'], defaultActivityConfidenceThreshold);
    expect(trigger['enabled'], isTrue);
  });

  test(
    'serializes custom time repeat settings in grouped and flat payloads',
    () async {
      const customMask =
          timeRepeatMondayBit | timeRepeatWednesdayBit | timeRepeatFridayBit;
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Custom Focus', type: 0),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '08:00',
            endTime: '12:00',
            timeRepeatMode: timeRepeatCustom,
            timeRepeatDaysMask: customMask,
          ),
        ),
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '08:00',
            endTime: '12:00',
            timeRepeatMode: timeRepeatCustom,
            timeRepeatDaysMask: customMask,
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );

      final payload = automationManager.buildSyncPayloadFromRuleTriggers(
        await database.getEnabledRulesWithTriggers(),
      );

      expect(payload.timeRules, hasLength(1));
      expect(payload.timeRules.single['id'], ruleId.toString());
      expect(payload.timeRules.single['timeRepeatMode'], timeRepeatCustom);
      expect(payload.timeRules.single['timeRepeatDaysMask'], customMask);

      final groupedRules = jsonDecode(payload.automationRulesJson) as List;
      final trigger =
          ((groupedRules.single as Map<String, dynamic>)['triggers'] as List)
                  .single
              as Map<String, dynamic>;
      expect(trigger['timeRepeatMode'], timeRepeatCustom);
      expect(trigger['timeRepeatDaysMask'], customMask);
    },
  );

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
    expect(payload.appRules.single['allowRepeatCallers'], isFalse);
    expect(payload.legacyFallbackCount, 1);
    expect(payload.groupedRuleCount, 0);
    expect(payload.groupedTriggerCount, 0);
    expect(jsonDecode(payload.automationRulesJson), isEmpty);
  });

  test('legacy time fallback defaults repeat settings to every day', () async {
    await database.insertRule(
      RulesCompanion.insert(
        name: 'Legacy Time',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );

    final payload = automationManager.buildSyncPayloadFromRuleTriggers(
      await database.getEnabledRulesWithTriggers(),
    );

    expect(payload.timeRules, hasLength(1));
    expect(payload.timeRules.single['timeRepeatMode'], timeRepeatEveryDay);
    expect(
      payload.timeRules.single['timeRepeatDaysMask'],
      timeRepeatEveryDayMask,
    );
    expect(payload.legacyFallbackCount, 1);
    expect(jsonDecode(payload.automationRulesJson), isEmpty);
  });

  test(
    'profile-aware sync includes unprofiled and enabled-profile rules',
    () async {
      const createdAt = 1760000000000;
      final profileId = await database.createProfile(
        ProfilesCompanion.insert(
          name: 'Library',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      final unprofiledRuleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Unprofiled Focus', type: 0),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '10:00',
          ),
        ),
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '10:00',
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );
      final profiledRuleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'Library Focus',
            type: 0,
            profileId: d.Value(profileId),
          ),
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

      final payload = automationManager
          .buildProfileAwareSyncPayloadFromRuleTriggers(
            await database.getEnabledRulesWithTriggers(),
            await database.watchProfiles(includeArchived: true).first,
          );

      expect(
        payload.timeRules.map((rule) => rule['id']),
        containsAll([unprofiledRuleId.toString(), profiledRuleId.toString()]),
      );
      expect(payload.groupedRuleCount, 2);
    },
  );

  test('profile-aware sync skips rules in disabled profiles', () async {
    const createdAt = 1760000000000;
    final profileId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Sleep',
        isEnabled: const d.Value(false),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(
          name: 'Disabled Profile Rule',
          type: 0,
          profileId: d.Value(profileId),
        ),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '22:00',
          endTime: '07:00',
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '22:00',
          endTime: '07:00',
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );

    final payload = automationManager
        .buildProfileAwareSyncPayloadFromRuleTriggers(
          await database.getEnabledRulesWithTriggers(),
          await database.watchProfiles(includeArchived: true).first,
        );

    expect(payload.timeRules, isEmpty);
    expect(payload.groupedRuleCount, 0);
    expect(jsonDecode(payload.automationRulesJson), isEmpty);
  });

  test(
    'profile-aware sync skips rules in archived or missing profiles',
    () async {
      const createdAt = 1760000000000;
      final archivedProfileId = await database.createProfile(
        ProfilesCompanion.insert(
          name: 'Archived',
          isArchived: const d.Value(true),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'Archived Profile Rule',
            type: 0,
            profileId: d.Value(archivedProfileId),
          ),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '10:00',
          ),
        ),
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '10:00',
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );
      await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'Missing Profile Rule',
            type: 0,
            profileId: const d.Value(999),
          ),
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

      final payload = automationManager
          .buildProfileAwareSyncPayloadFromRuleTriggers(
            await database.getEnabledRulesWithTriggers(),
            await database.watchProfiles(includeArchived: true).first,
          );

      expect(payload.timeRules, isEmpty);
      expect(payload.groupedRuleCount, 0);
    },
  );

  test('profile-aware sync suppresses stored exception flags', () async {
    const createdAt = 1760000000000;
    final profileStarredId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Starred Profile',
        allowStarredContacts: const d.Value(true),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    final profilePlainId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Plain Profile',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    final profileRepeatId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Repeat Profile',
        allowRepeatCallers: const d.Value(true),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final profileStarredRuleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(
          name: 'Profile Starred',
          type: 0,
          profileId: d.Value(profileStarredId),
        ),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '10:00',
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '10:00',
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );
    final ruleStarredRuleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(
          name: 'Rule Starred',
          type: 0,
          profileId: d.Value(profilePlainId),
          allowStarredContacts: const d.Value(true),
        ),
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
    final bothFalseRuleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(
          name: 'Both False',
          type: 0,
          profileId: d.Value(profilePlainId),
        ),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '11:00',
          endTime: '12:00',
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '11:00',
          endTime: '12:00',
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );
    final profileRepeatLegacyId = await database.insertRule(
      RulesCompanion.insert(
        name: 'Legacy Repeat Merge',
        type: 2,
        profileId: d.Value(profileRepeatId),
        packageName: const d.Value('com.example.repeat'),
      ),
    );

    final payload = automationManager
        .buildProfileAwareSyncPayloadFromRuleTriggers(
          await database.getEnabledRulesWithTriggers(),
          await database.watchProfiles(includeArchived: true).first,
        );
    final flatById = {
      for (final rule in [...payload.timeRules, ...payload.appRules])
        rule['id'] as String: rule,
    };

    expect(
      flatById[profileStarredRuleId.toString()]!['allowStarredContacts'],
      isFalse,
    );
    expect(
      flatById[ruleStarredRuleId.toString()]!['allowStarredContacts'],
      isFalse,
    );
    expect(
      flatById[bothFalseRuleId.toString()]!['allowStarredContacts'],
      isFalse,
    );
    expect(
      flatById[profileRepeatLegacyId.toString()]!['allowRepeatCallers'],
      isFalse,
    );
    expect(payload.legacyFallbackCount, 1);

    final groupedRules = jsonDecode(payload.automationRulesJson) as List;
    final groupedById = {
      for (final rule in groupedRules.cast<Map<String, dynamic>>())
        rule['id'] as String: rule,
    };
    expect(
      groupedById[profileStarredRuleId.toString()]!['allowStarredContacts'],
      isFalse,
    );
    expect(
      groupedById[ruleStarredRuleId.toString()]!['allowStarredContacts'],
      isFalse,
    );
    expect(
      groupedById[bothFalseRuleId.toString()]!['allowStarredContacts'],
      isFalse,
    );
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
    expect(payload.appRules.single['allowStarredContacts'], isFalse);
    expect(payload.appRules.single['allowRepeatCallers'], isFalse);
  });

  test(
    'location payload remains coordinate based with saved location metadata',
    () async {
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Library Focus', type: 1),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.139,
            longitude: 101.6869,
            radius: 150,
            savedLocationId: 12,
            locationLabel: 'Library',
          ),
        ),
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.139,
            longitude: 101.6869,
            radius: 150,
            savedLocationId: 12,
            locationLabel: 'Library',
          ),
        ].map((draft) => draft.toCompanion()).toList(),
      );

      final payload = automationManager.buildSyncPayloadFromRuleTriggers(
        await database.getEnabledRulesWithTriggers(),
      );

      expect(payload.locationRules, hasLength(1));
      expect(payload.locationRules.single['id'], ruleId.toString());
      expect(payload.locationRules.single['lat'], 3.139);
      expect(payload.locationRules.single['lng'], 101.6869);
      expect(payload.locationRules.single['rad'], 150);
      expect(
        payload.locationRules.single.containsKey('savedLocationId'),
        isFalse,
      );
      expect(
        payload.locationRules.single.containsKey('locationLabel'),
        isFalse,
      );

      final groupedRules = jsonDecode(payload.automationRulesJson) as List;
      final trigger =
          ((groupedRules.single as Map<String, dynamic>)['triggers'] as List)
                  .single
              as Map<String, dynamic>;
      expect(trigger['latitude'], 3.139);
      expect(trigger['longitude'], 101.6869);
      expect(trigger['radius'], 150);
      expect(trigger.containsKey('savedLocationId'), isFalse);
      expect(trigger.containsKey('locationLabel'), isFalse);
    },
  );

  test('keeps three-condition ALL rule out of flat fallback payload', () async {
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

    expect(payload.flattenedMultiTriggerRuleCount, 0);
    expect(payload.timeRules, isEmpty);
    expect(payload.appRules, isEmpty);
    expect(payload.activityRules, isEmpty);
    expect(payload.groupedRuleCount, 1);
    expect(payload.groupedTriggerCount, 3);
    expect(payload.skippedInvalidGroupedTriggerCount, 0);

    final groupedRules = jsonDecode(payload.automationRulesJson) as List;
    final groupedRule = groupedRules.single as Map<String, dynamic>;
    expect(groupedRule['id'], ruleId.toString());
    expect(groupedRule['name'], 'All Saved');
    expect(groupedRule['matchType'], 1);
    expect(groupedRule['priority'], 70);
    expect(groupedRule['allowStarredContacts'], isFalse);

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
  });

  test(
    'does not partially sync invalid ALL rule as grouped or flat fallback',
    () async {
      await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'Invalid All',
            type: 0,
            matchType: const d.Value(1),
            startTime: const d.Value('09:00'),
            endTime: const d.Value('17:00'),
          ),
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
        ),
        triggers: [
          const RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ).toCompanion(),
          RuleTriggersCompanion.insert(ruleId: 0, triggerType: 2),
        ],
      );

      final payload = automationManager.buildSyncPayloadFromRuleTriggers(
        await database.getEnabledRulesWithTriggers(),
      );

      expect(payload.flattenedMultiTriggerRuleCount, 0);
      expect(payload.timeRules, isEmpty);
      expect(payload.appRules, isEmpty);
      expect(payload.groupedRuleCount, 0);
      expect(payload.groupedTriggerCount, 0);
      expect(payload.skippedInvalidGroupedTriggerCount, 1);
      expect(jsonDecode(payload.automationRulesJson), isEmpty);
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

  test(
    'calendar busy windows payload includes all-day cached windows',
    () async {
      final triggerId = await database
          .createRuleWithTriggers(
            rule: withFirstTriggerLegacyFields(
              RulesCompanion.insert(name: 'Exam Day', type: 4),
              const RuleTriggerDraft(
                triggerType: RuleTriggerDraft.calendar,
                calendarIncludeAllDay: true,
              ),
            ),
            triggers: const [
              RuleTriggerDraft(
                triggerType: RuleTriggerDraft.calendar,
                calendarIncludeAllDay: true,
              ),
            ].map((draft) => draft.toCompanion()).toList(),
          )
          .then((ruleId) async {
            final ruleWithTriggers = await database
                .getEnabledRulesWithTriggers();
            return ruleWithTriggers
                .singleWhere((entry) => entry.rule.id == ruleId)
                .triggers
                .single
                .id
                .toString();
          });

      await database
          .into(database.calendarBusyWindowsCache)
          .insert(
            CalendarBusyWindowsCacheCompanion.insert(
              triggerId: triggerId,
              eventIdHash: const d.Value('hashed-only'),
              calendarId: const d.Value('primary'),
              startMillis: DateTime(2026, 5, 13).millisecondsSinceEpoch,
              endMillis: DateTime(2026, 5, 14).millisecondsSinceEpoch,
              isAllDay: const d.Value(true),
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
      expect(window['triggerId'], triggerId);
      expect(window['isAllDay'], isTrue);
      expect(
        window['startMillis'],
        DateTime(2026, 5, 13).millisecondsSinceEpoch,
      );
      expect(window['endMillis'], DateTime(2026, 5, 14).millisecondsSinceEpoch);
      expect(window.containsKey('eventIdHash'), isFalse);
      expect(window.containsKey('title'), isFalse);
    },
  );

  test('empty calendar busy window cache serializes as empty array', () async {
    expect(
      jsonDecode(
        await automationManager.buildCalendarBusyWindowsJson(database),
      ),
      isEmpty,
    );
  });
}
