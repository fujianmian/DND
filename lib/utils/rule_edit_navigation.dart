import '../database/database.dart';

bool shouldUseMultiConditionEditor(RuleWithTriggers entry) {
  return entry.triggers.isNotEmpty;
}
