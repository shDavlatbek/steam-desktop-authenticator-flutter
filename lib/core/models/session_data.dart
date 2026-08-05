import 'dart:convert';
import 'dart:math';

class SessionData {
  int steamID;
  String? accessToken;
  String? refreshToken;
  String? sessionID;

  SessionData({
    this.steamID = 0,
    this.accessToken,
    this.refreshToken,
    this.sessionID,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      steamID: json['SteamID'] as int? ?? 0,
      accessToken: json['AccessToken'] as String?,
      refreshToken: json['RefreshToken'] as String?,
      sessionID: json['SessionID'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SteamID': steamID,
      'AccessToken': accessToken,
      'RefreshToken': refreshToken,
      'SessionID': sessionID,
    };
  }

  /// Checks whether the access token has expired by examining the JWT exp claim.
  bool isAccessTokenExpired() {
    if (accessToken == null || accessToken!.isEmpty) return true;
    final exp = _getTokenExpirationTime(accessToken!);
    if (exp == null) return true;
    return DateTime.now().toUtc().isAfter(exp);
  }

  /// Checks whether the refresh token has expired by examining the JWT exp claim.
  bool isRefreshTokenExpired() {
    if (refreshToken == null || refreshToken!.isEmpty) return true;
    final exp = _getTokenExpirationTime(refreshToken!);
    if (exp == null) return true;
    return DateTime.now().toUtc().isAfter(exp);
  }

  /// Checks whether the refresh token is within 24 hours of expiring.
  bool isRefreshTokenAboutToExpire() {
    if (refreshToken == null || refreshToken!.isEmpty) return true;
    final exp = _getTokenExpirationTime(refreshToken!);
    if (exp == null) return true;
    final now = DateTime.now().toUtc();
    final threshold = exp.subtract(const Duration(hours: 24));
    return now.isAfter(threshold);
  }

  /// Refreshes the access token by decoding the provided token's claims.
  /// This handles only the local token parsing logic; the actual HTTP renewal
  /// call belongs in a service layer.
  ///
  /// If [allowRenewal] is false this is a no-op.
  void refreshAccessToken(bool allowRenewal) {
    if (!allowRenewal) return;
    // Token renewal requires an HTTP call which belongs in the service layer.
    // This method is a placeholder for local pre-/post-processing around that call.
  }

  /// Returns a map of cookie key-value pairs suitable for both
  /// store.steampowered.com and steamcommunity.com domains.
  /// Matches C# SessionData.GetCookies() exactly.
  Map<String, String> getCookieMap() {
    sessionID ??= generateSessionID();
    return {
      'steamLoginSecure': getSteamLoginSecure(),
      'sessionid': sessionID!,
      'mobileClient': 'android',
      'mobileClientVersion': '777777 3.6.4',
    };
  }

  /// Returns the steamLoginSecure cookie value in the format
  /// "{SteamID}%7C%7C{AccessToken}".
  String getSteamLoginSecure() {
    return '$steamID%7C%7C${accessToken ?? ''}';
  }

  /// Generates a random 32-character lowercase hex string for use as a session ID.
  static String generateSessionID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Decodes a JWT token's payload and extracts the 'exp' field as a [DateTime].
  /// Returns null if the token is malformed or missing the exp claim.
  ///
  /// Handles base64url encoding: replaces '-' with '+', '_' with '/',
  /// and pads with '=' to a multiple of 4.
  static DateTime? _getTokenExpirationTime(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      String payload = parts[1];
      // Convert base64url to standard base64
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      // Pad to multiple of 4
      final remainder = payload.length % 4;
      if (remainder != 0) {
        payload += '=' * (4 - remainder);
      }

      final decoded = utf8.decode(base64Decode(payload));
      final Map<String, dynamic> claims = jsonDecode(decoded);

      final exp = claims['exp'];
      if (exp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(
        (exp as int) * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
