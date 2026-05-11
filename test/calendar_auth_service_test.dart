import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_auto_app/services/calendar_auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and clears lightweight calendar connection metadata', () async {
    final store = CalendarConnectionStore();

    expect((await store.read()).connected, isFalse);
    expect(await store.read().then((metadata) => metadata.email), isNull);

    await store.saveConnected('student@example.com');
    final connected = await store.read();

    expect(connected.connected, isTrue);
    expect(connected.email, 'student@example.com');
    expect(connected.lastAuthStatus, 'connected');

    await store.saveDisconnected(status: 'cancelled');
    final disconnected = await store.read();

    expect(disconnected.connected, isFalse);
    expect(disconnected.email, isNull);
    expect(disconnected.lastAuthStatus, 'cancelled');
  });
}
