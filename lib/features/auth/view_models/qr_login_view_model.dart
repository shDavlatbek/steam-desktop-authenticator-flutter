import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:sda_flutter/core/models/session_data.dart';
import 'package:sda_flutter/core/services/steam_auth_service.dart';
import 'package:sda_flutter/core/services/debug_logger.dart';

/// Stages of a QR login, mapped onto what the user sees on screen.
enum QrLoginState {
  /// Asking Steam for a challenge.
  starting,

  /// QR is on screen, nobody has scanned it yet.
  waitingForScan,

  /// Steam reported remote interaction — scanned, awaiting approval in the app.
  scanned,

  /// Tokens received.
  success,

  /// The challenge went stale; the user can request a fresh one.
  expired,

  error,
}

/// Drives password-free login: Steam issues a challenge, this app renders it as
/// a QR code, the user approves it in the official Steam mobile app, and the
/// resulting tokens come back through polling.
///
/// Steam rotates the challenge periodically, so the displayed code is expected
/// to change while the user is looking at it.
class QrLoginViewModel extends ChangeNotifier {
  final SteamAuthService _authService;
  final DebugLogger _log = DebugLogger();

  /// How long to keep polling before declaring the attempt stale.
  static const Duration _attemptWindow = Duration(minutes: 3);

  /// Consecutive poll failures tolerated before giving up. Steam returns
  /// transient errors while a session is pending, so a single failure means
  /// nothing.
  static const int _maxConsecutiveFailures = 5;

  QrLoginState state = QrLoginState.starting;
  String? errorMessage;

  /// The URL to encode into the QR image. Changes when Steam rotates it.
  String? challengeUrl;

  /// Set once [state] is [QrLoginState.success].
  SessionData? session;

  /// The account name Steam reports on success, which a QR login learns only
  /// at the very end.
  String? accountName;

  String? _clientId;
  String? _requestId;
  int _pollIntervalSeconds = 5;
  bool _polling = false;
  bool _disposed = false;

  QrLoginViewModel({required SteamAuthService authService})
      : _authService = authService;

  String get statusText {
    switch (state) {
      case QrLoginState.starting:
        return 'Requesting a login code from Steam...';
      case QrLoginState.waitingForScan:
        return 'Scan this code with the Steam mobile app.';
      case QrLoginState.scanned:
        return 'Code scanned — approve the login on your phone.';
      case QrLoginState.success:
        return 'Approved. Signing in...';
      case QrLoginState.expired:
        return 'This code expired before it was approved.';
      case QrLoginState.error:
        return errorMessage ?? 'An unknown error occurred.';
    }
  }

  bool get isBusy =>
      state == QrLoginState.starting || state == QrLoginState.success;

  /// Requests a challenge and begins polling. Safe to call again to replace an
  /// expired code.
  Future<void> start() async {
    _polling = false; // stop any in-flight loop before starting a new session

    state = QrLoginState.starting;
    errorMessage = null;
    challengeUrl = null;
    session = null;
    accountName = null;
    _notify();

    try {
      final result = await _authService.beginAuthSessionViaQR();

      _clientId = result['client_id']?.toString();
      _requestId = result['request_id']?.toString();
      challengeUrl = result['challenge_url'] as String?;

      final interval = double.tryParse(result['interval']?.toString() ?? '');
      _pollIntervalSeconds = (interval == null || interval < 1)
          ? 5
          : interval.round();

      if (_clientId == null || _requestId == null || challengeUrl == null) {
        throw Exception('Steam returned an incomplete QR challenge.');
      }

      _log.info('QrLogin', 'QR session started',
          detail: 'clientId: $_clientId, interval: ${_pollIntervalSeconds}s');

      state = QrLoginState.waitingForScan;
      _notify();

      unawaited(_pollUntilResolved());
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _pollUntilResolved() async {
    _polling = true;
    final deadline = DateTime.now().add(_attemptWindow);
    int consecutiveFailures = 0;

    while (_polling && !_disposed) {
      await Future.delayed(Duration(seconds: _pollIntervalSeconds));
      if (!_polling || _disposed) return;

      if (DateTime.now().isAfter(deadline)) {
        state = QrLoginState.expired;
        _polling = false;
        _notify();
        return;
      }

      try {
        final result = await _authService.pollAuthSessionStatus(
          _clientId!,
          _requestId!,
        );
        consecutiveFailures = 0;

        if (result['access_token'] != null) {
          _completeLogin(result);
          return;
        }

        // Steam rotates the challenge; the display has to follow or the user
        // ends up scanning a code that is no longer valid.
        final newClientId = result['new_client_id'] as String?;
        if (newClientId != null && newClientId != '0') {
          _clientId = newClientId;
        }
        final newChallengeUrl = result['new_challenge_url'] as String?;
        if (newChallengeUrl != null && newChallengeUrl != challengeUrl) {
          challengeUrl = newChallengeUrl;
          _notify();
        }

        if (result['had_remote_interaction'] == true &&
            state == QrLoginState.waitingForScan) {
          state = QrLoginState.scanned;
          _notify();
        }
      } catch (e) {
        consecutiveFailures++;
        _log.error('QrLogin', 'Poll failed ($consecutiveFailures): $e');

        if (consecutiveFailures >= _maxConsecutiveFailures) {
          _polling = false;
          _fail(Exception(
              'Lost contact with Steam while waiting for approval.'));
          return;
        }
      }
    }
  }

  void _completeLogin(Map<String, dynamic> result) {
    _polling = false;

    final accessToken = result['access_token'] as String;
    final refreshToken = result['refresh_token'] as String?;

    // A QR login never states the SteamID outright, so read it from the token.
    final steamId = SessionData.steamIdFromToken(refreshToken ?? accessToken);
    if (steamId == null) {
      _fail(Exception('Steam returned a token without a SteamID.'));
      return;
    }

    session = SessionData(
      steamID: steamId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionID: SessionData.generateSessionID(),
    );
    accountName = result['account_name'] as String?;

    _log.info('QrLogin', 'QR login approved', detail: 'SteamID: $steamId');

    state = QrLoginState.success;
    _notify();
  }

  void _fail(Object error) {
    state = QrLoginState.error;
    final message = error.toString();
    errorMessage = message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _polling = false;
    super.dispose();
  }
}
