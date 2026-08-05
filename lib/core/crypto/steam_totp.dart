import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../constants/steam_guard_constants.dart';

/// Generates Steam Guard TOTP codes.
/// Direct port of SteamGuardAccount.GenerateSteamGuardCodeForTime() from C#.
class SteamTotp {
  /// Generates a 5-character Steam Guard code for the given Unix timestamp.
  ///
  /// Algorithm:
  /// 1. Base64-decode SharedSecret
  /// 2. Divide time by 30 -> 8-byte big-endian array
  /// 3. HMAC-SHA1(sharedSecretBytes, timeArray) -> 20-byte hash
  /// 4. Dynamic binary code extraction
  /// 5. Map to Steam's custom 26-character alphabet
  static String? generateCodeForTime(String? sharedSecret, int time) {
    if (sharedSecret == null || sharedSecret.isEmpty) {
      return '';
    }

    // Port of: Regex.Unescape(this.SharedSecret)
    // Handle JSON escape sequences (mainly \/ -> /)
    final unescaped = sharedSecret.replaceAll(r'\/', '/');
    final Uint8List sharedSecretArray;
    try {
      sharedSecretArray = base64.decode(unescaped);
    } catch (_) {
      return null;
    }

    // Divide time by 30-second period
    int timeChunk = time ~/ 30;

    // Convert to 8-byte big-endian array
    final timeArray = Uint8List(8);
    for (int i = 8; i > 0; i--) {
      timeArray[i - 1] = timeChunk & 0xFF;
      timeChunk >>= 8;
    }

    // HMAC-SHA1
    final hmac = Hmac(sha1, sharedSecretArray);
    final hashedData = hmac.convert(timeArray).bytes;

    // Dynamic binary code extraction
    final codeArray = Uint8List(5);
    try {
      final b = hashedData[19] & 0xF;
      int codePoint = (hashedData[b] & 0x7F) << 24 |
          (hashedData[b + 1] & 0xFF) << 16 |
          (hashedData[b + 2] & 0xFF) << 8 |
          (hashedData[b + 3] & 0xFF);

      final translations = SteamGuardConstants.steamGuardCodeTranslations;
      for (int i = 0; i < 5; ++i) {
        codeArray[i] = translations[codePoint % translations.length];
        codePoint ~/= translations.length;
      }
    } catch (_) {
      return null;
    }

    return utf8.decode(codeArray);
  }
}
