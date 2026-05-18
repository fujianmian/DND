import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/models/rule_trigger_draft.dart';
import 'package:dnd_auto_app/utils/rule_edit_navigation.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('one trigger row still opens the multi-condition editor', () async {
    final entry = await _createRuleWithTriggerCount(database, 1);

    expect(entry.triggers, hasLength(1));
    expect(shouldUseMultiConditionEditor(entry), isTrue);
  });

  test('multiple trigger rows open the multi-condition editor', () async {
    final entry = await _createRuleWithTriggerCount(database, 2);

    expect(entry.triggers, hasLength(2));
    expect(shouldUseMultiConditionEditor(entry), isTrue);
  });

  test(
    'legacy rules without trigger rows keep the single-trigger fallback',
    () {
      final rule = Rule(
        id: 1,
        name: 'Legacy',
        type: RuleTriggerDraft.time,
        startTime: '09:00',
        endTime: '10:00',
        latitude: null,
        longitude: null,
        radius: null,
        savedLocationId: null,
        locationLabel: null,
        packageName: null,
        isEnabled: true,
        allowStarredContacts: false,
        allowRepeatCallers: false,
        activityType: null,
        timeRepeatMode: 0,
        timeRepeatDaysMask: 127,
        priority: rulePriorityTime,
        matchType: 0,
        profileId: null,
      );

      expect(
        shouldUseMultiConditionEditor(
          RuleWithTriggers(rule: rule, triggers: const []),
        ),
        isFalse,
      );
    },
  );
}

Future<RuleWithTriggers> _createRuleWithTriggerCount(
  AppDatabase database,
  int triggerCount,
) async {
  final drafts = [
    const RuleTriggerDraft(
      triggerType: RuleTriggerDraft.time,
      startTime: '09:00',
      endTime: '10:00',
    ),
    const RuleTriggerDraft(
      triggerType: RuleTriggerDraft.app,
      packageName: 'com.example.app',
    ),
  ].take(triggerCount).toList();

  final ruleId = await database.createRuleWithTriggers(
    rule: withFirstTriggerLegacyFields(
      RulesCompanion.insert(name: 'Focus', type: drafts.first.triggerType),
      drafts.first,
    ),
    triggers: drafts.map((draft) => draft.toCompanion()).toList(),
  );

  return (await database.getEnabledRulesWithTriggers()).singleWhere(
    (entry) => entry.rule.id == ruleId,
  );
}
