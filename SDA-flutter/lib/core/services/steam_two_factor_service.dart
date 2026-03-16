import 'dart:convert';

import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Handles ITwoFactorService API calls for managing Steam Guard
/// authenticators.
class SteamTwoFactorService {
  /// Registers a new authenticator for the given Steam account.
  ///
  /// [accessToken] - A valid access token for the user.
  /// [steamId] - The user's 64-bit Steam ID.
  /// [deviceId] - A unique device identifier (android:UUID format).
  ///
  /// Returns the full decoded JSON response from Steam, which contains the
  /// shared secret, identity secret, revocation code, etc.
  static Future<Map<String, dynamic>> addAuthenticator(
    SteamWebService web,
    String accessToken,
    int steamId,
    String deviceId,
  ) async {
    final url =
        '${ApiEndpoints.twoFactorAddAuthenticator}?access_token=$accessToken';
    final responseBody = await web.postRequest(
      url,
      body: {
        'steamid': steamId.toString(),
        'authenticator_type': '1',
        'device_identifier': deviceId,
        'sms_phone_id': '1',
        'version': '2',
      },
    );

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  /// Finalizes (activates) a newly added authenticator by confirming the SMS
  /// code the user received.
  ///
  /// [authCode] - The current TOTP code generated from the new shared secret.
  /// [authTime] - The Steam-aligned Unix timestamp used to generate [authCode].
  /// [smsCode] - The SMS verification code sent to the user's phone.
  ///
  /// Returns the full decoded JSON response from Steam.
  static Future<Map<String, dynamic>> finalizeAddAuthenticator(
    SteamWebService web,
    String accessToken,
    int steamId,
    String authCode,
    int authTime,
    String smsCode,
  ) async {
    final url =
        '${ApiEndpoints.twoFactorFinalizeAddAuthenticator}?access_token=$accessToken';
    final responseBody = await web.postRequest(
      url,
      body: {
        'steamid': steamId.toString(),
        'authenticator_code': authCode,
        'authenticator_time': authTime.toString(),
        'activation_code': smsCode,
        'validate_sms_code': '1',
      },
    );

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  /// Removes the authenticator from the account using the revocation code.
  ///
  /// [revocationCode] - The R-code saved when the authenticator was first added.
  /// [scheme] - The Steam Guard scheme to revert to (e.g. 1 = email codes).
  ///
  /// Returns `true` if the authenticator was successfully removed.
  static Future<bool> removeAuthenticator(
    SteamWebService web,
    String accessToken,
    String revocationCode,
    int scheme,
  ) async {
    final url =
        '${ApiEndpoints.twoFactorRemoveAuthenticator}?access_token=$accessToken';
    final responseBody = await web.postRequest(
      url,
      body: {
        'revocation_code': revocationCode,
        'revocation_reason': '1',
        'steamguard_scheme': scheme.toString(),
      },
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;
    return response['success'] == true;
  }
}
