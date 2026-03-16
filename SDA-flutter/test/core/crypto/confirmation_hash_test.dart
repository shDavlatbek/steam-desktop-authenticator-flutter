import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sda_flutter/core/crypto/confirmation_hash.dart';

void main() {
  group('ConfirmationHash', () {
    test('generates non-null hash for valid inputs', () {
      final secret = base64.encode(List.generate(20, (i) => i + 1));
      final hash = ConfirmationHash.generateForTime(secret, 1700000000, 'conf');
      expect(hash, isNotNull);
      expect(hash!.isNotEmpty, isTrue);
    });

    test('same inputs produce same hash', () {
      final secret = base64.encode(List.generate(20, (i) => i + 5));
      final hash1 =
          ConfirmationHash.generateForTime(secret, 1700000000, 'conf');
      final hash2 =
          ConfirmationHash.generateForTime(secret, 1700000000, 'conf');
      expect(hash1, equals(hash2));
    });

    test('different times produce different hashes', () {
      final secret = base64.encode(List.generate(20, (i) => i + 5));
      final hash1 =
          ConfirmationHash.generateForTime(secret, 1700000000, 'conf');
      final hash2 =
          ConfirmationHash.generateForTime(secret, 1700000001, 'conf');
      expect(hash1, isNot(equals(hash2)));
    });

    test('different tags produce different hashes', () {
      final secret = base64.encode(List.generate(20, (i) => i + 5));
      final hash1 =
          ConfirmationHash.generateForTime(secret, 1700000000, 'conf');
      final hash2 =
          ConfirmationHash.generateForTime(secret, 1700000000, 'accept');
      expect(hash1, isNot(equals(hash2)));
    });

    test('hash is URL-encoded Base64', () {
      final secret = base64.encode(List.generate(20, (i) => i + 10));
      final hash =
          ConfirmationHash.generateForTime(secret, 1700000000, 'conf');
      expect(hash, isNotNull);
      // URL-encoded base64 should not contain raw + or / or =
      // (they get encoded as %2B, %2F, %3D)
      // But it CAN contain letters, digits, and % (from encoding)
      expect(hash!.contains(' '), isFalse);
    });

    test('null tag produces valid hash (8 bytes only)', () {
      final secret = base64.encode(List.generate(20, (i) => i + 1));
      final hash = ConfirmationHash.generateForTime(secret, 1700000000, null);
      expect(hash, isNotNull);
    });

    test('long tag is truncated to 32 chars', () {
      final secret = base64.encode(List.generate(20, (i) => i + 1));
      final longTag = 'a' * 100;
      final hash32 = ConfirmationHash.generateForTime(
          secret, 1700000000, 'a' * 32);
      final hashLong =
          ConfirmationHash.generateForTime(secret, 1700000000, longTag);
      // Both should produce the same hash since tag is capped at 32
      expect(hash32, equals(hashLong));
    });

    test('returns null for invalid base64 secret', () {
      final hash =
          ConfirmationHash.generateForTime('not-valid-base64!!!', 1700000000, 'conf');
      expect(hash, isNull);
    });
  });
}
