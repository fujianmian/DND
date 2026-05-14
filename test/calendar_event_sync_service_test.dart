import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart';

import 'package:dnd_auto_app/database/database.dart';
import 'package:dnd_auto_app/services/calendar_event_sync_service.dart';

void main() {
  group('CalendarEventSyncService event conversion', () {
    test('converts timed events into simplified busy windows', () {
      final start = DateTime.utc(2026, 5, 11, 9);
      final end = DateTime.utc(2026, 5, 11, 10);
      final event = Event(
        id: 'raw-event-id',
        summary: 'Project Meeting',
        start: EventDateTime(dateTime: start),
        end: EventDateTime(dateTime: end),
      );

      final window = CalendarEventSyncService.eventToBusyWindow(
        event: event,
        triggerId: '42',
        calendarId: primaryCalendarId,
        includeAllDay: false,
        keyword: 'meeting',
        fetchedAtMillis: 123,
      );

      expect(window, isNotNull);
      expect(window!.triggerId, '42');
      expect(window.calendarId, primaryCalendarId);
      expect(window.eventIdHash, isNot('raw-event-id'));
      expect(window.startMillis, start.millisecondsSinceEpoch);
      expect(window.endMillis, end.millisecondsSinceEpoch);
      expect(window.isAllDay, isFalse);
      expect(window.keywordMatched, isTrue);
      expect(window.fetchedAt, 123);
    });

    test('detects all-day events and respects include-all-day', () {
      final localAllDayStart = DateTime(2026, 5, 12);
      final localAllDayEnd = DateTime(2026, 5, 13);
      final event = Event(
        id: 'all-day-event',
        summary: 'Exam day',
        start: EventDateTime(date: DateTime.utc(2026, 5, 12)),
        end: EventDateTime(date: DateTime.utc(2026, 5, 13)),
      );

      expect(CalendarEventSyncService.isAllDayEvent(event), isTrue);
      expect(
        CalendarEventSyncService.eventToBusyWindow(
          event: event,
          triggerId: '42',
          calendarId: primaryCalendarId,
          includeAllDay: false,
          keyword: null,
          fetchedAtMillis: 123,
        ),
        isNull,
      );

      final included = CalendarEventSyncService.eventToBusyWindow(
        event: event,
        triggerId: '42',
        calendarId: primaryCalendarId,
        includeAllDay: true,
        keyword: null,
        fetchedAtMillis: 123,
      );

      expect(included, isNotNull);
      expect(included!.isAllDay, isTrue);
      expect(included.startMillis, localAllDayStart.millisecondsSinceEpoch);
      expect(included.endMillis, localAllDayEnd.millisecondsSinceEpoch);
      expect(
        DateTime(2026, 5, 12, 12).millisecondsSinceEpoch,
        inInclusiveRange(included.startMillis, included.endMillis - 1),
      );
    });

    test(
      'includes transparent all-day events when include-all-day is enabled',
      () {
        final event = Event(
          id: 'transparent-all-day-event',
          summary: 'Exam day',
          transparency: 'transparent',
          start: EventDateTime(date: DateTime.utc(2026, 5, 13)),
          end: EventDateTime(date: DateTime.utc(2026, 5, 14)),
        );

        final included = CalendarEventSyncService.eventToBusyWindow(
          event: event,
          triggerId: '42',
          calendarId: primaryCalendarId,
          includeAllDay: true,
          keyword: null,
          fetchedAtMillis: 123,
        );

        expect(included, isNotNull);
        expect(included!.isAllDay, isTrue);
        expect(
          included.startMillis,
          DateTime(2026, 5, 13).millisecondsSinceEpoch,
        );
        expect(
          included.endMillis,
          DateTime(2026, 5, 14).millisecondsSinceEpoch,
        );
      },
    );

    test('still skips transparent timed events', () {
      final event = Event(
        id: 'transparent-timed-event',
        summary: 'Focus time',
        transparency: 'transparent',
        start: EventDateTime(dateTime: DateTime.utc(2026, 5, 13, 9)),
        end: EventDateTime(dateTime: DateTime.utc(2026, 5, 13, 10)),
      );

      expect(
        CalendarEventSyncService.eventToBusyWindow(
          event: event,
          triggerId: '42',
          calendarId: primaryCalendarId,
          includeAllDay: true,
          keyword: null,
          fetchedAtMillis: 123,
        ),
        isNull,
      );
    });

    test('matches title keywords without storing event title', () {
      final event = Event(
        id: 'keyword-event',
        summary: 'Final Exam Review',
        start: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 9)),
        end: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 10)),
      );

      expect(
        CalendarEventSyncService.eventMatchesKeyword(event, 'exam'),
        isTrue,
      );
      expect(
        CalendarEventSyncService.eventMatchesKeyword(event, 'class'),
        isFalse,
      );

      final window = CalendarEventSyncService.eventToBusyWindow(
        event: event,
        triggerId: '42',
        calendarId: primaryCalendarId,
        includeAllDay: false,
        keyword: 'exam',
        fetchedAtMillis: 123,
      );

      expect(window, isNotNull);
    });

    test('checks all-day event title keywords in memory only', () {
      final event = Event(
        id: 'keyword-all-day-event',
        summary: 'Final Exam Day',
        start: EventDateTime(date: DateTime.utc(2026, 5, 13)),
        end: EventDateTime(date: DateTime.utc(2026, 5, 14)),
      );

      final skipped = CalendarEventSyncService.eventToBusyWindow(
        event: event,
        triggerId: '42',
        calendarId: primaryCalendarId,
        includeAllDay: true,
        keyword: 'meeting',
        fetchedAtMillis: 123,
      );
      final included = CalendarEventSyncService.eventToBusyWindow(
        event: event,
        triggerId: '42',
        calendarId: primaryCalendarId,
        includeAllDay: true,
        keyword: 'exam',
        fetchedAtMillis: 123,
      );

      expect(skipped, isNull);
      expect(included, isNotNull);
      expect(included!.eventIdHash, isNot('keyword-all-day-event'));
    });

    test('skips cancelled, transparent, and malformed events', () {
      final cancelled = Event(
        status: 'cancelled',
        start: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 9)),
        end: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 10)),
      );
      final transparent = Event(
        transparency: 'transparent',
        start: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 9)),
        end: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 10)),
      );
      final malformed = Event(
        start: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 10)),
        end: EventDateTime(dateTime: DateTime.utc(2026, 5, 11, 9)),
      );

      for (final event in [cancelled, transparent, malformed]) {
        expect(
          CalendarEventSyncService.eventToBusyWindow(
            event: event,
            triggerId: '42',
            calendarId: primaryCalendarId,
            includeAllDay: true,
            keyword: null,
            fetchedAtMillis: 123,
          ),
          isNull,
        );
      }
    });
  });

  test('replaces cached windows for a trigger transactionally', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final service = CalendarEventSyncService(database: database);

    await database
        .into(database.calendarBusyWindowsCache)
        .insert(
          const CalendarBusyWindowDraft(
            triggerId: '42',
            calendarId: primaryCalendarId,
            eventIdHash: 'old',
            startMillis: 100,
            endMillis: 200,
            isAllDay: false,
            keywordMatched: true,
            fetchedAt: 50,
          ).toCompanion(),
        );

    await service.replaceCachedWindowsForTrigger(
      triggerId: '42',
      windows: const [
        CalendarBusyWindowDraft(
          triggerId: '42',
          calendarId: primaryCalendarId,
          eventIdHash: 'new-a',
          startMillis: 300,
          endMillis: 400,
          isAllDay: false,
          keywordMatched: true,
          fetchedAt: 250,
        ),
        CalendarBusyWindowDraft(
          triggerId: '42',
          calendarId: primaryCalendarId,
          eventIdHash: 'new-b',
          startMillis: 500,
          endMillis: 600,
          isAllDay: true,
          keywordMatched: true,
          fetchedAt: 250,
        ),
      ],
    );

    final rows = await database.select(database.calendarBusyWindowsCache).get();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.eventIdHash), containsAll(['new-a', 'new-b']));
    expect(rows.any((row) => row.eventIdHash == 'old'), isFalse);
  });
}
