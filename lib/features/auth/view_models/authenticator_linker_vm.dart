import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:sda_flutter/core/crypto/steam_totp.dart';
import 'package:sda_flutter/core/models/session_data.dart';
import 'package:sda_flutter/core/models/steam_guard_account.dart';
import 'package:sda_flutter/core/services/steam_time_service.dart';
import 'package:sda_flutter/core/services/steam_two_factor_service.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Represents the current state of the authenticator linking flow.
enum LinkingState {
  idle,
  checkingPhone,
  mustProvidePhone,
  mustConfirmEmail,
  addingAuthenticator,
  awaitingFinalization,
  enterSmsCode,
  finalizing,
  showRevocationCode,
  success,
  error,
}

/// Port of AuthenticatorLinker.cs state machine combined with the linking flow
/// from LoginForm.cs.
///
/// Drives the full authenticator linking process:
/// 1. Check whether the account has a verified phone number.
/// 2. If not, prompt for a phone number, confirm email, and verify via SMS.
/// 3. Add the authenticator (ITwoFactorService/AddAuthenticator).
/// 4. Finalize by submitting the SMS activation code.
/// 5. Present the revocation code and save the account.
class AuthenticatorLinkerViewModel extends ChangeNotifier {
  final SteamWebService _web;
  final SteamTimeService _timeService;

  /// The current step of the linking flow.
  LinkingState state = LinkingState.idle;

  /// The newly linked account (populated after addAuthenticator succeeds).
  SteamGuardAccount? linkedAccount;

  /// The device identifier used for the authenticator registration.
  String? deviceId;

  /// User-facing error message when [state] is [LinkingState.error].
  String? errorMessage;

  /// The email address where Steam sent a confirmation link (phone flow).
  String? confirmationEmailAddress;

  /// The revocation code shown to the user after successful linking.
  String? revocationCode;

  /// The session obtained from the login step.
  SessionData? _session;


  AuthenticatorLinkerViewModel({
    required SteamWebService web,
    required SteamTimeService timeService,
  })  : _web = web,
        _timeService = timeService;

  /// A human-readable status message for the current state.
  String get statusText {
    switch (state) {
      case LinkingState.idle:
        return '';
      case LinkingState.checkingPhone:
        return 'Checking phone status...';
      case LinkingState.mustProvidePhone:
        return 'A phone number is required to add an authenticator.';
      case LinkingState.mustConfirmEmail:
        return 'Please confirm the email sent to '
            '${confirmationEmailAddress ?? "your email address"}.';
      case LinkingState.addingAuthenticator:
        return 'Adding authenticator...';
      case LinkingState.awaitingFinalization:
        return 'Waiting for SMS code to finalize...';
      case LinkingState.enterSmsCode:
        return 'Enter the SMS code sent to your phone.';
      case LinkingState.finalizing:
        return 'Finalizing authenticator...';
      case LinkingState.showRevocationCode:
        return 'Write down your revocation code! You need it to remove the '
            'authenticator.';
      case LinkingState.success:
        return 'Authenticator linked successfully!';
      case LinkingState.error:
        return errorMessage ?? 'An unknown error occurred.';
    }
  }

  /// Begins the linking flow by calling AddAuthenticator directly.
  ///
  /// Steam will send the activation code to the account's email or phone
  /// automatically — no need to check or add a phone number first.
  Future<void> startLinking(SessionData session) async {
    _session = session;
    deviceId = 'android:${const Uuid().v4()}';
    errorMessage = null;

    await _addAuthenticator();
  }

  /// Calls ITwoFactorService/AddAuthenticator to register a new authenticator
  /// on the account.
  Future<void> _addAuthenticator() async {
    state = LinkingState.addingAuthenticator;
    notifyListeners();

    try {
      final result = await SteamTwoFactorService.addAuthenticator(
        _web,
        _session!.accessToken!,
        _session!.steamID,
        deviceId!,
      );

      final response = result['response'] as Map<String, dynamic>?;
      if (response == null) {
        state = LinkingState.error;
        errorMessage = 'Steam returned an empty response.';
        notifyListeners();
        return;
      }

      final status = response['status'] as int?;
      if (status == 29) {
        state = LinkingState.error;
        errorMessage = 'This account already has an authenticator. '
            'Remove it first before adding a new one.';
        notifyListeners();
        return;
      }
      if (status == 2) {
        state = LinkingState.error;
        errorMessage = 'A phone number is required but not yet verified.';
        notifyListeners();
        return;
      }
      if (status != 1) {
        state = LinkingState.error;
        errorMessage = 'Failed to add authenticator (status: $status).';
        notifyListeners();
        return;
      }

      // Build the linked account from the response.
      linkedAccount = SteamGuardAccount(
        sharedSecret: response['shared_secret'] as String?,
        serialNumber: response['serial_number']?.toString(),
        revocationCode: response['revocation_code'] as String?,
        uri: response['uri'] as String?,
        serverTime: int.tryParse(response['server_time']?.toString() ?? '0') ?? 0,
        accountName: response['account_name'] as String?,
        tokenGid: response['token_gid'] as String?,
        identitySecret: response['identity_secret'] as String?,
        secret1: response['secret_1'] as String?,
        status: response['status'] as int? ?? 0,
        deviceId: deviceId,
        phoneNumberHint: response['phone_number_hint'] as String?,
        fullyEnrolled: false,
        session: _session,
      );

      revocationCode = linkedAccount!.revocationCode;

      // Show the revocation code, then wait for SMS to finalize.
      state = LinkingState.showRevocationCode;
      notifyListeners();
    } catch (e) {
      state = LinkingState.error;
      errorMessage = _formatError(e);
      notifyListeners();
    }
  }

  /// Moves from the revocation code screen to the SMS finalization step.
  void proceedToFinalization() {
    state = LinkingState.awaitingFinalization;
    notifyListeners();
  }

  /// Finalizes the authenticator by submitting the activation SMS code along
  /// with the current TOTP code generated from the new shared secret.
  ///
  /// On success, marks the account as fully enrolled and transitions to
  /// [LinkingState.success].
  Future<void> finalizeAuthenticator(String smsCode) async {
    if (smsCode.trim().isEmpty) {
      state = LinkingState.error;
      errorMessage = 'Please enter the SMS code.';
      notifyListeners();
      return;
    }

    if (linkedAccount == null) {
      state = LinkingState.error;
      errorMessage = 'No authenticator to finalize.';
      notifyListeners();
      return;
    }

    state = LinkingState.finalizing;
    notifyListeners();

    try {
      final steamTime = await _timeService.getSteamTime();
      final authCode = SteamTotp.generateCodeForTime(
        linkedAccount!.sharedSecret,
        steamTime,
      );

      if (authCode == null || authCode.isEmpty) {
        state = LinkingState.error;
        errorMessage = 'Failed to generate TOTP code for finalization.';
        notifyListeners();
        return;
      }

      final result = await SteamTwoFactorService.finalizeAddAuthenticator(
        _web,
        _session!.accessToken!,
        _session!.steamID,
        authCode,
        steamTime,
        smsCode.trim(),
      );

      final response = result['response'] as Map<String, dynamic>?;
      if (response == null) {
        state = LinkingState.error;
        errorMessage = 'Steam returned an empty finalization response.';
        notifyListeners();
        return;
      }

      final success = response['success'] as bool? ?? false;
      final wantMore = response['want_more'] as bool? ?? false;
      final status = response['status'] as int?;

      if (status == 89) {
        state = LinkingState.error;
        errorMessage = 'Invalid SMS code. Please try again.';
        notifyListeners();
        return;
      }

      if (!success && !wantMore) {
        state = LinkingState.error;
        errorMessage =
            'Failed to finalize authenticator (status: $status).';
        notifyListeners();
        return;
      }

      if (wantMore) {
        // Steam wants another round of finalization (rare). Go back to
        // awaiting finalization.
        state = LinkingState.awaitingFinalization;
        notifyListeners();
        return;
      }

      // Success!
      linkedAccount!.fullyEnrolled = true;
      state = LinkingState.success;
      notifyListeners();
    } catch (e) {
      state = LinkingState.error;
      errorMessage = _formatError(e);
      notifyListeners();
    }
  }

  /// Resets the view model to its initial state.
  void reset() {
    state = LinkingState.idle;
    errorMessage = null;
    linkedAccount = null;
    deviceId = null;
    confirmationEmailAddress = null;
    revocationCode = null;
    _session = null;
    notifyListeners();
  }

  /// Formats an exception into a user-friendly error string.
  String _formatError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }
}
