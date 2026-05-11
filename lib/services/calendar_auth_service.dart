import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';

const List<String> calendarAuthScopes = <String>[
  CalendarApi.calendarEventsReadonlyScope,
];

final CalendarAuthService calendarAuthService = CalendarAuthService();

class CalendarConnectionMetadata {
  const CalendarConnectionMetadata({
    required this.connected,
    this.email,
    this.lastAuthStatus,
  });

  final bool connected;
  final String? email;
  final String? lastAuthStatus;
}

class CalendarConnectResult {
  const CalendarConnectResult._({
    required this.connected,
    required this.cancelled,
    required this.message,
    this.email,
  });

  factory CalendarConnectResult.connected(String email) {
    return CalendarConnectResult._(
      connected: true,
      cancelled: false,
      email: email,
      message: 'Google Calendar connected.',
    );
  }

  factory CalendarConnectResult.cancelled() {
    return const CalendarConnectResult._(
      connected: false,
      cancelled: true,
      message: 'Google Calendar connection was cancelled.',
    );
  }

  factory CalendarConnectResult.failed(String message) {
    return CalendarConnectResult._(
      connected: false,
      cancelled: false,
      message: message,
    );
  }

  final bool connected;
  final bool cancelled;
  final String message;
  final String? email;
}

class CalendarConnectionStore {
  static const _connectedKey = 'calendarConnection.connected';
  static const _emailKey = 'calendarConnection.email';
  static const _lastAuthStatusKey = 'calendarConnection.lastAuthStatus';

  Future<CalendarConnectionMetadata> read() async {
    final prefs = await SharedPreferences.getInstance();
    return CalendarConnectionMetadata(
      connected: prefs.getBool(_connectedKey) ?? false,
      email: prefs.getString(_emailKey),
      lastAuthStatus: prefs.getString(_lastAuthStatusKey),
    );
  }

  Future<void> saveConnected(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, true);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_lastAuthStatusKey, 'connected');
  }

  Future<void> saveDisconnected({String status = 'disconnected'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, false);
    await prefs.remove(_emailKey);
    await prefs.setString(_lastAuthStatusKey, status);
  }
}

class CalendarAuthService {
  CalendarAuthService({
    CalendarConnectionStore? store,
    GoogleSignIn? googleSignIn,
  }) : _store = store ?? CalendarConnectionStore(),
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final CalendarConnectionStore _store;
  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  Future<bool> isConnected() async {
    return (await _store.read()).connected;
  }

  Future<String?> getConnectedAccountEmail() async {
    return (await _store.read()).email;
  }

  Future<CalendarConnectionMetadata> getConnectionMetadata() {
    return _store.read();
  }

  Future<CalendarConnectResult> connect() async {
    try {
      await _ensureInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        await _store.saveDisconnected(status: 'unsupported');
        return CalendarConnectResult.failed(
          'Google sign-in is not available on this device.',
        );
      }

      final account = await _googleSignIn.authenticate(
        scopeHint: calendarAuthScopes,
      );
      final authorization =
          await account.authorizationClient.authorizationForScopes(
            calendarAuthScopes,
          ) ??
          await account.authorizationClient.authorizeScopes(calendarAuthScopes);

      authorization.authClient(scopes: calendarAuthScopes).close();
      await _store.saveConnected(account.email);
      return CalendarConnectResult.connected(account.email);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        await _store.saveDisconnected(status: 'cancelled');
        return CalendarConnectResult.cancelled();
      }

      await _store.saveDisconnected(status: 'failed');
      return CalendarConnectResult.failed(_messageForGoogleSignInException(e));
    } catch (_) {
      await _store.saveDisconnected(status: 'failed');
      return CalendarConnectResult.failed(
        'Google Calendar could not be connected. Please try again.',
      );
    }
  }

  Future<void> disconnect() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.disconnect();
    } on GoogleSignInException {
      await _googleSignIn.signOut();
    } catch (_) {
      // Local metadata is still cleared below, even if Google revoke fails.
    } finally {
      await _store.saveDisconnected();
    }
  }

  Future<auth.AuthClient?> getAuthenticatedClient() async {
    try {
      await _ensureInitialized();
      final signInAttempt = _googleSignIn.attemptLightweightAuthentication(
        reportAllExceptions: true,
      );
      final account = signInAttempt == null ? null : await signInAttempt;
      if (account == null) {
        await _store.saveDisconnected(status: 'signed_out');
        return null;
      }

      final authorization = await account.authorizationClient
          .authorizationForScopes(calendarAuthScopes);
      if (authorization == null) {
        await _store.saveDisconnected(status: 'authorization_missing');
        return null;
      }

      await _store.saveConnected(account.email);
      return authorization.authClient(scopes: calendarAuthScopes);
    } catch (_) {
      await _store.saveDisconnected(status: 'auth_client_failed');
      return null;
    }
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _googleSignIn.initialize();
  }

  String _messageForGoogleSignInException(GoogleSignInException exception) {
    switch (exception.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Calendar sign-in is not configured yet.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in could not open on this device.';
      default:
        return 'Google Calendar could not be connected. Please try again.';
    }
  }
}
