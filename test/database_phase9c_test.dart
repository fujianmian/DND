import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/models/rule_trigger_draft.dart';
import 'package:dnd_auto_app/models/rule_trigger_summary.dart';
import 'package:dnd_auto_app/models/time_repeat.dart';

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

  test('creates updates archives and watches saved locations', () async {
    const createdAt = 1760000000000;
    final locationId = await database.createSavedLocation(
      SavedLocationsCompanion.insert(
        name: 'Library',
        latitude: 3.139,
        longitude: 101.6869,
        radius: 150,
        address: const d.Value('Campus Level 2'),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    var location = await database.getSavedLocation(locationId);
    expect(location, isNotNull);
    expect(location!.name, 'Library');
    expect(location.latitude, 3.139);
    expect(location.longitude, 101.6869);
    expect(location.radius, 150);
    expect(location.address, 'Campus Level 2');
    expect(location.isArchived, isFalse);
    expect(await database.watchActiveSavedLocations().first, hasLength(1));

    await database.updateSavedLocation(
      location.copyWith(
        name: 'Main Library',
        radius: 200,
        address: const d.Value('Campus Level 3'),
        updatedAt: createdAt + 1,
      ),
    );
    location = await database.getSavedLocation(locationId);
    expect(location!.name, 'Main Library');
    expect(location.radius, 200);
    expect(location.address, 'Campus Level 3');

    await database.archiveSavedLocation(locationId, updatedAt: createdAt + 2);

    location = await database.getSavedLocation(locationId);
    expect(location!.isArchived, isTrue);
    expect(location.updatedAt, createdAt + 2);
    expect(await database.getAllSavedLocations(), isEmpty);
    expect(
      await database.getAllSavedLocations(includeArchived: true),
      hasLength(1),
    );
    expect(await database.watchActiveSavedLocations().first, isEmpty);
  });

  test('saved location edits refresh referencing rule snapshots', () async {
    const createdAt = 1760000000000;
    final locationId = await database.createSavedLocation(
      SavedLocationsCompanion.insert(
        name: 'Home',
        latitude: 3.139,
        longitude: 101.6869,
        radius: 150,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final ruleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Home Focus', type: 1),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.location,
          latitude: 3.139,
          longitude: 101.6869,
          radius: 150,
          savedLocationId: locationId,
          locationLabel: 'Home',
        ),
      ),
      triggers: [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.location,
          latitude: 3.139,
          longitude: 101.6869,
          radius: 150,
          savedLocationId: locationId,
          locationLabel: 'Home',
        ).toCompanion(),
      ],
    );

    final location = await database.getSavedLocation(locationId);
    await database.updateSavedLocation(
      location!.copyWith(
        name: 'Stadium',
        latitude: 3.1612,
        longitude: 101.7123,
        radius: 250,
        updatedAt: createdAt + 1,
      ),
    );

    final rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    final trigger = (await database.getRuleTriggers(ruleId)).single;

    expect(rule.savedLocationId, locationId);
    expect(rule.locationLabel, 'Stadium');
    expect(rule.latitude, 3.1612);
    expect(rule.longitude, 101.7123);
    expect(rule.radius, 250);

    expect(trigger.savedLocationId, locationId);
    expect(trigger.locationLabel, 'Stadium');
    expect(trigger.latitude, 3.1612);
    expect(trigger.longitude, 101.7123);
    expect(trigger.radius, 250);
  });

  test('validates saved location name and radius', () async {
    const createdAt = 1760000000000;

    expect(
      () => database.createSavedLocation(
        SavedLocationsCompanion.insert(
          name: '   ',
          latitude: 3.139,
          longitude: 101.6869,
          radius: 150,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ),
      throwsArgumentError,
    );

    expect(
      () => database.createSavedLocation(
        SavedLocationsCompanion.insert(
          name: 'Library',
          latitude: 3.139,
          longitude: 101.6869,
          radius: 25,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ),
      throwsArgumentError,
    );

    final locationId = await database.createSavedLocation(
      SavedLocationsCompanion.insert(
        name: '  Library  ',
        latitude: 3.139,
        longitude: 101.6869,
        radius: 50,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final location = await database.getSavedLocation(locationId);
    expect(location!.name, 'Library');
    expect(location.radius, 50);
    expect(location.address, isNull);
  });

  test('creates updates enables disables and watches profiles', () async {
    const createdAt = 1760000000000;

    expect(validateProfileName('   '), 'Profile name is required');
    expect(validateProfileName('  Work  '), isNull);
    expect(
      () => database.createProfile(
        ProfilesCompanion.insert(
          name: '   ',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ),
      throwsArgumentError,
    );

    final profileId = await database.createProfile(
      ProfilesCompanion.insert(
        name: '  Work  ',
        description: const d.Value('Office hours'),
        allowStarredContacts: const d.Value(true),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    var profile = await database.getProfile(profileId);
    expect(profile, isNotNull);
    expect(profile!.name, 'Work');
    expect(profile.description, 'Office hours');
    expect(profile.isEnabled, isTrue);
    expect(profile.allowStarredContacts, isFalse);
    expect(profile.allowRepeatCallers, isFalse);
    expect(profile.isArchived, isFalse);

    await database.updateProfile(
      profile.copyWith(
        name: '  Deep Work  ',
        description: const d.Value('Focus block'),
        allowRepeatCallers: true,
        updatedAt: createdAt + 1,
      ),
    );
    profile = await database.getProfile(profileId);
    expect(profile!.name, 'Deep Work');
    expect(profile.description, 'Focus block');
    expect(profile.allowStarredContacts, isFalse);
    expect(profile.allowRepeatCallers, isFalse);

    await database.setProfileEnabled(
      profileId,
      false,
      updatedAt: createdAt + 2,
    );
    profile = await database.getProfile(profileId);
    expect(profile!.isEnabled, isFalse);
    expect(profile.updatedAt, createdAt + 2);

    await database.setProfileEnabled(profileId, true, updatedAt: createdAt + 3);
    profile = await database.getProfile(profileId);
    expect(profile!.isEnabled, isTrue);
    expect(profile.updatedAt, createdAt + 3);

    final archivedProfileId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Gaming',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await database.archiveProfile(archivedProfileId, updatedAt: createdAt + 4);

    final activeProfiles = await database.watchActiveProfiles().first;
    expect(activeProfiles.map((profile) => profile.id), [profileId]);

    final allProfiles = await database
        .watchProfiles(includeArchived: true)
        .first;
    expect(
      allProfiles.map((profile) => profile.id),
      contains(archivedProfileId),
    );
    expect(
      allProfiles
          .singleWhere((profile) => profile.id == archivedProfileId)
          .isArchived,
      isTrue,
    );
  });

  test('assigns unassigns and counts rules for profiles', () async {
    const createdAt = 1760000000000;
    final profileId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Library',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    final workProfileId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Work',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final firstRuleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Quiet Study',
        type: 0,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('11:00'),
      ),
    );
    final secondRuleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Unprofiled',
        type: 0,
        startTime: const d.Value('12:00'),
        endTime: const d.Value('13:00'),
      ),
    );
    final profiledRuleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Profiled at create',
        type: 0,
        profileId: d.Value(profileId),
        startTime: const d.Value('14:00'),
        endTime: const d.Value('15:00'),
      ),
    );

    final initialRule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(firstRuleId))).getSingle();
    expect(initialRule.profileId, isNull);
    final createdProfiledRule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(profiledRuleId))).getSingle();
    expect(createdProfiledRule.profileId, profileId);

    await database.assignRuleToProfile(firstRuleId, profileId);

    final profileRules = await database.getRulesForProfile(profileId);
    expect(profileRules.map((entry) => entry.rule.id), [
      firstRuleId,
      profiledRuleId,
    ]);
    expect(profileRules.first.triggers, hasLength(1));
    final watchedProfileRules = await database
        .watchRulesForProfile(profileId)
        .first;
    expect(watchedProfileRules.map((entry) => entry.rule.id), [
      firstRuleId,
      profiledRuleId,
    ]);

    final unprofiledRules = await database.getRulesForProfile(null);
    expect(unprofiledRules.map((entry) => entry.rule.id), [secondRuleId]);
    var standaloneRules = await database
        .watchStandaloneRulesWithTriggers()
        .first;
    expect(standaloneRules.map((entry) => entry.rule.id), [secondRuleId]);
    expect(await database.countRulesForProfile(profileId), 2);

    final profilesWithCounts = await database
        .watchProfilesWithRuleCounts()
        .first;
    expect(profilesWithCounts, hasLength(2));
    expect(
      profilesWithCounts
          .singleWhere((entry) => entry.profile.id == profileId)
          .ruleCount,
      2,
    );

    await database.assignRuleToProfile(firstRuleId, null);

    final unassignedRule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(firstRuleId))).getSingle();
    expect(unassignedRule.profileId, isNull);
    expect(await database.countRulesForProfile(profileId), 1);
    standaloneRules = await database.watchStandaloneRulesWithTriggers().first;
    expect(standaloneRules.map((entry) => entry.rule.id), [
      firstRuleId,
      secondRuleId,
    ]);

    final draft = const RuleTriggerDraft(
      triggerType: RuleTriggerDraft.time,
      startTime: '14:00',
      endTime: '15:00',
    );
    await database.updateRuleWithTriggers(
      ruleId: profiledRuleId,
      rule: withFirstTriggerLegacyFields(
        const RulesCompanion().copyWith(
          name: const d.Value('Profiled at update'),
          profileId: d.Value<int?>(workProfileId),
        ),
        draft,
      ),
      triggers: [draft.toCompanion()],
    );

    var editedRule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(profiledRuleId))).getSingle();
    expect(editedRule.profileId, workProfileId);
    expect(await database.countRulesForProfile(profileId), 0);
    expect(await database.countRulesForProfile(workProfileId), 1);

    await database.updateRuleWithTriggers(
      ruleId: profiledRuleId,
      rule: withFirstTriggerLegacyFields(
        const RulesCompanion().copyWith(
          name: const d.Value('Unassigned at update'),
          profileId: const d.Value<int?>(null),
        ),
        draft,
      ),
      triggers: [draft.toCompanion()],
    );

    editedRule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(profiledRuleId))).getSingle();
    expect(editedRule.profileId, isNull);
    expect(await database.countRulesForProfile(workProfileId), 0);
    standaloneRules = await database.watchStandaloneRulesWithTriggers().first;
    expect(standaloneRules.map((entry) => entry.rule.id), [
      firstRuleId,
      secondRuleId,
      profiledRuleId,
    ]);
  });

  test(
    'archiving a profile unassigns rules without changing enabled state',
    () async {
      const createdAt = 1760000000000;
      final profileId = await database.createProfile(
        ProfilesCompanion.insert(
          name: 'Sleep',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final enabledRuleId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Bedtime',
          type: 0,
          startTime: const d.Value('22:00'),
          endTime: const d.Value('07:00'),
        ),
      );
      final disabledRuleId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Nap',
          type: 0,
          isEnabled: const d.Value(false),
          startTime: const d.Value('14:00'),
          endTime: const d.Value('15:00'),
        ),
      );

      await database.assignRuleToProfile(enabledRuleId, profileId);
      await database.assignRuleToProfile(disabledRuleId, profileId);

      await database.archiveProfile(profileId, updatedAt: createdAt + 1);

      final profile = await database.getProfile(profileId);
      expect(profile!.isArchived, isTrue);
      expect(profile.updatedAt, createdAt + 1);

      final rules = await database.select(database.rules).get();
      final enabledRule = rules.singleWhere((rule) => rule.id == enabledRuleId);
      final disabledRule = rules.singleWhere(
        (rule) => rule.id == disabledRuleId,
      );
      expect(enabledRule.profileId, isNull);
      expect(disabledRule.profileId, isNull);
      expect(enabledRule.isEnabled, isTrue);
      expect(disabledRule.isEnabled, isFalse);
      expect(await database.countRulesForProfile(profileId), 0);
      final standaloneRules = await database
          .watchStandaloneRulesWithTriggers()
          .first;
      expect(
        standaloneRules.map((entry) => entry.rule.id),
        containsAll([enabledRuleId, disabledRuleId]),
      );
    },
  );

  test('profile rule enabled switch updates the contained rule only', () async {
    const createdAt = 1760000000000;
    final profileId = await database.createProfile(
      ProfilesCompanion.insert(
        name: 'Library',
        isEnabled: const d.Value(false),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Study',
        type: 0,
        profileId: d.Value(profileId),
        startTime: const d.Value('09:00'),
        endTime: const d.Value('10:00'),
      ),
    );

    var rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    expect(rule.isEnabled, isTrue);
    expect(rule.profileId, profileId);

    await database.updateRule(rule.copyWith(isEnabled: false));
    rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    expect(rule.isEnabled, isFalse);
    expect(rule.profileId, profileId);

    await database.updateRule(rule.copyWith(isEnabled: true));
    rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    final profile = await database.getProfile(profileId);
    expect(profile!.isEnabled, isFalse);
    expect(rule.isEnabled, isTrue);
    expect(rule.profileId, profileId);
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
      'Time: 09:00-17:00, every day',
    );
  });

  test('formats time repeat summaries', () async {
    final weekdaysId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Workday', type: 0),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '17:00',
          timeRepeatMode: timeRepeatWeekdays,
          timeRepeatDaysMask: timeRepeatWeekdaysMask,
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '17:00',
          timeRepeatMode: timeRepeatWeekdays,
          timeRepeatDaysMask: timeRepeatWeekdaysMask,
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );
    final weekendsId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Weekend', type: 0),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '22:00',
          endTime: '06:00',
          timeRepeatMode: timeRepeatWeekends,
          timeRepeatDaysMask: timeRepeatWeekendsMask,
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '22:00',
          endTime: '06:00',
          timeRepeatMode: timeRepeatWeekends,
          timeRepeatDaysMask: timeRepeatWeekendsMask,
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );
    const customMask =
        timeRepeatMondayBit | timeRepeatWednesdayBit | timeRepeatFridayBit;
    final customId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Custom', type: 0),
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

    final weekdaysTrigger = (await database.getRuleTriggers(weekdaysId)).single;
    final weekendsTrigger = (await database.getRuleTriggers(weekendsId)).single;
    final customTrigger = (await database.getRuleTriggers(customId)).single;

    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        weekdaysTrigger,
        appLabelFor: (_) => 'Example App',
      ),
      'Time: 09:00-17:00, weekdays',
    );
    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        weekendsTrigger,
        appLabelFor: (_) => 'Example App',
      ),
      'Time: 22:00-06:00, weekends',
    );
    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        customTrigger,
        appLabelFor: (_) => 'Example App',
      ),
      'Time: 08:00-12:00, Mon/Wed/Fri',
    );
  });

  test('formats location summary with location label snapshot', () async {
    final ruleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Library Focus', type: 1),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.location,
          latitude: 3.139,
          longitude: 101.6869,
          radius: 150,
          savedLocationId: 7,
          locationLabel: ' Library ',
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.location,
          latitude: 3.139,
          longitude: 101.6869,
          radius: 150,
          savedLocationId: 7,
          locationLabel: ' Library ',
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );

    final rule = await (database.select(
      database.rules,
    )..where((rule) => rule.id.equals(ruleId))).getSingle();
    final trigger = (await database.getRuleTriggers(ruleId)).single;

    expect(
      RuleTriggerSummaryFormatter.triggerSummary(
        trigger,
        appLabelFor: (_) => 'Example App',
      ),
      'Location: Library, 150m',
    );
    expect(
      RuleTriggerSummaryFormatter.legacyRuleSummary(
        rule,
        appLabelFor: (_) => 'Example App',
      ),
      'Location: Library, 150m',
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
