import '../crypto/steam_totp.dart';
import '../models/steam_guard_account.dart';
import '../services/steam_auth_service.dart';
import '../services/steam_time_service.dart';
import '../services/steam_token_service.dart';
import '../services/steam_two_factor_service.dart';
import '../services/steam_web_service.dart';

/// Orchestrates account-level operations such as TOTP generation, login,
/// session refresh, and authenticator management.
///
/// Acts as a facade over the lower-level service classes so that view models
/// can perform account operations without knowing the service details.
class AccountRepository {
  final SteamWebService _web;
  final SteamTimeService _timeService;
  final SteamAuthService _authService;

  AccountRepository({
    required SteamWebService web,
    required SteamTimeService timeService,
    required SteamAuthService authService,
  })  : _web = web,
        _timeService = timeService,
        _authService = authService;

  /// Generates a 5-character Steam Guard TOTP code for the given [account]
  /// using the current Steam-aligned time.
  Future<String?> generateSteamGuardCode(SteamGuardAccount account) async {
    final time = await _timeService.getSteamTime();
    return SteamTotp.generateCodeForTime(account.sharedSecret, time);
  }

  /// Returns the current Unix timestamp aligned with Steam servers.
  Future<int> getSteamTime() => _timeService.getSteamTime();

  /// Initiates a credential-based login flow with Steam.
  ///
  /// 1. Fetches the RSA public key for [username].
  /// 2. Encrypts [password] with the RSA key.
  /// 3. Begins an authentication session.
  ///
  /// Returns the raw session response map. The caller (typically a view model)
  /// is responsible for handling polling and 2FA submission.
  Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    // 1. Get RSA public key
    final rsaData = await _authService.getPasswordRsaPublicKey(username);

    // 2. Encrypt password
    final encryptedPassword = _authService.encryptPassword(
      password,
      rsaData['publickey_mod']!,
      rsaData['publickey_exp']!,
    );

    // 3. Begin auth session
    final sessionData = await _authService.beginAuthSession(
      username,
      encryptedPassword,
      rsaData['timestamp']!,
    );

    return sessionData;
  }

  /// Refreshes the access token for the given [account].
  ///
  /// When [allowRenewal] is `true`, a new refresh token may also be issued.
  /// Throws an [Exception] if the account has no session.
  Future<void> refreshSession(
    SteamGuardAccount account, {
    bool allowRenewal = false,
  }) async {
    if (account.session == null) throw Exception('No session');

    final result = await SteamTokenService.refreshAccessToken(
      _web,
      account.session!.refreshToken!,
      account.session!.steamID,
      allowRenewal: allowRenewal,
    );

    account.session!.accessToken = result['access_token'];
    if (result.containsKey('refresh_token') &&
        result['refresh_token'] != null) {
      account.session!.refreshToken = result['refresh_token'];
    }
  }

  /// Removes the Steam Guard authenticator from [account].
  ///
  /// [scheme] - The Steam Guard scheme to revert to (e.g. 1 = email codes).
  ///
  /// Returns `true` if the authenticator was successfully removed.
  Future<bool> deactivateAuthenticator(
    SteamGuardAccount account,
    int scheme,
  ) async {
    return await SteamTwoFactorService.removeAuthenticator(
      _web,
      account.session!.accessToken!,
      account.revocationCode!,
      scheme,
    );
  }
}
