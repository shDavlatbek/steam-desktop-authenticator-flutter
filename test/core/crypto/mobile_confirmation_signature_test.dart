import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sda_flutter/core/crypto/mobile_confirmation_signature.dart';

/// Rebuilds the 18-byte message independently of the implementation so the
/// byte layout is pinned by the test rather than asserted against itself.
Uint8List expectedMessage(int version, BigInt clientId, BigInt steamId) {
  final out = Uint8List(18);
  final mask = BigInt.from(0xFF);

  out[0] = version & 0xFF;
  out[1] = (version >> 8) & 0xFF;
  for (int i = 0; i < 8; i++) {
    out[2 + i] = ((clientId >> (8 * i)) & mask).toInt();
    out[10 + i] = ((steamId >> (8 * i)) & mask).toInt();
  }
  return out;
}

void main() {
  final secret = base64.encode(List.generate(20, (i) => i + 1));
  const version = 1;
  const clientId = '2207813151333862682';
  const steamId = '76561198123456789';

  group('MobileConfirmationSignature', () {
    test('matches an independently constructed HMAC-SHA256', () {
      final message = expectedMessage(
        version,
        BigInt.parse(clientId),
        BigInt.parse(steamId),
      );
      final expected =
          Hmac(sha256, base64.decode(secret)).convert(message).bytes;

      final actual = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: version,
        clientId: clientId,
        steamId: steamId,
      );

      expect(actual, equals(expected));
    });

    test('produces a 32-byte signature', () {
      final signature = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: version,
        clientId: clientId,
        steamId: steamId,
      );
      expect(signature.length, 32);
    });

    test('is deterministic', () {
      Uint8List sign() => MobileConfirmationSignature.generate(
            sharedSecret: secret,
            version: version,
            clientId: clientId,
            steamId: steamId,
          );
      expect(sign(), equals(sign()));
    });

    test('version, client id and steam id each change the signature', () {
      final base = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: version,
        clientId: clientId,
        steamId: steamId,
      );

      final otherVersion = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: 2,
        clientId: clientId,
        steamId: steamId,
      );
      final otherClient = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: version,
        clientId: '2207813151333862683',
        steamId: steamId,
      );
      final otherSteamId = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: version,
        clientId: clientId,
        steamId: '76561198123456790',
      );

      expect(otherVersion, isNot(equals(base)));
      expect(otherClient, isNot(equals(base)));
      expect(otherSteamId, isNot(equals(base)));
    });

    test('keeps full precision for uint64 values beyond int64', () {
      // 2^64-1 exceeds Dart's signed int range; going through ByteData's
      // setUint64 or a double would corrupt these bytes.
      const maxUint64 = '18446744073709551615';
      final signature = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: 0xFFFF,
        clientId: maxUint64,
        steamId: maxUint64,
      );

      final message = expectedMessage(
        0xFFFF,
        BigInt.parse(maxUint64),
        BigInt.parse(maxUint64),
      );
      final expected =
          Hmac(sha256, base64.decode(secret)).convert(message).bytes;

      expect(signature, equals(expected));
    });

    test('generateBase64 encodes the raw signature', () {
      final raw = MobileConfirmationSignature.generate(
        sharedSecret: secret,
        version: version,
        clientId: clientId,
        steamId: steamId,
      );
      final encoded = MobileConfirmationSignature.generateBase64(
        sharedSecret: secret,
        version: version,
        clientId: clientId,
        steamId: steamId,
      );

      expect(encoded, equals(base64.encode(raw)));
    });

    test('unescapes JSON-escaped secrets like SteamTotp does', () {
      final withSlashes = base64.encode(List.generate(20, (i) => i * 7));
      if (!withSlashes.contains('/')) return; // nothing to unescape

      final escaped = withSlashes.replaceAll('/', r'\/');
      expect(
        MobileConfirmationSignature.generate(
          sharedSecret: escaped,
          version: version,
          clientId: clientId,
          steamId: steamId,
        ),
        equals(MobileConfirmationSignature.generate(
          sharedSecret: withSlashes,
          version: version,
          clientId: clientId,
          steamId: steamId,
        )),
      );
    });

    test('rejects an empty secret', () {
      expect(
        () => MobileConfirmationSignature.generate(
          sharedSecret: '',
          version: version,
          clientId: clientId,
          steamId: steamId,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a version wider than uint16', () {
      expect(
        () => MobileConfirmationSignature.generate(
          sharedSecret: secret,
          version: 0x10000,
          clientId: clientId,
          steamId: steamId,
        ),
        throwsArgumentError,
      );
    });

    test('rejects identifiers that are not uint64', () {
      expect(
        () => MobileConfirmationSignature.generate(
          sharedSecret: secret,
          version: version,
          clientId: 'not-a-number',
          steamId: steamId,
        ),
        throwsArgumentError,
      );
      expect(
        () => MobileConfirmationSignature.generate(
          sharedSecret: secret,
          version: version,
          clientId: '-1',
          steamId: steamId,
        ),
        throwsArgumentError,
      );
      expect(
        () => MobileConfirmationSignature.generate(
          sharedSecret: secret,
          version: version,
          clientId: '18446744073709551616', // 2^64
          steamId: steamId,
        ),
        throwsArgumentError,
      );
    });
  });
}
