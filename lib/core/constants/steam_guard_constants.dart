import 'dart:typed_data';

class SteamGuardConstants {
  /// The character set used for Steam Guard TOTP codes.
  /// Maps to ASCII: "23456789BCDFGHJKMNPQRTVWXY"
  static final Uint8List steamGuardCodeTranslations = Uint8List.fromList([
    50, 51, 52, 53, 54, 55, 56, 57, // 2-9
    66, 67, 68, 70, 71, 72, 74, 75, // B,C,D,F,G,H,J,K
    77, 78, 80, 81, 82, 84, 86, 87, // M,N,P,Q,R,T,V,W
    88, 89, // X,Y
  ]);

  /// TOTP time period in seconds.
  static const int totpPeriod = 30;

  /// Length of generated Steam Guard codes.
  static const int totpCodeLength = 5;

  /// User agent string that mimics the Steam mobile app.
  static const String mobileAppUserAgent =
      'Dalvik/2.1.0 (Linux; U; Android 9; Valve Steam App Version/3)';

  /// Mobile client identifier for cookies.
  static const String mobileClient = 'android';

  /// Mobile client version for cookies.
  static const String mobileClientVersion = '777777 3.6.4';
}
