import 'dart:convert';

import '../constants/api_endpoints.dart';
import 'steam_web_service.dart';

/// Details of a pending QR login, shown to the user before they approve it.
///
/// Mirrors CAuthentication_GetAuthSessionInfo_Response. Approving blind is how
/// people get phished, so every field here exists to be displayed.
class AuthSessionInfo {
  final String? ip;
  final String? geoloc;
  final String? city;
  final String? state;
  final String? country;
  final int? platformType;
  final String? deviceFriendlyName;
  final int version;

  /// EAuthSessionSecurityHistory: 1 means Steam has not seen this login
  /// pattern before.
  final int? loginHistory;

  /// True when the requesting device is somewhere the account normally isn't.
  final bool locationMismatch;

  final bool highUsageLogin;
  final int? requestedPersistence;

  const AuthSessionInfo({
    this.ip,
    this.geoloc,
    this.city,
    this.state,
    this.country,
    this.platformType,
    this.deviceFriendlyName,
    this.version = 1,
    this.loginHistory,
    this.locationMismatch = false,
    this.highUsageLogin = false,
    this.requestedPersistence,
  });

  factory AuthSessionInfo.fromJson(Map<String, dynamic> json) {
    return AuthSessionInfo(
      ip: json['ip'] as String?,
      geoloc: json['geoloc'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      platformType: json['platform_type'] as int?,
      deviceFriendlyName: json['device_friendly_name'] as String?,
      version: json['version'] as int? ?? 1,
      loginHistory: json['login_history'] as int?,
      locationMismatch: json['requestor_location_mismatch'] as bool? ?? false,
      highUsageLogin: json['high_usage_login'] as bool? ?? false,
      requestedPersistence: json['requested_persistence'] as int?,
    );
  }

  /// A displayable "City, State, Country" string, omitting missing parts.
  String get location {
    final parts = [city, state, country]
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }

  /// EAuthTokenPlatformType rendered for display.
  String get platformName {
    switch (platformType) {
      case 1:
        return 'Steam Client';
      case 2:
        return 'Web Browser';
      case 3:
        return 'Mobile App';
      default:
        return 'Unknown';
    }
  }

  /// True when Steam flagged anything unusual about this request.
  bool get isSuspicious => locationMismatch || loginHistory == 1;
}

/// Approves or denies QR login attempts made on other devices.
///
/// This is the role the official Steam mobile app plays when it scans a login
/// QR code. Both calls authenticate with an access token passed on the query
/// string, and that token must have been issued for platform type 3
/// (MobileApp) — a web-only token is rejected with EResult 15.
class SteamLoginApprovalService {
  /// Fetches metadata about the pending login identified by [clientId].
  static Future<AuthSessionInfo> getAuthSessionInfo(
    SteamWebService web,
    String accessToken,
    String clientId,
  ) async {
    final response = await web.postForResponse(
      _withAccessToken(ApiEndpoints.authGetAuthSessionInfo, accessToken),
      body: {'client_id': clientId},
    );

    if (!response.isSuccess) {
      throw LoginApprovalException(response.failureReason);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final body = json['response'] as Map<String, dynamic>?;
    if (body == null || body.isEmpty) {
      throw LoginApprovalException(
          'This login request no longer exists. It may have expired.');
    }

    return AuthSessionInfo.fromJson(body);
  }

  /// Approves ([confirm] true) or denies the pending login.
  ///
  /// [signature] is the base64-encoded HMAC from
  /// `MobileConfirmationSignature.generateBase64`. The response message is
  /// empty on success, so the outcome comes from the EResult header.
  static Future<void> submitMobileConfirmation(
    SteamWebService web,
    String accessToken, {
    required int version,
    required String clientId,
    required String steamId,
    required String signature,
    required bool confirm,
    int persistence = 1,
  }) async {
    final response = await web.postForResponse(
      _withAccessToken(
          ApiEndpoints.authUpdateWithMobileConfirmation, accessToken),
      body: {
        'version': version.toString(),
        'client_id': clientId,
        'steamid': steamId,
        'signature': signature,
        'confirm': confirm ? '1' : '0',
        'persistence': persistence.toString(),
      },
    );

    if (!response.isSuccess) {
      throw LoginApprovalException(response.failureReason);
    }
  }

  static String _withAccessToken(String url, String accessToken) =>
      '$url?access_token=${Uri.encodeQueryComponent(accessToken)}';
}

/// Thrown when Steam rejects an approval request.
class LoginApprovalException implements Exception {
  final String message;

  LoginApprovalException(this.message);

  @override
  String toString() => message;
}
