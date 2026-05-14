import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart';

import '../database/database.dart';
import '../models/rule_trigger_draft.dart';
import 'calendar_auth_service.dart';

const int defaultCalendarLookaheadHours = 168;
const String primaryCalendarId = 'primary';

class CalendarEventSyncResult {
  const CalendarEventSyncResult._({
    required this.success,
    required this.status,
    required this.triggerCount,
    required this.insertedCount,
    required this.skippedCount,
    required this.message,
    this.fetchedAt,
  });

  factory CalendarEventSyncResult.success({
    required int triggerCount,
    required int insertedCount,
    required int skippedCount,
    required DateTime fetchedAt,
  }) {
    return CalendarEventSyncResult._(
      success: true,
      status: 'success',
      triggerCount: triggerCount,
      insertedCount: insertedCount,
      skippedCount: skippedCount,
      fetchedAt: fetchedAt,
      message: insertedCount == 1
          ? 'Cached 1 calendar window.'
          : 'Cached $insertedCount calendar windows.',
    );
  }

  factory CalendarEventSyncResult.noCalendarTriggers() {
    return const CalendarEventSyncResult._(
      success: true,
      status: 'no_calendar_triggers',
      triggerCount: 0,
      insertedCount: 0,
      skippedCount: 0,
      message: 'No Calendar triggers to sync yet.',
    );
  }

  factory CalendarEventSyncResult.notConnected() {
    return const CalendarEventSyncResult._(
      success: false,
      status: 'not_connected',
      triggerCount: 0,
      insertedCount: 0,
      skippedCount: 0,
      message: 'Google Calendar is not connected.',
    );
  }

  factory CalendarEventSyncResult.authUnavailable() {
    return const CalendarEventSyncResult._(
      success: false,
      status: 'auth_unavailable',
      triggerCount: 0,
      insertedCount: 0,
      skippedCount: 0,
      message: 'Google Calendar authorization is unavailable.',
    );
  }

  factory CalendarEventSyncResult.failed(String message) {
    return CalendarEventSyncResult._(
      success: false,
      status: 'failed',
      triggerCount: 0,
      insertedCount: 0,
      skippedCount: 0,
      message: message,
    );
  }

  final bool success;
  final String status;
  final int triggerCount;
  final int insertedCount;
  final int skippedCount;
  final String message;
  final DateTime? fetchedAt;
}

class CalendarBusyWindowDraft {
  const CalendarBusyWindowDraft({
    required this.triggerId,
    required this.startMillis,
    required this.endMillis,
    required this.isAllDay,
    required this.keywordMatched,
    required this.fetchedAt,
    this.eventIdHash,
    this.calendarId,
  });

  final String triggerId;
  final String? eventIdHash;
  final String? calendarId;
  final int startMillis;
  final int endMillis;
  final bool isAllDay;
  final bool keywordMatched;
  final int fetchedAt;

  CalendarBusyWindowsCacheCompanion toCompanion() {
    return CalendarBusyWindowsCacheCompanion.insert(
      triggerId: triggerId,
      eventIdHash: d.Value(eventIdHash),
      calendarId: d.Value(calendarId),
      startMillis: startMillis,
      endMillis: endMillis,
      isAllDay: d.Value(isAllDay),
      keywordMatched: d.Value(keywordMatched),
      fetchedAt: fetchedAt,
    );
  }
}

class CalendarEventSyncService {
  CalendarEventSyncService({
    required AppDatabase database,
    CalendarAuthService? authService,
    DateTime Function()? now,
  }) : _database = database,
       _authService = authService ?? calendarAuthService,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final CalendarAuthService _authService;
  final DateTime Function() _now;

  Future<CalendarEventSyncResult> syncAllCalendarTriggerBusyWindows() async {
    if (!await _authService.isConnected()) {
      return CalendarEventSyncResult.notConnected();
    }

    final triggers = await _loadCalendarTriggers();
    if (triggers.isEmpty) {
      return CalendarEventSyncResult.noCalendarTriggers();
    }

    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      return CalendarEventSyncResult.authUnavailable();
    }

    try {
      final api = CalendarApi(client);
      final fetchedAt = _now();
      final fetchedAtMillis = fetchedAt.millisecondsSinceEpoch;
      var insertedCount = 0;
      var skippedCount = 0;

      for (final trigger in triggers) {
        final syncResult = await _syncTrigger(
          api: api,
          trigger: trigger,
          fetchedAtMillis: fetchedAtMillis,
        );
        insertedCount += syncResult.insertedCount;
        skippedCount += syncResult.skippedCount;
      }

      return CalendarEventSyncResult.success(
        triggerCount: triggers.length,
        insertedCount: insertedCount,
        skippedCount: skippedCount,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return CalendarEventSyncResult.failed(
        'Calendar events could not be refreshed. Check your connection and try again.',
      );
    } finally {
      client.close();
    }
  }

  Future<void> replaceCachedWindowsForTrigger({
    required String triggerId,
    required List<CalendarBusyWindowDraft> windows,
  }) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.calendarBusyWindowsCache,
      )..where((row) => row.triggerId.equals(triggerId))).go();

      for (final window in windows) {
        await _database
            .into(_database.calendarBusyWindowsCache)
            .insert(window.toCompanion());
      }
    });
  }

  static CalendarBusyWindowDraft? eventToBusyWindow({
    required Event event,
    required String triggerId,
    required String calendarId,
    required bool includeAllDay,
    required String? keyword,
    required int fetchedAtMillis,
  }) {
    if (event.status == 'cancelled') {
      return null;
    }

    final start = event.start;
    final end = event.end;
    if (start == null || end == null) return null;

    final isAllDay = isAllDayEvent(event);
    if (isAllDay && !includeAllDay) return null;
    if (!isAllDay && event.transparency == 'transparent') return null;
    if (!eventMatchesKeyword(event, keyword)) return null;

    final startMillis = _eventDateTimeMillis(start, isAllDay: isAllDay);
    final endMillis = _eventDateTimeMillis(end, isAllDay: isAllDay);
    if (startMillis == null || endMillis == null) return null;
    if (endMillis <= startMillis) return null;

    return CalendarBusyWindowDraft(
      triggerId: triggerId,
      eventIdHash: stableEventIdHash(event.id),
      calendarId: calendarId,
      startMillis: startMillis,
      endMillis: endMillis,
      isAllDay: isAllDay,
      keywordMatched: keyword == null || keyword.trim().isNotEmpty,
      fetchedAt: fetchedAtMillis,
    );
  }

  static bool isAllDayEvent(Event event) {
    return event.start?.date != null && event.end?.date != null;
  }

  static bool eventMatchesKeyword(Event event, String? keyword) {
    final normalizedKeyword = keyword?.trim().toLowerCase();
    if (normalizedKeyword == null || normalizedKeyword.isEmpty) return true;
    return event.summary?.toLowerCase().contains(normalizedKeyword) ?? false;
  }

  static String? stableEventIdHash(String? eventId) {
    if (eventId == null || eventId.isEmpty) return null;

    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final codeUnit in eventId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<List<RuleTrigger>> _loadCalendarTriggers() async {
    final rules = await _database.getEnabledRulesWithTriggers();
    return [
      for (final rule in rules)
        for (final trigger in rule.triggers)
          if (trigger.enabled &&
              trigger.triggerType == RuleTriggerDraft.calendar)
            trigger,
    ];
  }

  Future<_TriggerSyncCounts> _syncTrigger({
    required CalendarApi api,
    required RuleTrigger trigger,
    required int fetchedAtMillis,
  }) async {
    final calendarId = _normalizeCalendarId(trigger.calendarId);
    final keyword = _normalizeKeyword(trigger.calendarKeyword);
    final includeAllDay = trigger.calendarIncludeAllDay;
    final lookaheadHours = _positiveOrDefault(
      trigger.calendarLookaheadHours,
      defaultCalendarLookaheadHours,
    );
    final now = _now();
    final timeMin = now.toUtc();
    final timeMax = now.add(Duration(hours: lookaheadHours)).toUtc();
    final triggerId = trigger.id.toString();
    final windows = <CalendarBusyWindowDraft>[];
    var skippedCount = 0;
    var fetchedEventCount = 0;
    var skippedAllDayBecauseDisabledCount = 0;
    String? pageToken;

    do {
      final events = await api.events.list(
        calendarId,
        timeMin: timeMin,
        timeMax: timeMax,
        singleEvents: true,
        orderBy: 'startTime',
        showDeleted: false,
        pageToken: pageToken,
        $fields:
            'items(id,status,summary,transparency,start,end),nextPageToken',
      );
      final fetchedEvents = events.items ?? const <Event>[];
      fetchedEventCount += fetchedEvents.length;
      for (final event in fetchedEvents) {
        final isAllDay = isAllDayEvent(event);
        if (isAllDay && !includeAllDay) {
          skippedAllDayBecauseDisabledCount++;
        }
        final window = eventToBusyWindow(
          event: event,
          triggerId: triggerId,
          calendarId: calendarId,
          includeAllDay: includeAllDay,
          keyword: keyword,
          fetchedAtMillis: fetchedAtMillis,
        );
        if (window == null) {
          skippedCount++;
        } else {
          windows.add(window);
          if (window.isAllDay) {
            _logAllDayWindowCached(window);
          }
        }
      }
      pageToken = events.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    _logTriggerSyncSummary(
      triggerId: triggerId,
      includeAllDay: includeAllDay,
      fetchedEventCount: fetchedEventCount,
      skippedAllDayBecauseDisabledCount: skippedAllDayBecauseDisabledCount,
      cachedAllDayWindowCount: windows
          .where((window) => window.isAllDay)
          .length,
    );

    await replaceCachedWindowsForTrigger(
      triggerId: triggerId,
      windows: windows,
    );
    return _TriggerSyncCounts(
      insertedCount: windows.length,
      skippedCount: skippedCount,
    );
  }

  static int? _eventDateTimeMillis(
    EventDateTime value, {
    required bool isAllDay,
  }) {
    if (isAllDay) {
      final date = value.date;
      if (date == null) return null;
      return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    }

    return value.dateTime?.toUtc().millisecondsSinceEpoch;
  }

  static String _normalizeCalendarId(String? calendarId) {
    final trimmed = calendarId?.trim();
    return trimmed == null || trimmed.isEmpty ? primaryCalendarId : trimmed;
  }

  static String? _normalizeKeyword(String? keyword) {
    final trimmed = keyword?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int _positiveOrDefault(int? value, int defaultValue) {
    return value == null || value <= 0 ? defaultValue : value;
  }

  static void _logTriggerSyncSummary({
    required String triggerId,
    required bool includeAllDay,
    required int fetchedEventCount,
    required int skippedAllDayBecauseDisabledCount,
    required int cachedAllDayWindowCount,
  }) {
    // Safe diagnostics only: no event titles, IDs, locations, or descriptions.
    debugPrint(
      '[CalendarSync] triggerId=$triggerId, includeAllDay=$includeAllDay, '
      'fetchedEvents=$fetchedEventCount, '
      'skippedAllDayBecauseIncludeFalse=$skippedAllDayBecauseDisabledCount, '
      'cachedAllDayWindows=$cachedAllDayWindowCount',
    );
  }

  static void _logAllDayWindowCached(CalendarBusyWindowDraft window) {
    // Safe diagnostics only: trigger ID plus derived window bounds.
    debugPrint(
      '[CalendarSync] cached all-day window: triggerId=${window.triggerId}, '
      'startMillis=${window.startMillis}, endMillis=${window.endMillis}',
    );
  }
}

class _TriggerSyncCounts {
  const _TriggerSyncCounts({
    required this.insertedCount,
    required this.skippedCount,
  });

  final int insertedCount;
  final int skippedCount;
}
