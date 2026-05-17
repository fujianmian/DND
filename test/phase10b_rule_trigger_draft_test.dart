import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/models/rule_trigger_draft.dart';
import 'package:dnd_auto_app/models/time_repeat.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('time repeat constants and masks are stable', () {
    expect(timeRepeatEveryDay, 0);
    expect(timeRepeatWeekdays, 1);
    expect(timeRepeatWeekends, 2);
    expect(timeRepeatCustom, 3);
    expect(timeRepeatMondayBit, 1);
    expect(timeRepeatTuesdayBit, 2);
    expect(timeRepeatWednesdayBit, 4);
    expect(timeRepeatThursdayBit, 8);
    expect(timeRepeatFridayBit, 16);
    expect(timeRepeatSaturdayBit, 32);
    expect(timeRepeatSundayBit, 64);
    expect(timeRepeatEveryDayMask, 127);
    expect(timeRepeatWeekdaysMask, 31);
    expect(timeRepeatWeekendsMask, 96);
  });

  test('normalizes time repeat modes and labels', () {
    expect(normalizeTimeRepeatMode(null), timeRepeatEveryDay);
    expect(normalizeTimeRepeatMode(99), timeRepeatEveryDay);
    expect(maskForRepeatMode(timeRepeatEveryDay), timeRepeatEveryDayMask);
    expect(maskForRepeatMode(timeRepeatWeekdays), timeRepeatWeekdaysMask);
    expect(maskForRepeatMode(timeRepeatWeekends), timeRepeatWeekendsMask);
    expect(maskForRepeatMode(timeRepeatCustom), 0);
    expect(repeatLabel(timeRepeatEveryDay), 'every day');
    expect(repeatLabel(timeRepeatWeekdays), 'weekdays');
    expect(repeatLabel(timeRepeatWeekends), 'weekends');
    expect(
      repeatLabel(
        timeRepeatCustom,
        daysMask:
            timeRepeatMondayBit | timeRepeatWednesdayBit | timeRepeatFridayBit,
      ),
      'Mon/Wed/Fri',
    );
  });

  test('validates rule name, match type, required fields, and duplicates', () {
    expect(
      validateRuleTriggerDrafts(
        ruleName: '',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
        ],
      ),
      'Enter a rule name.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 4,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
        ],
      ),
      'Please choose a match type.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [],
      ),
      'Please add at least one condition.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [RuleTriggerDraft(triggerType: -1)],
      ),
      'Condition 1: please choose a trigger type.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [RuleTriggerDraft(triggerType: RuleTriggerDraft.time)],
      ),
      'Condition 1: please select start and end times.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
            timeRepeatMode: 99,
          ),
        ],
      ),
      'Condition 1: please choose a valid repeat setting.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
            timeRepeatMode: timeRepeatCustom,
            timeRepeatDaysMask: 0,
          ),
        ],
      ),
      'Condition 1: please select at least one repeat day.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
            timeRepeatMode: timeRepeatCustom,
            timeRepeatDaysMask:
                timeRepeatMondayBit |
                timeRepeatWednesdayBit |
                timeRepeatFridayBit,
          ),
        ],
      ),
      isNull,
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(triggerType: RuleTriggerDraft.location),
        ],
      ),
      'Condition 1: please select a location and radius.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.139,
            longitude: 101.6869,
            radius: 25,
          ),
        ],
      ),
      'Condition 1: please select a radius of at least 50m.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [RuleTriggerDraft(triggerType: RuleTriggerDraft.app)],
      ),
      'Condition 1: please select an application.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(triggerType: RuleTriggerDraft.activity),
        ],
      ),
      'Condition 1: please select an activity.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.app,
            packageName: 'com.example.app',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.app,
            packageName: 'com.example.app',
          ),
        ],
      ),
      'Condition 2 duplicates an existing application.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.activity,
            activityType: 'WALKING',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.activity,
            activityType: 'WALKING',
          ),
        ],
      ),
      'Condition 2 duplicates an existing activity.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
        ],
      ),
      'Condition 2 duplicates an existing time range.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.139,
            longitude: 101.6869,
            radius: 100,
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.139,
            longitude: 101.6869,
            radius: 100,
          ),
        ],
      ),
      'Condition 2 duplicates an existing location.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Meeting Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(triggerType: RuleTriggerDraft.calendar),
        ],
      ),
      isNull,
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Meeting Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.calendar,
            calendarLookaheadHours: 0,
          ),
        ],
      ),
      'Condition 1: calendar lookahead hours must be positive.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Meeting Focus',
        matchType: 0,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.calendar,
            calendarId: ' primary ',
            calendarKeyword: ' Exam ',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.calendar,
            calendarId: 'primary',
            calendarKeyword: 'exam',
          ),
        ],
      ),
      'Condition 2 duplicates an existing calendar condition.',
    );

    expect(
      validateRuleTriggerDrafts(
        ruleName: 'Focus',
        matchType: 1,
        triggers: const [
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.time,
            startTime: '09:00',
            endTime: '17:00',
          ),
          RuleTriggerDraft(
            triggerType: RuleTriggerDraft.location,
            latitude: 3.139,
            longitude: 101.6869,
            radius: 100,
          ),
        ],
      ),
      isNull,
    );
  });

  test('converts a draft into trigger and first-trigger legacy values', () {
    const draft = RuleTriggerDraft(
      triggerType: RuleTriggerDraft.app,
      startTime: '09:00',
      endTime: '17:00',
      packageName: ' com.example.app ',
    );

    final trigger = draft.toCompanion(ruleId: 42);
    final rule = withFirstTriggerLegacyFields(
      RulesCompanion.insert(
        name: 'App Rule',
        type: 0,
        matchType: const d.Value(1),
      ),
      draft,
    );

    expect(trigger.ruleId.value, 42);
    expect(trigger.triggerType.value, RuleTriggerDraft.app);
    expect(trigger.packageName.value, 'com.example.app');
    expect(trigger.startTime.value, isNull);
    expect(rule.type.value, RuleTriggerDraft.app);
    expect(rule.packageName.value, 'com.example.app');
    expect(rule.startTime.value, isNull);
    expect(rule.endTime.value, isNull);
  });

  test('location draft preserves saved location snapshot values', () {
    const draft = RuleTriggerDraft(
      triggerType: RuleTriggerDraft.location,
      latitude: 3.139,
      longitude: 101.6869,
      radius: 150,
      savedLocationId: 12,
      locationLabel: ' Library ',
    );

    final trigger = draft.toCompanion(ruleId: 42);
    final rule = withFirstTriggerLegacyFields(
      RulesCompanion.insert(name: 'Library Rule', type: 0),
      draft,
    );

    expect(trigger.ruleId.value, 42);
    expect(trigger.triggerType.value, RuleTriggerDraft.location);
    expect(trigger.latitude.value, 3.139);
    expect(trigger.longitude.value, 101.6869);
    expect(trigger.radius.value, 150);
    expect(trigger.savedLocationId.value, 12);
    expect(trigger.locationLabel.value, 'Library');
    expect(rule.type.value, RuleTriggerDraft.location);
    expect(rule.latitude.value, 3.139);
    expect(rule.longitude.value, 101.6869);
    expect(rule.radius.value, 150);
    expect(rule.savedLocationId.value, 12);
    expect(rule.locationLabel.value, 'Library');
  });

  test(
    'time draft defaults and custom repeat values persist to companions',
    () {
      const defaultDraft = RuleTriggerDraft(
        triggerType: RuleTriggerDraft.time,
        startTime: '09:00',
        endTime: '17:00',
      );
      final defaultTrigger = defaultDraft.toCompanion(ruleId: 7);

      expect(defaultDraft.timeRepeatMode, timeRepeatEveryDay);
      expect(defaultDraft.timeRepeatDaysMask, timeRepeatEveryDayMask);
      expect(defaultTrigger.timeRepeatMode.value, timeRepeatEveryDay);
      expect(defaultTrigger.timeRepeatDaysMask.value, timeRepeatEveryDayMask);

      const customMask =
          timeRepeatMondayBit | timeRepeatWednesdayBit | timeRepeatFridayBit;
      const customDraft = RuleTriggerDraft(
        triggerType: RuleTriggerDraft.time,
        startTime: '08:00',
        endTime: '12:00',
        timeRepeatMode: timeRepeatCustom,
        timeRepeatDaysMask: customMask,
      );
      final customTrigger = customDraft.toCompanion(ruleId: 8);
      final customRule = withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Custom Time', type: 0),
        customDraft,
      );

      expect(customTrigger.timeRepeatMode.value, timeRepeatCustom);
      expect(customTrigger.timeRepeatDaysMask.value, customMask);
      expect(customRule.timeRepeatMode.value, timeRepeatCustom);
      expect(customRule.timeRepeatDaysMask.value, customMask);
    },
  );

  test('converts a calendar draft into trigger values', () {
    const draft = RuleTriggerDraft(
      triggerType: RuleTriggerDraft.calendar,
      calendarId: ' primary ',
      calendarKeyword: ' exam ',
      calendarIncludeAllDay: true,
      calendarLookaheadHours: 72,
    );

    final trigger = draft.toCompanion(ruleId: 42);
    final rule = withFirstTriggerLegacyFields(
      RulesCompanion.insert(name: 'Calendar Rule', type: 0),
      draft,
    );

    expect(trigger.ruleId.value, 42);
    expect(trigger.triggerType.value, RuleTriggerDraft.calendar);
    expect(trigger.calendarId.value, 'primary');
    expect(trigger.calendarKeyword.value, 'exam');
    expect(trigger.calendarIncludeAllDay.value, isTrue);
    expect(trigger.calendarLookaheadHours.value, 72);
    expect(trigger.startTime.value, isNull);
    expect(trigger.packageName.value, isNull);
    expect(rule.type.value, RuleTriggerDraft.calendar);
    expect(rule.startTime.value, isNull);
    expect(rule.packageName.value, isNull);
    expect(rule.activityType.value, isNull);
  });

  test('converts existing RuleTrigger and legacy Rule into drafts', () async {
    final ruleId = await database.createSingleTriggerRule(
      RulesCompanion.insert(
        name: 'Legacy Time',
        type: RuleTriggerDraft.time,
        startTime: const d.Value('09:00'),
        endTime: const d.Value('17:00'),
      ),
    );
    final rule = await _rule(database, ruleId);
    final trigger = (await database.getRuleTriggers(ruleId)).single;

    final fromTrigger = RuleTriggerDraft.fromRuleTrigger(trigger);
    final fromLegacy = RuleTriggerDraft.fromLegacyRule(rule);

    expect(fromTrigger.triggerType, RuleTriggerDraft.time);
    expect(fromTrigger.startTime, '09:00');
    expect(fromTrigger.endTime, '17:00');
    expect(fromTrigger.timeRepeatMode, timeRepeatEveryDay);
    expect(fromTrigger.timeRepeatDaysMask, timeRepeatEveryDayMask);
    expect(fromTrigger.enabled, isTrue);
    expect(fromLegacy.triggerType, RuleTriggerDraft.time);
    expect(fromLegacy.startTime, '09:00');
    expect(fromLegacy.endTime, '17:00');
    expect(fromLegacy.timeRepeatMode, timeRepeatEveryDay);
    expect(fromLegacy.timeRepeatDaysMask, timeRepeatEveryDayMask);
  });

  test(
    'converts existing saved location RuleTrigger and legacy Rule into drafts',
    () async {
      const draft = RuleTriggerDraft(
        triggerType: RuleTriggerDraft.location,
        latitude: 3.139,
        longitude: 101.6869,
        radius: 150,
        savedLocationId: 12,
        locationLabel: 'Library',
      );
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Library', type: 1),
          draft,
        ),
        triggers: [draft.toCompanion()],
      );
      final rule = await _rule(database, ruleId);
      final trigger = (await database.getRuleTriggers(ruleId)).single;

      final fromTrigger = RuleTriggerDraft.fromRuleTrigger(trigger);
      final fromLegacy = RuleTriggerDraft.fromLegacyRule(rule);

      expect(fromTrigger.triggerType, RuleTriggerDraft.location);
      expect(fromTrigger.latitude, 3.139);
      expect(fromTrigger.longitude, 101.6869);
      expect(fromTrigger.radius, 150);
      expect(fromTrigger.savedLocationId, 12);
      expect(fromTrigger.locationLabel, 'Library');
      expect(fromLegacy.triggerType, RuleTriggerDraft.location);
      expect(fromLegacy.latitude, 3.139);
      expect(fromLegacy.longitude, 101.6869);
      expect(fromLegacy.radius, 150);
      expect(fromLegacy.savedLocationId, 12);
      expect(fromLegacy.locationLabel, 'Library');
    },
  );

  test(
    'converts existing custom repeat RuleTrigger and legacy Rule into drafts',
    () async {
      const customMask =
          timeRepeatMondayBit | timeRepeatWednesdayBit | timeRepeatFridayBit;
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Custom Time', type: 0),
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
      final rule = await _rule(database, ruleId);
      final trigger = (await database.getRuleTriggers(ruleId)).single;

      final fromTrigger = RuleTriggerDraft.fromRuleTrigger(trigger);
      final fromLegacy = RuleTriggerDraft.fromLegacyRule(rule);

      expect(rule.timeRepeatMode, timeRepeatCustom);
      expect(rule.timeRepeatDaysMask, customMask);
      expect(trigger.timeRepeatMode, timeRepeatCustom);
      expect(trigger.timeRepeatDaysMask, customMask);
      expect(fromTrigger.timeRepeatMode, timeRepeatCustom);
      expect(fromTrigger.timeRepeatDaysMask, customMask);
      expect(fromLegacy.timeRepeatMode, timeRepeatCustom);
      expect(fromLegacy.timeRepeatDaysMask, customMask);
    },
  );

  test(
    'createSingleTriggerRule mirrors repeat fields into RuleTriggers',
    () async {
      const customMask = timeRepeatTuesdayBit | timeRepeatThursdayBit;
      final ruleId = await database.createSingleTriggerRule(
        RulesCompanion.insert(
          name: 'Single Custom',
          type: RuleTriggerDraft.time,
          startTime: const d.Value('10:00'),
          endTime: const d.Value('14:00'),
          timeRepeatMode: const d.Value(timeRepeatCustom),
          timeRepeatDaysMask: const d.Value(customMask),
        ),
      );

      final rule = await _rule(database, ruleId);
      final trigger = (await database.getRuleTriggers(ruleId)).single;

      expect(rule.timeRepeatMode, timeRepeatCustom);
      expect(rule.timeRepeatDaysMask, customMask);
      expect(trigger.timeRepeatMode, timeRepeatCustom);
      expect(trigger.timeRepeatDaysMask, customMask);
    },
  );

  test('converts existing calendar RuleTrigger into a draft', () async {
    final ruleId = await database.createRuleWithTriggers(
      rule: withFirstTriggerLegacyFields(
        RulesCompanion.insert(name: 'Meetings', type: 0),
        const RuleTriggerDraft(
          triggerType: RuleTriggerDraft.calendar,
          calendarId: 'primary',
          calendarKeyword: 'meeting',
          calendarIncludeAllDay: true,
          calendarLookaheadHours: 168,
        ),
      ),
      triggers: const [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.calendar,
          calendarId: 'primary',
          calendarKeyword: 'meeting',
          calendarIncludeAllDay: true,
          calendarLookaheadHours: 168,
        ),
      ].map((draft) => draft.toCompanion()).toList(),
    );

    final rule = await _rule(database, ruleId);
    final trigger = (await database.getRuleTriggers(ruleId)).single;
    final fromTrigger = RuleTriggerDraft.fromRuleTrigger(trigger);
    final fromLegacy = RuleTriggerDraft.fromLegacyRule(rule);

    expect(rule.type, RuleTriggerDraft.calendar);
    expect(fromTrigger.triggerType, RuleTriggerDraft.calendar);
    expect(fromTrigger.calendarId, 'primary');
    expect(fromTrigger.calendarKeyword, 'meeting');
    expect(fromTrigger.calendarIncludeAllDay, isTrue);
    expect(fromTrigger.calendarLookaheadHours, 168);
    expect(fromLegacy.triggerType, RuleTriggerDraft.calendar);
    expect(fromLegacy.calendarId, isNull);
    expect(fromLegacy.calendarIncludeAllDay, isFalse);
  });

  test(
    'creates a rule with multiple triggers and mirrored first legacy fields',
    () async {
      const drafts = [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.location,
          latitude: 3.139,
          longitude: 101.6869,
          radius: 125,
          savedLocationId: 9,
          locationLabel: 'Campus Library',
        ),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.app,
          packageName: 'com.example.study',
        ),
      ];

      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'Campus Study',
            type: 0,
            matchType: const d.Value(1),
            allowStarredContacts: const d.Value(true),
          ),
          drafts.first,
        ),
        triggers: drafts.map((draft) => draft.toCompanion()).toList(),
      );

      final rule = await _rule(database, ruleId);
      final triggers = await database.getRuleTriggers(ruleId);

      expect(rule.matchType, 1);
      expect(rule.allowStarredContacts, isFalse);
      expect(rule.type, RuleTriggerDraft.location);
      expect(rule.latitude, 3.139);
      expect(rule.longitude, 101.6869);
      expect(rule.radius, 125);
      expect(rule.savedLocationId, 9);
      expect(rule.locationLabel, 'Campus Library');
      expect(rule.packageName, isNull);
      expect(triggers, hasLength(2));
      expect(triggers.first.ruleId, ruleId);
      expect(triggers.first.triggerType, RuleTriggerDraft.location);
      expect(triggers.first.savedLocationId, 9);
      expect(triggers.first.locationLabel, 'Campus Library');
      expect(triggers.last.packageName, 'com.example.study');
    },
  );

  test(
    'creates a three-condition ALL rule with cleared exception flags and legacy mirror',
    () async {
      const drafts = [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.time,
          startTime: '09:00',
          endTime: '17:00',
        ),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.app,
          packageName: 'com.example.study',
        ),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.activity,
          activityType: 'WALKING',
        ),
      ];

      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(
            name: 'Deep Work',
            type: 0,
            matchType: const d.Value(1),
            allowStarredContacts: const d.Value(true),
            allowRepeatCallers: const d.Value(true),
          ),
          drafts.first,
        ),
        triggers: drafts.map((draft) => draft.toCompanion()).toList(),
      );

      final rule = await _rule(database, ruleId);
      final triggers = await database.getRuleTriggers(ruleId);

      expect(rule.matchType, 1);
      expect(rule.allowStarredContacts, isFalse);
      expect(rule.allowRepeatCallers, isFalse);
      expect(rule.type, RuleTriggerDraft.time);
      expect(rule.startTime, '09:00');
      expect(rule.endTime, '17:00');
      expect(rule.packageName, isNull);
      expect(triggers, hasLength(3));
      expect(triggers.map((trigger) => trigger.triggerType), [
        RuleTriggerDraft.time,
        RuleTriggerDraft.app,
        RuleTriggerDraft.activity,
      ]);
    },
  );

  test(
    'updates a rule by replacing trigger rows without duplication',
    () async {
      final ruleId = await database.createRuleWithTriggers(
        rule: withFirstTriggerLegacyFields(
          RulesCompanion.insert(name: 'Original', type: 0),
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
        ].map((draft) => draft.toCompanion()).toList(),
      );

      const updatedDrafts = [
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.activity,
          activityType: 'WALKING',
        ),
        RuleTriggerDraft(
          triggerType: RuleTriggerDraft.app,
          packageName: 'com.example.walk',
        ),
      ];

      await database.updateRuleWithTriggers(
        ruleId: ruleId,
        rule: withFirstTriggerLegacyFields(
          const RulesCompanion(
            name: d.Value('Updated'),
            matchType: d.Value(0),
            allowRepeatCallers: d.Value(true),
          ),
          updatedDrafts.first,
        ),
        triggers: updatedDrafts.map((draft) => draft.toCompanion()).toList(),
      );

      final rule = await _rule(database, ruleId);
      final triggers = await database.getRuleTriggers(ruleId);

      expect(rule.name, 'Updated');
      expect(rule.matchType, 0);
      expect(rule.allowRepeatCallers, isFalse);
      expect(rule.type, RuleTriggerDraft.activity);
      expect(rule.activityType, 'WALKING');
      expect(rule.startTime, isNull);
      expect(triggers, hasLength(2));
      expect(triggers.first.triggerType, RuleTriggerDraft.activity);
      expect(triggers.last.packageName, 'com.example.walk');
    },
  );
}

Future<Rule> _rule(AppDatabase database, int id) {
  return (database.select(
    database.rules,
  )..where((rule) => rule.id.equals(id))).getSingle();
}
