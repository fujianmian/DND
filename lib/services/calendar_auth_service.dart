import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';

import 'dnd_service.dart';

const List<String> calendarAuthScopes = <String>[
  CalendarApi.calendarEventsReadonlyScope,
];

const String? _calendarGoogleSignInClientId = null;
const String googleServerClientIdEnvironmentKey = 'GOOGLE_SERVER_CLIENT_ID';
const String _calendarGoogleSignInServerClientIdFromDefine =
    String.fromEnvironment(googleServerClientIdEnvironmentKey);
const String _missingWebClientIdMessage =
    'Google Calendar sign in is missing a Web Client ID.';

final CalendarAuthService calendarAuthService = CalendarAuthService();

@visibleForTesting
String? resolveCalendarGoogleSignInServerClientId({
  String dartDefineValue = _calendarGoogleSignInServerClientIdFromDefine,
  Map<String, String>? dotenvValues,
}) {
  return _nonBlank(dartDefineValue) ??
      _nonBlank(dotenvValues?[googleServerClientIdEnvironmentKey]);
}

@visibleForTesting
String maskCalendarGoogleSignInServerClientId(String? value) {
  final configuredValue = _nonBlank(value);
  if (configuredValue == null) return 'none';

  const visiblePrefixLength = 6;
  const visibleSuffix = 'usercontent.com';
  if (configuredValue.length <= visiblePrefixLength + visibleSuffix.length) {
    return 'configured';
  }

  return '${configuredValue.substring(0, visiblePrefixLength)}...'
      '$visibleSuffix';
}

@visibleForTesting
String maskCalendarGoogleClientIdsInDebugText(String value) {
  return value.replaceAllMapped(
    RegExp(r'[A-Za-z0-9_-]+\.apps\.googleusercontent\.com'),
    (match) => maskCalendarGoogleSignInServerClientId(match.group(0)),
  );
}

String? get _calendarGoogleSignInServerClientId {
  final dotenvValues = dotenv.isInitialized ? dotenv.env : null;
  return resolveCalendarGoogleSignInServerClientId(dotenvValues: dotenvValues);
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

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

class CalendarAuthDebugConfigurationInfo {
  const CalendarAuthDebugConfigurationInfo({
    required this.buildMode,
    required this.scopes,
    required this.dartClientIdConfigured,
    required this.dartServerClientIdConfigured,
    required this.dartServerClientIdMasked,
    required this.usesGoogleSignInInstance,
    required this.initializationStarted,
    required this.metadata,
    this.androidPackageName,
    this.androidApplicationId,
    this.androidAppLabel,
    this.androidSdkInt,
    this.internetPermissionDeclared,
    this.defaultWebClientIdResourcePresent,
    this.platformDiagnosticsError,
  });

  final String buildMode;
  final List<String> scopes;
  final bool dartClientIdConfigured;
  final bool dartServerClientIdConfigured;
  final String dartServerClientIdMasked;
  final bool usesGoogleSignInInstance;
  final bool initializationStarted;
  final CalendarConnectionMetadata metadata;
  final String? androidPackageName;
  final String? androidApplicationId;
  final String? androidAppLabel;
  final int? androidSdkInt;
  final bool? internetPermissionDeclared;
  final bool? defaultWebClientIdResourcePresent;
  final String? platformDiagnosticsError;

  Map<String, String> toDebugMap() {
    return <String, String>{
      'Build mode': buildMode,
      'Android package name': androidPackageName ?? 'unknown',
      'Android applicationId': androidApplicationId ?? 'unknown',
      'Android app label': androidAppLabel ?? 'unknown',
      'Android SDK': androidSdkInt?.toString() ?? 'unknown',
      'INTERNET permission declared':
          internetPermissionDeclared?.toString() ?? 'unknown',
      'Calendar scopes': scopes.join(', '),
      'Dart clientId configured': dartClientIdConfigured.toString(),
      'Dart serverClientId configured': dartServerClientIdConfigured.toString(),
      'Dart serverClientId': dartServerClientIdMasked,
      'default_web_client_id resource present':
          defaultWebClientIdResourcePresent?.toString() ?? 'unknown',
      'Using GoogleSignIn.instance': usesGoogleSignInInstance.toString(),
      'GoogleSignIn initialization started': initializationStarted.toString(),
      'Stored connected': metadata.connected.toString(),
      'Stored email': metadata.email ?? 'none',
      'Stored last auth status': metadata.lastAuthStatus ?? 'none',
      'Platform diagnostics error': platformDiagnosticsError ?? 'none',
    };
  }

  String toDebugText() {
    return toDebugMap().entries
        .map((entry) {
          return '${entry.key}: ${entry.value}';
        })
        .join('\n');
  }
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
    String? Function()? serverClientIdProvider,
  }) : _store = store ?? CalendarConnectionStore(),
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _usesGoogleSignInInstance = googleSignIn == null,
       _serverClientIdProvider =
           serverClientIdProvider ??
           (() => _calendarGoogleSignInServerClientId);

  final CalendarConnectionStore _store;
  final GoogleSignIn _googleSignIn;
  final bool _usesGoogleSignInInstance;
  final String? Function() _serverClientIdProvider;
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

  Future<CalendarAuthDebugConfigurationInfo> getDebugConfigurationInfo() async {
    final metadata = await _store.read();
    final appDebugInfo = await DndService.getAppDebugInfo();
    final serverClientId = _serverClientId;

    return CalendarAuthDebugConfigurationInfo(
      buildMode: _buildMode,
      scopes: List<String>.unmodifiable(calendarAuthScopes),
      dartClientIdConfigured: _isConfigured(_calendarGoogleSignInClientId),
      dartServerClientIdConfigured: _isConfigured(serverClientId),
      dartServerClientIdMasked: maskCalendarGoogleSignInServerClientId(
        serverClientId,
      ),
      usesGoogleSignInInstance: _usesGoogleSignInInstance,
      initializationStarted: _initialization != null,
      metadata: metadata,
      androidPackageName: appDebugInfo['packageName'] as String?,
      androidApplicationId: appDebugInfo['applicationId'] as String?,
      androidAppLabel: appDebugInfo['appLabel'] as String?,
      androidSdkInt: (appDebugInfo['androidSdkInt'] as num?)?.toInt(),
      internetPermissionDeclared:
          appDebugInfo['internetPermissionDeclared'] as bool?,
      defaultWebClientIdResourcePresent:
          appDebugInfo['defaultWebClientIdResourcePresent'] as bool?,
      platformDiagnosticsError: appDebugInfo['platformError'] as String?,
    );
  }

  Future<CalendarConnectResult> connect() async {
    await _logSignInStarting();
    try {
      if (!_isConfigured(_serverClientId)) {
        await _store.saveDisconnected(status: 'configuration_missing');
        _log('Calendar sign-in failed: Web client ID missing.');
        return CalendarConnectResult.failed(_missingWebClientIdMessage);
      }

      await _ensureInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        await _store.saveDisconnected(status: 'unsupported');
        _log('Calendar sign-in failed: authenticate unsupported on platform.');
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
      _log('Calendar sign-in succeeded: email=${account.email}');
      return CalendarConnectResult.connected(account.email);
    } on GoogleSignInException catch (e, stack) {
      _logFailure('Calendar sign-in', e, stack);
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        await _store.saveDisconnected(status: 'cancelled');
        return CalendarConnectResult.cancelled();
      }

      await _store.saveDisconnected(status: 'failed:${_debugCodeForError(e)}');
      return CalendarConnectResult.failed(_messageForGoogleSignInException(e));
    } on PlatformException catch (e, stack) {
      _logFailure('Calendar sign-in', e, stack);
      await _store.saveDisconnected(status: 'failed:${_debugCodeForError(e)}');
      return CalendarConnectResult.failed(_messageForPlatformException(e));
    } catch (e, stack) {
      _logFailure('Calendar sign-in', e, stack);
      await _store.saveDisconnected(status: 'failed:${_debugCodeForError(e)}');
      return CalendarConnectResult.failed(_messageForUnknownException(e));
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
      if (!_isConfigured(_serverClientId)) {
        await _store.saveDisconnected(
          status: 'auth_client_failed:configuration_missing',
        );
        _log('Calendar auth client failed: Web client ID missing.');
        return null;
      }

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
    } on GoogleSignInException catch (e, stack) {
      _logFailure('Calendar auth client', e, stack);
      await _store.saveDisconnected(
        status: 'auth_client_failed:${_debugCodeForError(e)}',
      );
      return null;
    } on PlatformException catch (e, stack) {
      _logFailure('Calendar auth client', e, stack);
      await _store.saveDisconnected(
        status: 'auth_client_failed:${_debugCodeForError(e)}',
      );
      return null;
    } catch (e, stack) {
      _logFailure('Calendar auth client', e, stack);
      await _store.saveDisconnected(
        status: 'auth_client_failed:${_debugCodeForError(e)}',
      );
      return null;
    }
  }

  Future<void> _ensureInitialized() {
    final serverClientId = _serverClientId;
    return _initialization ??= _googleSignIn.initialize(
      clientId: _calendarGoogleSignInClientId,
      serverClientId: serverClientId,
    );
  }

  String _messageForGoogleSignInException(GoogleSignInException exception) {
    final debugSuffix = _friendlyDebugSuffix(exception);
    final description = exception.description?.toLowerCase() ?? '';
    switch (exception.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
        if (description.contains('serverclientid')) {
          return _missingWebClientIdMessage;
        }
        return 'Google Calendar sign-in needs a Google OAuth configuration check. $debugSuffix';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in provider configuration needs checking. $debugSuffix';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in could not open on this device. $debugSuffix';
      default:
        return 'Google Calendar could not be connected. $debugSuffix';
    }
  }

  String _messageForPlatformException(PlatformException exception) {
    return 'Google Calendar could not be connected. '
        '${_friendlyDebugSuffix(exception)}';
  }

  String _messageForUnknownException(Object exception) {
    return 'Google Calendar could not be connected. '
        '${_friendlyDebugSuffix(exception)}';
  }

  Future<void> _logSignInStarting() async {
    final metadata = await _store.read();
    final appDebugInfo = await DndService.getAppDebugInfo();
    _log('Calendar sign-in starting');
    _log('Calendar sign-in scopes: ${calendarAuthScopes.join(', ')}');
    _log(
      'Calendar sign-in serverClientId configured: '
      '${_isConfigured(_serverClientId)}',
    );
    _log(
      'Calendar sign-in serverClientId: '
      '${maskCalendarGoogleSignInServerClientId(_serverClientId)}',
    );
    _log(
      'Calendar sign-in metadata: connected=${metadata.connected}, '
      'email=${metadata.email ?? 'none'}, '
      'lastAuthStatus=${metadata.lastAuthStatus ?? 'none'}',
    );
    _log(
      'Calendar sign-in app id: '
      'package=${appDebugInfo['packageName'] ?? 'unknown'}, '
      'applicationId=${appDebugInfo['applicationId'] ?? 'unknown'}',
    );
  }

  void _logFailure(String operation, Object exception, StackTrace stack) {
    _log('$operation failed');
    _log('Exception type: ${exception.runtimeType}');
    if (exception is GoogleSignInException) {
      _log('GoogleSignInException code: ${exception.code.name}');
      _log(
        'GoogleSignInException description: '
        '${_safeDebugValue(exception.description)}',
      );
      _log(
        'GoogleSignInException details: ${_safeDebugValue(exception.details)}',
      );
    } else if (exception is PlatformException) {
      _log('PlatformException code: ${exception.code}');
      _log('PlatformException message: ${_safeDebugValue(exception.message)}');
      _log('PlatformException details: ${_safeDebugValue(exception.details)}');
    } else {
      _log('Exception message: ${_safeDebugValue(exception)}');
    }
    debugPrintStack(label: '$operation stack trace', stackTrace: stack);
  }

  void _log(String message) {
    debugPrint('[CalendarAuth] $message');
  }

  String _friendlyDebugSuffix(Object exception) {
    return '(Debug: ${_debugMessageForError(exception)})';
  }

  String _debugMessageForError(Object exception) {
    if (exception is GoogleSignInException) {
      final description = _safeDebugOneLine(exception.description);
      if (description == null) return exception.code.name;
      return '${exception.code.name}: ${_truncate(description)}';
    }
    if (exception is PlatformException) {
      final message = _safeDebugOneLine(exception.message);
      if (message == null) return exception.code;
      return '${exception.code}: ${_truncate(message)}';
    }
    return exception.runtimeType.toString();
  }

  String _debugCodeForError(Object exception) {
    if (exception is GoogleSignInException) {
      return exception.code.name;
    }
    if (exception is PlatformException) {
      return exception.code;
    }
    return exception.runtimeType.toString();
  }

  String? _oneLine(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _truncate(String value) {
    const maxLength = 96;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }

  String _safeDebugValue(Object? value) {
    final text = _safeDebugOneLine(value?.toString());
    return text ?? 'none';
  }

  String? _safeDebugOneLine(String? value) {
    final text = _oneLine(value);
    if (text == null) return null;
    return maskCalendarGoogleClientIdsInDebugText(text);
  }

  bool _isConfigured(String? value) => value != null && value.trim().isNotEmpty;

  String? get _serverClientId => _serverClientIdProvider();

  String get _buildMode {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }
}
