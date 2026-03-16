import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Generates confirmation hashes for Steam trade/market confirmations.
/// Direct port of SteamGuardAccount._generateConfirmationHashForTime() from C#.
class ConfirmationHash {
  /// Generates an HMAC-SHA1 hash for confirmation requests.
  ///
  /// [identitySecret] - Base64-encoded identity secret from maFile.
  /// [time] - Unix timestamp (Steam server time).
  /// [tag] - Operation tag (e.g., "conf", "accept", "reject").
  ///
  /// Returns URL-encoded Base64 hash string, or null on error.
  static String? generateForTime(String identitySecret, int time, String? tag) {
    final Uint8List decode;
    try {
      decode = base64.decode(identitySecret);
    } catch (_) {
      return null;
    }

    // Calculate total array size: 8 bytes for time + tag bytes (max 32)
    int n2 = 8;
    if (tag != null) {
      if (tag.length > 32) {
        n2 = 8 + 32;
      } else {
        n2 = 8 + tag.length;
      }
    }

    final array = Uint8List(n2);

    // Write time as 8-byte big-endian (same loop as C#)
    int timeVal = time;
    int n3 = 8;
    while (true) {
      final n4 = n3 - 1;
      if (n3 <= 0) break;
      array[n4] = timeVal & 0xFF;
      timeVal >>= 8;
      n3 = n4;
    }

    // Append tag bytes
    if (tag != null) {
      final tagBytes = utf8.encode(tag);
      final copyLen = n2 - 8;
      for (int i = 0; i < copyLen; i++) {
        array[8 + i] = tagBytes[i];
      }
    }

    try {
      final hmac = Hmac(sha1, decode);
      final hashedData = hmac.convert(array).bytes;
      final encodedData = base64.encode(hashedData);
      return Uri.encodeComponent(encodedData);
    } catch (_) {
      return null;
    }
  }
}
