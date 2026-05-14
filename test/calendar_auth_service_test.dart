import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_auto_app/services/calendar_auth_service.dart';
import 'package:dnd_auto_app/services/dnd_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DndService.platform, (call) async {
          if (call.method != 'getAppDebugInfo') return null;
          return <String, Object?>{
            'packageName': 'com.example.dnd_auto_app',
            'applicationId': 'com.example.dnd_auto_app',
            'appLabel': 'Quietly',
            'androidSdkInt': 35,
            'internetPermissionDeclared': true,
            'defaultWebClientIdResourcePresent': false,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DndService.platform, null);
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

  test('resolves Calendar serverClientId from dart-define before dotenv', () {
    final serverClientId = resolveCalendarGoogleSignInServerClientId(
      dartDefineValue:
          ' 1083909303996-tve26ijo9i99e5gnrv8abs117qu7muti.apps.googleusercontent.com ',
      dotenvValues: const <String, String>{
        googleServerClientIdEnvironmentKey:
            'dotenv-web.apps.googleusercontent.com',
      },
    );

    expect(
      serverClientId,
      '1083909303996-tve26ijo9i99e5gnrv8abs117qu7muti.apps.googleusercontent.com',
    );
  });

  test('resolves Calendar serverClientId from dotenv fallback', () {
    final serverClientId = resolveCalendarGoogleSignInServerClientId(
      dartDefineValue: ' ',
      dotenvValues: const <String, String>{
        googleServerClientIdEnvironmentKey:
            'dotenv-web.apps.googleusercontent.com',
      },
    );

    expect(serverClientId, 'dotenv-web.apps.googleusercontent.com');
  });

  test('masks Calendar serverClientId in debug output', () {
    expect(
      maskCalendarGoogleSignInServerClientId(
        '1083909303996-tve26ijo9i99e5gnrv8abs117qu7muti.apps.googleusercontent.com',
      ),
      '108390...usercontent.com',
    );
  });

  test('masks Google client IDs embedded in debug text', () {
    expect(
      maskCalendarGoogleClientIdsInDebugText(
        'serverClientId=1083909303996-tve26ijo9i99e5gnrv8abs117qu7muti.apps.googleusercontent.com',
      ),
      'serverClientId=108390...usercontent.com',
    );
  });

  test(
    'connect returns app-side error when Web client ID is missing',
    () async {
      final service = CalendarAuthService(serverClientIdProvider: () => null);

      final result = await service.connect();
      final metadata = await service.getConnectionMetadata();

      expect(result.connected, isFalse);
      expect(result.cancelled, isFalse);
      expect(
        result.message,
        'Google Calendar sign in is missing a Web Client ID.',
      );
      expect(metadata.connected, isFalse);
      expect(metadata.lastAuthStatus, 'configuration_missing');
    },
  );
}
