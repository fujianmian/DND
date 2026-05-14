import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/services/dnd_service.dart';

void main() {
  group('AutomationPauseState.fromPlatformMap', () {
    test('uses safe defaults for null or missing fields', () {
      final state = AutomationPauseState.fromPlatformMap(null);

      expect(state.automationPaused, isFalse);
      expect(state.pauseUntilMillis, 0);
      expect(state.pausedAtMillis, 0);
      expect(state.pauseReason, 'manual');
      expect(state.isIndefinite, isFalse);
      expect(state.isExpired, isFalse);
      expect(state.pauseUntil, isNull);
      expect(state.pausedAt, isNull);
    });

    test('parses indefinite pause', () {
      final state = AutomationPauseState.fromPlatformMap({
        'automationPaused': true,
        'pauseUntilMillis': 0,
        'pausedAtMillis': 1778700000000,
        'pauseReason': 'manual',
      });

      expect(state.automationPaused, isTrue);
      expect(state.isIndefinite, isTrue);
      expect(state.isExpired, isFalse);
      expect(state.pauseUntil, isNull);
      expect(
        state.pausedAt,
        DateTime.fromMillisecondsSinceEpoch(1778700000000),
      );
    });

    test('parses fixed duration pause', () {
      final pauseUntil = DateTime.now()
          .add(const Duration(minutes: 15))
          .millisecondsSinceEpoch;
      final state = AutomationPauseState.fromPlatformMap({
        'automationPaused': true,
        'pauseUntilMillis': pauseUntil,
        'pausedAtMillis': pauseUntil - 30000,
        'pauseReason': 'manual',
      });

      expect(state.automationPaused, isTrue);
      expect(state.isIndefinite, isFalse);
      expect(state.isExpired, isFalse);
      expect(state.pauseUntil, DateTime.fromMillisecondsSinceEpoch(pauseUntil));
    });

    test('reports expired fixed duration pause', () {
      final state = AutomationPauseState.fromPlatformMap({
        'automationPaused': true,
        'pauseUntilMillis': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
        'pausedAtMillis': 1778700000000,
      });

      expect(state.isExpired, isTrue);
    });
  });
}
