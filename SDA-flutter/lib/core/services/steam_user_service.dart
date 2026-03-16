import 'dart:convert';

import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Handles IUserAccountService API calls.
class SteamUserService {
  /// Retrieves the country code associated with the given Steam account.
  ///
  /// Returns the ISO 3166-1 alpha-2 country code (e.g. "US", "GB").
  static Future<String> getUserCountry(
    SteamWebService web,
    String accessToken,
    int steamId,
  ) async {
    final url =
        '${ApiEndpoints.userGetCountry}?access_token=$accessToken';
    final responseBody = await web.postRequest(
      url,
      body: {
        'steamid': steamId.toString(),
      },
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;
    return response['country'] as String;
  }
}
