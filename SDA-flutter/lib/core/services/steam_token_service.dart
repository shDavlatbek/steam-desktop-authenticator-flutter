import 'dart:convert';

import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Handles refreshing Steam access tokens using a long-lived refresh token.
///
/// Port of SessionData.RefreshAccessToken() from the original SDA C# project.
class SteamTokenService {
  /// Requests a new access token (and optionally a new refresh token) from
  /// the Steam authentication service.
  ///
  /// [web] - HTTP client to use for the request.
  /// [refreshToken] - The current refresh token.
  /// [steamId] - The user's Steam ID (64-bit).
  /// [allowRenewal] - When `true`, a new refresh token may be returned as well.
  ///
  /// Returns a [Map] containing `'access_token'` and, when renewal was
  /// requested and granted, `'refresh_token'`.
  static Future<Map<String, String>> refreshAccessToken(
    SteamWebService web,
    String refreshToken,
    int steamId, {
    bool allowRenewal = false,
  }) async {
    final responseBody = await web.postRequest(
      ApiEndpoints.authGenerateAccessTokenForApp,
      body: {
        'refresh_token': refreshToken,
        'steamid': steamId.toString(),
        'renewal_type': allowRenewal ? '1' : '0',
      },
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;

    final result = <String, String>{
      'access_token': response['access_token'] as String,
    };

    if (response.containsKey('refresh_token')) {
      result['refresh_token'] = response['refresh_token'] as String;
    }

    return result;
  }
}
