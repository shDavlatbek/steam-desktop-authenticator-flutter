import 'package:flutter/foundation.dart';

import 'package:sda_flutter/core/crypto/steam_totp.dart';
import 'package:sda_flutter/core/models/session_data.dart';
import 'package:sda_flutter/core/models/steam_guard_account.dart';
import 'package:sda_flutter/core/services/steam_auth_service.dart';
import 'package:sda_flutter/core/services/steam_time_service.dart';

/// The type of login being performed.
enum LoginType {
  /// Fresh login for a new account setup.
  initial,

  /// Re-login to refresh an existing account's session.
  refresh,

  /// Login for importing an account from another device.
  import_,
}

/// Represents the current state of the login flow.
enum LoginState {
  idle,
  loggingIn,
  awaitingEmailCode,
  awaitingSteamGuardCode,
  polling,
  success,
  error,
}

/// Port of LoginForm.cs logic.
///
/// State machine that drives the Steam credential-based authentication flow,
/// including RSA encryption, 2FA submission, and polling for session tokens.
class LoginViewModel extends ChangeNotifier {
  final SteamAuthService _authService;
  final SteamTimeService _timeService;

  /// The type of login being performed.
  LoginType loginType;

  /// The current state of the login flow.
  LoginState state = LoginState.idle;

  /// Error message when [state] is [LoginState.error].
  String? errorMessage;

  /// The session data produced by a successful login.
  SessionData? session;

  /// The existing account, used for refresh/import modes where the username
  /// is pre-filled and TOTP codes can be auto-submitted.
  SteamGuardAccount? account;

  // Internal auth session state from beginAuthSession.
  String? _clientId;
  String? _requestId;
  int? _steamId;
  int _pollInterval = 5;

  LoginViewModel({
    required SteamAuthService authService,
    required SteamTimeService timeService,
    this.loginType = LoginType.initial,
    this.account,
  })  : _authService = authService,
        _timeService = timeService;

  /// Whether the UI should disable the username field (refresh mode pre-fills
  /// the account name).
  bool get isUsernameLocked =>
      loginType == LoginType.refresh && account?.accountName != null;

  /// The pre-filled username, if applicable.
  String get prefillUsername => account?.accountName ?? '';

  /// A human-readable description of what this login is for.
  String get explanationText {
    switch (loginType) {
      case LoginType.initial:
        return 'Log in with your Steam account to set up the authenticator.';
      case LoginType.refresh:
        return 'Your session has expired. Please log in again to refresh it.';
      case LoginType.import_:
        return 'Log in to import this account\'s authenticator.';
    }
  }

  /// A human-readable status message for the current state.
  String get statusText {
    switch (state) {
      case LoginState.idle:
        return '';
      case LoginState.loggingIn:
        return 'Logging in...';
      case LoginState.awaitingEmailCode:
        return 'A code was sent to your email address.';
      case LoginState.awaitingSteamGuardCode:
        return 'Enter your Steam Guard code.';
      case LoginState.polling:
        return 'Waiting for Steam to approve the login...';
      case LoginState.success:
        return 'Login successful!';
      case LoginState.error:
        return errorMessage ?? 'An unknown error occurred.';
    }
  }

  /// Initiates the login flow with the given credentials.
  ///
  /// Follows the Steam web authentication protocol:
  /// 1. Fetch RSA public key for the account.
  /// 2. Encrypt the password with the RSA key.
  /// 3. Begin an auth session.
  /// 4. Handle 2FA prompts or poll directly for tokens.
  Future<void> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      state = LoginState.error;
      errorMessage = 'Username and password are required.';
      notifyListeners();
      return;
    }

    state = LoginState.loggingIn;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Get RSA key and encrypt password
      final rsaData =
          await _authService.getPasswordRsaPublicKey(username.trim());
      final encryptedPassword = _authService.encryptPassword(
        password,
        rsaData['publickey_mod']!,
        rsaData['publickey_exp']!,
      );

      // 2. Begin auth session
      final result = await _authService.beginAuthSession(
        username.trim(),
        encryptedPassword,
        rsaData['timestamp']!,
      );

      _clientId = result['client_id']?.toString();
      _requestId = result['request_id']?.toString();
      _steamId = int.tryParse(result['steamid']?.toString() ?? '');
      _pollInterval =
          int.tryParse(result['interval']?.toString() ?? '5') ?? 5;

      // 3. Check if 2FA is needed
      final allowedConfirmations =
          result['allowed_confirmations'] as List<dynamic>?;
      if (allowedConfirmations != null && allowedConfirmations.isNotEmpty) {
        for (final conf in allowedConfirmations) {
          final type = conf['confirmation_type'];
          if (type == 3) {
            // Device code (TOTP) -- if we have an existing account with a
            // shared secret, auto-submit the code.
            if (account != null &&
                account!.sharedSecret != null &&
                loginType != LoginType.initial) {
              await _autoSubmitTotp();
              return;
            }
            state = LoginState.awaitingSteamGuardCode;
            notifyListeners();
            return;
          } else if (type == 2) {
            // Email code
            state = LoginState.awaitingEmailCode;
            notifyListeners();
            return;
          }
        }
      }

      // No 2FA needed -- poll directly
      await _pollForResult();
    } catch (e) {
      state = LoginState.error;
      errorMessage = _formatError(e);
      notifyListeners();
    }
  }

  /// Submits a Steam Guard code (email or TOTP) to the active auth session
  /// and then polls for the final session tokens.
  Future<void> submitCode(String code, {bool isEmailCode = false}) async {
    if (code.trim().isEmpty) {
      state = LoginState.error;
      errorMessage = 'Please enter a code.';
      notifyListeners();
      return;
    }

    state = LoginState.polling;
    notifyListeners();

    try {
      await _authService.updateWithSteamGuardCode(
        _clientId!,
        _steamId.toString(),
        code.trim(),
        isEmailCode ? 2 : 3,
      );
      await _pollForResult();
    } catch (e) {
      state = LoginState.error;
      errorMessage = _formatError(e);
      notifyListeners();
    }
  }

  /// Generates a TOTP code from the existing account's shared secret and
  /// automatically submits it, then polls for the result.
  Future<void> _autoSubmitTotp() async {
    state = LoginState.polling;
    notifyListeners();

    try {
      final time = await _timeService.getSteamTime();
      final code =
          SteamTotp.generateCodeForTime(account!.sharedSecret, time);
      if (code == null || code.isEmpty) {
        state = LoginState.error;
        errorMessage = 'Failed to generate TOTP code from shared secret.';
        notifyListeners();
        return;
      }

      await _authService.updateWithSteamGuardCode(
        _clientId!,
        _steamId.toString(),
        code,
        3, // TOTP code type
      );
      await _pollForResult();
    } catch (e) {
      state = LoginState.error;
      errorMessage = _formatError(e);
      notifyListeners();
    }
  }

  /// Polls Steam for session tokens until they become available or the
  /// attempt times out after ~60 intervals.
  Future<void> _pollForResult() async {
    state = LoginState.polling;
    notifyListeners();

    for (int i = 0; i < 60; i++) {
      try {
        final result = await _authService.pollAuthSessionStatus(
          _clientId!,
          _requestId!,
        );

        if (result.containsKey('access_token') &&
            result['access_token'] != null) {
          session = SessionData(
            steamID: _steamId ?? 0,
            accessToken: result['access_token'],
            refreshToken: result['refresh_token'],
            sessionID: SessionData.generateSessionID(),
          );
          state = LoginState.success;
          notifyListeners();
          return;
        }

        // The server may issue a new client ID for subsequent polls.
        if (result.containsKey('new_client_id') &&
            result['new_client_id'] != null) {
          _clientId = result['new_client_id'];
        }
      } catch (_) {
        // Transient errors during polling are expected; keep trying.
      }

      await Future.delayed(Duration(seconds: _pollInterval));
    }

    state = LoginState.error;
    errorMessage = 'Login timed out. Please try again.';
    notifyListeners();
  }

  /// Resets the view model to its initial state so the user can retry.
  void reset() {
    state = LoginState.idle;
    errorMessage = null;
    session = null;
    _clientId = null;
    _requestId = null;
    _steamId = null;
    _pollInterval = 5;
    notifyListeners();
  }

  /// Formats an exception into a user-friendly error string.
  String _formatError(Object error) {
    final message = error.toString();
    // Strip the "Exception: " prefix if present.
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }
}
