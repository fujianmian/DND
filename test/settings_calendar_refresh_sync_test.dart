import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/screens/settings_screen.dart';
import 'package:dnd_auto_app/services/calendar_event_sync_service.dart';

void main() {
  test('successful calendar refresh triggers automation sync', () async {
    var syncCount = 0;
    final didSync = await syncAutomationAfterCalendarBusyWindowRefresh(
      result: CalendarEventSyncResult.success(
        triggerCount: 1,
        insertedCount: 1,
        skippedCount: 0,
        fetchedAt: DateTime(2026, 5, 18, 9),
      ),
      syncRulesToAndroid: () async {
        syncCount++;
      },
    );

    expect(didSync, isTrue);
    expect(syncCount, 1);
  });

  test(
    'failed calendar refresh does not sync stale cache to Android',
    () async {
      var syncCount = 0;
      final didSync = await syncAutomationAfterCalendarBusyWindowRefresh(
        result: CalendarEventSyncResult.failed('Calendar refresh failed.'),
        syncRulesToAndroid: () async {
          syncCount++;
        },
      );

      expect(didSync, isFalse);
      expect(syncCount, 0);
    },
  );

  test(
    'successful zero-window calendar refresh still re-evaluates automation',
    () async {
      var syncCount = 0;
      final didSync = await syncAutomationAfterCalendarBusyWindowRefresh(
        result: CalendarEventSyncResult.success(
          triggerCount: 1,
          insertedCount: 0,
          skippedCount: 1,
          fetchedAt: DateTime(2026, 5, 18, 10),
        ),
        syncRulesToAndroid: () async {
          syncCount++;
        },
      );

      expect(didSync, isTrue);
      expect(syncCount, 1);
    },
  );
}
