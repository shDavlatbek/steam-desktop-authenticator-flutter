import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Signs approval of another device's QR login attempt.
///
/// This has no counterpart in the original SDA C# project — it belongs to
/// Steam's newer QR login flow, where the mobile authenticator proves it holds
/// the account's TOTP secret by signing the pending session's identifiers.
///
/// The layout is fixed by Steam and matches the reference implementations in
/// DoctorMcKay/node-steam-session and dyc3/steamguard-cli:
///
/// ```
/// message (18 bytes, little-endian):
///   [0..1]   version    uint16
///   [2..9]   client_id  uint64
///   [10..17] steamid    uint64
/// signature = HMAC-SHA256(base64Decode(sharedSecret), message)
/// ```
///
/// Getting the byte order or field widths wrong yields a well-formed signature
/// that Steam silently rejects, so treat this like the other crypto files:
/// verify against the references rather than refactoring by intuition.
class MobileConfirmationSignature {
  static const int _messageLength = 18;

  /// Largest value representable in a uint64 field.
  static final BigInt _maxUint64 = (BigInt.one << 64) - BigInt.one;

  /// Produces the raw 32-byte HMAC-SHA256 signature.
  ///
  /// [clientId] and [steamId] are taken as strings because both are uint64 and
  /// lose precision as Dart ints on some platforms.
  ///
  /// Throws an [ArgumentError] if the secret is missing or malformed, or if
  /// either identifier is not a valid uint64.
  static Uint8List generate({
    required String sharedSecret,
    required int version,
    required String clientId,
    required String steamId,
  }) {
    if (sharedSecret.isEmpty) {
      throw ArgumentError('sharedSecret is required');
    }
    if (version < 0 || version > 0xFFFF) {
      throw ArgumentError.value(version, 'version', 'must fit in a uint16');
    }

    final Uint8List key;
    try {
      // Mirrors SteamTotp: maFiles may carry JSON-escaped secrets.
      key = base64.decode(sharedSecret.replaceAll(r'\/', '/'));
    } catch (_) {
      throw ArgumentError.value(
          sharedSecret, 'sharedSecret', 'is not valid base64');
    }

    final message = Uint8List(_messageLength);
    message[0] = version & 0xFF;
    message[1] = (version >> 8) & 0xFF;
    _writeUint64LE(message, 2, _parseUint64(clientId, 'clientId'));
    _writeUint64LE(message, 10, _parseUint64(steamId, 'steamId'));

    return Uint8List.fromList(Hmac(sha256, key).convert(message).bytes);
  }

  /// Convenience wrapper returning the signature base64-encoded, which is how
  /// Steam's form-encoded WebAPI expects a protobuf `bytes` field.
  static String generateBase64({
    required String sharedSecret,
    required int version,
    required String clientId,
    required String steamId,
  }) {
    return base64.encode(generate(
      sharedSecret: sharedSecret,
      version: version,
      clientId: clientId,
      steamId: steamId,
    ));
  }

  static BigInt _parseUint64(String value, String name) {
    final parsed = BigInt.tryParse(value.trim());
    if (parsed == null) {
      throw ArgumentError.value(value, name, 'is not an integer');
    }
    if (parsed.isNegative || parsed > _maxUint64) {
      throw ArgumentError.value(value, name, 'does not fit in a uint64');
    }
    return parsed;
  }

  /// Writes [value] as 8 little-endian bytes at [offset].
  ///
  /// Done via [BigInt] rather than [ByteData.setUint64] so that values above
  /// the signed-64-bit range stay exact and the code remains portable.
  static void _writeUint64LE(Uint8List out, int offset, BigInt value) {
    final mask = BigInt.from(0xFF);
    for (int i = 0; i < 8; i++) {
      out[offset + i] = ((value >> (8 * i)) & mask).toInt();
    }
  }
}
