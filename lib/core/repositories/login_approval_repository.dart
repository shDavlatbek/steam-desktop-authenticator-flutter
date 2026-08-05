import '../crypto/mobile_confirmation_signature.dart';
import '../models/qr_challenge.dart';
import '../models/steam_guard_account.dart';
import '../services/debug_logger.dart';
import '../services/steam_login_approval_service.dart';
import '../services/steam_web_service.dart';
import 'account_repository.dart';
import 'confirmation_repository.dart' show NeedsAuthenticationException;

/// Approves or denies QR logins started on other devices — the role the
/// official Steam mobile app plays when it scans a login QR code.
///
/// Requires an account this app holds the `shared_secret` for, since approval
/// is proven by signing the pending session's identifiers.
class LoginApprovalRepository {
  final SteamWebService _web;
  final AccountRepository _accountRepo;
  final DebugLogger _log = DebugLogger();

  LoginApprovalRepository({
    required SteamWebService web,
    required AccountRepository accountRepo,
  })  : _web = web,
        _accountRepo = accountRepo;

  /// Whether [account] holds everything needed to approve logins.
  static bool canApprove(SteamGuardAccount account) =>
      account.sharedSecret != null &&
      account.sharedSecret!.isNotEmpty &&
      account.session?.refreshToken != null;

  /// Fetches details of the pending login so the user can inspect it before
  /// deciding.
  Future<AuthSessionInfo> getSessionInfo(
    SteamGuardAccount account,
    QrChallenge challenge,
  ) async {
    await _ensureValidSession(account);

    _log.info('LoginApproval', 'Fetching session info',
        detail: 'clientId: ${challenge.clientId}');

    return SteamLoginApprovalService.getAuthSessionInfo(
      _web,
      account.session!.accessToken!,
      challenge.clientId,
    );
  }

  /// Approves ([approve] true) or denies the pending login.
  Future<void> respond(
    SteamGuardAccount account,
    QrChallenge challenge, {
    required bool approve,
  }) async {
    await _ensureValidSession(account);

    final steamId = account.session!.steamID.toString();
    final signature = MobileConfirmationSignature.generateBase64(
      sharedSecret: account.sharedSecret!,
      version: challenge.version,
      clientId: challenge.clientId,
      steamId: steamId,
    );

    _log.info('LoginApproval', approve ? 'Approving login' : 'Denying login',
        detail: 'clientId: ${challenge.clientId}, '
            'version: ${challenge.version}, steamId: $steamId');

    await SteamLoginApprovalService.submitMobileConfirmation(
      _web,
      account.session!.accessToken!,
      version: challenge.version,
      clientId: challenge.clientId,
      steamId: steamId,
      signature: signature,
      confirm: approve,
    );

    _log.info('LoginApproval', 'Steam accepted the response');
  }

  /// Ensures the account can sign and has a usable access token.
  ///
  /// Steam rejects approval calls made with a stale or non-mobile token
  /// (EResult 15), so the token is refreshed up front rather than after a
  /// confusing failure.
  Future<void> _ensureValidSession(SteamGuardAccount account) async {
    if (account.sharedSecret == null || account.sharedSecret!.isEmpty) {
      throw MissingSecretException(account.accountName);
    }

    final session = account.session;
    if (session == null || session.refreshToken == null) {
      throw NeedsAuthenticationException();
    }

    if (session.isRefreshTokenExpired()) {
      _log.error('LoginApproval',
          'Refresh token expired for ${account.accountName}');
      throw NeedsAuthenticationException();
    }

    if (session.isAccessTokenExpired()) {
      _log.info('LoginApproval',
          'Access token expired, refreshing for ${account.accountName}');
      try {
        await _accountRepo.refreshSession(account);
      } catch (e) {
        _log.error('LoginApproval', 'Token refresh failed: $e');
        throw NeedsAuthenticationException();
      }
    }
  }
}

/// Thrown when an account has no `shared_secret`, so logins cannot be signed.
class MissingSecretException implements Exception {
  final String? accountName;

  MissingSecretException(this.accountName);

  @override
  String toString() =>
      '${accountName ?? 'This account'} has no shared secret, so it cannot '
      'approve logins. Import its .maFile to enable this.';
}
