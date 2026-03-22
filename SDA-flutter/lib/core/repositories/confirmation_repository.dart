import '../constants/api_endpoints.dart';
import '../crypto/confirmation_hash.dart';
import '../models/confirmation.dart';
import '../models/steam_guard_account.dart';
import '../services/debug_logger.dart';
import '../services/steam_confirmation_service.dart';
import '../services/steam_time_service.dart';
import '../services/steam_token_service.dart';
import '../services/steam_web_service.dart';

/// Manages Steam trade/market confirmation operations.
///
/// Provides a high-level API for fetching, accepting, and denying confirmations
/// by orchestrating the lower-level [SteamConfirmationService],
/// [SteamTimeService], and [SteamWebService].
class ConfirmationRepository {
  final SteamWebService _web;
  final SteamTimeService _timeService;
  final DebugLogger _log = DebugLogger();

  ConfirmationRepository({
    required SteamWebService web,
    required SteamTimeService timeService,
  })  : _web = web,
        _timeService = timeService;

  /// Refreshes the access token if expired, matching C# MainForm's
  /// timerTradesPopup_Tick logic that refreshes before every confirmation call.
  Future<void> _ensureValidSession(SteamGuardAccount account) async {
    final session = account.session;
    if (session == null) {
      throw NeedsAuthenticationException();
    }

    if (session.isRefreshTokenExpired()) {
      _log.error('ConfirmationRepo',
          'Refresh token expired for ${account.accountName}');
      throw NeedsAuthenticationException();
    }

    if (session.isAccessTokenExpired()) {
      _log.info('ConfirmationRepo',
          'Access token expired, refreshing for ${account.accountName}');
      try {
        final tokens = await SteamTokenService.refreshAccessToken(
          _web,
          session.refreshToken!,
          session.steamID,
        );
        session.accessToken = tokens['access_token'];
        if (tokens.containsKey('refresh_token')) {
          session.refreshToken = tokens['refresh_token'];
        }
        _log.info('ConfirmationRepo', 'Access token refreshed successfully');
      } catch (e, st) {
        _log.error('ConfirmationRepo', 'Token refresh failed: $e',
            detail: st.toString());
        throw NeedsAuthenticationException();
      }
    }
  }

  /// Fetches all pending confirmations for [account].
  ///
  /// Throws an [Exception] when the response indicates failure, and a
  /// [NeedsAuthenticationException] when the session has expired.
  Future<List<Confirmation>> fetchConfirmations(
    SteamGuardAccount account,
  ) async {
    _log.info('ConfirmationRepo', 'Fetching confirmations for ${account.accountName}',
        detail: 'SteamID: ${account.session?.steamID}, '
            'DeviceID: ${account.deviceId}, '
            'HasIdentitySecret: ${account.identitySecret != null}, '
            'HasSession: ${account.session != null}, '
            'AccessTokenExpired: ${account.session?.isAccessTokenExpired()}');

    await _ensureValidSession(account);

    final url = await generateConfirmationUrl(account);
    _log.info('ConfirmationRepo', 'Confirmation URL built', detail: url);

    final cookies = account.session!.getCookieMap();
    _log.info('ConfirmationRepo', 'Cookies',
        detail: cookies.keys.join(', '));

    final responseMap =
        await SteamConfirmationService.fetchConfirmations(_web, url, cookies);
    _log.info('ConfirmationRepo', 'Response received',
        detail: responseMap.toString());

    final response = ConfirmationsResponse.fromJson(responseMap);

    if (!response.success) {
      final msg = response.message ?? 'Failed to fetch confirmations';
      _log.error('ConfirmationRepo', 'Fetch failed: $msg');
      throw Exception(msg);
    }
    if (response.needAuthentication) {
      _log.error('ConfirmationRepo', 'Session expired — needs re-authentication');
      throw NeedsAuthenticationException();
    }

    _log.info('ConfirmationRepo',
        'Fetched ${response.confirmations?.length ?? 0} confirmations');
    return response.confirmations ?? [];
  }

  /// Accepts a single [conf] for [account].
  Future<bool> acceptConfirmation(
    SteamGuardAccount account,
    Confirmation conf,
  ) async {
    return _sendConfirmationAjax(account, conf, 'allow');
  }

  /// Denies a single [conf] for [account].
  Future<bool> denyConfirmation(
    SteamGuardAccount account,
    Confirmation conf,
  ) async {
    return _sendConfirmationAjax(account, conf, 'cancel');
  }

  /// Accepts multiple confirmations for [account] in a single request.
  Future<bool> acceptMultipleConfirmations(
    SteamGuardAccount account,
    List<Confirmation> confs,
  ) async {
    return _sendMultiConfirmationAjax(account, confs, 'allow');
  }

  /// Denies multiple confirmations for [account] in a single request.
  Future<bool> denyMultipleConfirmations(
    SteamGuardAccount account,
    List<Confirmation> confs,
  ) async {
    return _sendMultiConfirmationAjax(account, confs, 'cancel');
  }

  /// Generates the full confirmation list URL with signed query parameters.
  Future<String> generateConfirmationUrl(
    SteamGuardAccount account, {
    String tag = 'conf',
  }) async {
    final queryString = await generateConfirmationQueryParams(account, tag);
    return '${ApiEndpoints.confirmationGetList}?$queryString';
  }

  /// Generates signed query parameters for a confirmation request.
  ///
  /// Throws an [ArgumentError] if the account has no device ID.
  Future<String> generateConfirmationQueryParams(
    SteamGuardAccount account,
    String tag,
  ) async {
    if (account.deviceId == null || account.deviceId!.isEmpty) {
      throw ArgumentError('Device ID is not present');
    }

    final time = await _timeService.getSteamTime();
    final hash =
        ConfirmationHash.generateForTime(account.identitySecret!, time, tag);

    final params = {
      'p': account.deviceId!,
      'a': account.session!.steamID.toString(),
      'k': hash!,
      't': time.toString(),
      'm': 'react',
      'tag': tag,
    };

    return params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  Future<bool> _sendConfirmationAjax(
    SteamGuardAccount account,
    Confirmation conf,
    String op,
  ) async {
    await _ensureValidSession(account);
    final tag = op == 'allow' ? 'accept' : 'reject';
    final queryParams = await generateConfirmationQueryParams(account, tag);
    final cookies = account.session!.getCookieMap();

    return SteamConfirmationService.sendConfirmationAjax(
      _web,
      conf.id,
      conf.key,
      op,
      queryParams,
      cookies,
    );
  }

  Future<bool> _sendMultiConfirmationAjax(
    SteamGuardAccount account,
    List<Confirmation> confs,
    String op,
  ) async {
    await _ensureValidSession(account);
    final tag = op == 'allow' ? 'accept' : 'reject';
    final queryParams = await generateConfirmationQueryParams(account, tag);
    final cookies = account.session!.getCookieMap();

    final confMaps = confs
        .map((c) => {'id': c.id, 'nonce': c.key})
        .toList();

    return SteamConfirmationService.sendMultiConfirmationAjax(
      _web,
      confMaps,
      op,
      queryParams,
      cookies,
    );
  }
}

/// Thrown when a confirmation request indicates the session has expired and
/// the user needs to re-authenticate.
class NeedsAuthenticationException implements Exception {
  @override
  String toString() => 'Needs re-authentication';
}
