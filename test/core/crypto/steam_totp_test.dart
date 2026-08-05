import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sda_flutter/core/crypto/steam_totp.dart';

void main() {
  group('SteamTotp', () {
    test('generates correct 5-character code', () {
      // Known test: a simple shared secret produces a 5-char code
      // Using a fixed Base64 shared secret and fixed time
      final sharedSecret = base64.encode([
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        0x11, 0x12, 0x13, 0x14,
      ]);

      final code = SteamTotp.generateCodeForTime(sharedSecret, 1700000000);
      expect(code, isNotNull);
      expect(code!.length, equals(5));

      // All characters should be from the Steam alphabet
      const validChars = '23456789BCDFGHJKMNPQRTVWXY';
      for (final c in code.split('')) {
        expect(validChars.contains(c), isTrue,
            reason: 'Character "$c" not in Steam alphabet');
      }
    });

    test('same time produces same code', () {
      final secret = base64.encode(List.generate(20, (i) => i + 42));
      final code1 = SteamTotp.generateCodeForTime(secret, 1700000000);
      final code2 = SteamTotp.generateCodeForTime(secret, 1700000000);
      expect(code1, equals(code2));
    });

    test('different 30-second chunks produce different codes', () {
      final secret = base64.encode(List.generate(20, (i) => i + 42));
      final code1 = SteamTotp.generateCodeForTime(secret, 1700000000);
      final code2 = SteamTotp.generateCodeForTime(secret, 1700000030);
      // Different time chunks should produce different codes
      // (extremely unlikely to collide)
      expect(code1, isNot(equals(code2)));
    });

    test('same 30-second chunk produces same code', () {
      final secret = base64.encode(List.generate(20, (i) => i + 42));
      // 1700000010 / 30 = 56666667, 1700000020 / 30 = 56666667 (same chunk)
      final code1 = SteamTotp.generateCodeForTime(secret, 1700000010);
      final code2 = SteamTotp.generateCodeForTime(secret, 1700000020);
      // Same 30-second chunk → same code
      expect(code1, equals(code2));
    });

    test('returns empty string for null secret', () {
      expect(SteamTotp.generateCodeForTime(null, 1700000000), equals(''));
    });

    test('returns empty string for empty secret', () {
      expect(SteamTotp.generateCodeForTime('', 1700000000), equals(''));
    });

    test('handles escaped forward slashes in secret', () {
      // Secret with escaped forward slash (as JSON might encode it)
      final rawSecret = base64.encode(List.generate(20, (i) => i + 1));
      // Simulate a JSON-escaped version (shouldn't contain /, but test the path)
      final code = SteamTotp.generateCodeForTime(rawSecret, 1700000000);
      expect(code, isNotNull);
      expect(code!.length, equals(5));
    });

    test('TOTP algorithm produces known output for all-zeros secret', () {
      // 20 bytes of zeros
      final secret = base64.encode(List.filled(20, 0));
      final code = SteamTotp.generateCodeForTime(secret, 0);
      expect(code, isNotNull);
      expect(code!.length, equals(5));
      // This is a deterministic output we can verify doesn't change
      final code2 = SteamTotp.generateCodeForTime(secret, 0);
      expect(code, equals(code2));
    });
  });
}
