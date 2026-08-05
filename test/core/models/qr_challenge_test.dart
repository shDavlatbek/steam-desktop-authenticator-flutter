import 'package:flutter_test/flutter_test.dart';
import 'package:sda_flutter/core/models/qr_challenge.dart';

void main() {
  group('QrChallenge.tryParse', () {
    test('parses a live challenge URL', () {
      final challenge =
          QrChallenge.tryParse('https://s.team/q/1/2207813151333862682');

      expect(challenge, isNotNull);
      expect(challenge!.version, 1);
      expect(challenge.clientId, '2207813151333862682');
    });

    test('keeps the client id as an exact string', () {
      // Round-tripping through a Dart int would be lossy on some platforms.
      const clientId = '18446744073709551615';
      final challenge = QrChallenge.tryParse('https://s.team/q/1/$clientId');

      expect(challenge!.clientId, clientId);
    });

    test('accepts http and a trailing query string', () {
      expect(QrChallenge.tryParse('http://s.team/q/1/123')!.clientId, '123');
      expect(
        QrChallenge.tryParse('https://s.team/q/2/456?t=abc')!.version,
        2,
      );
    });

    test('ignores surrounding whitespace from a scanner', () {
      final challenge =
          QrChallenge.tryParse('  https://s.team/q/1/123\n');
      expect(challenge!.clientId, '123');
    });

    test('returns null for non-Steam or malformed payloads', () {
      final rejected = [
        '',
        'https://example.com/q/1/123',
        'https://s.team/q/1',
        'https://s.team/q/abc/123',
        'https://steamcommunity.com/mobileconf/getlist',
        'otpauth://totp/Steam:username',
        'https://s.team.evil.com/q/1/123',
      ];

      for (final url in rejected) {
        expect(QrChallenge.tryParse(url), isNull, reason: 'should reject $url');
      }
    });

    test('compares by value', () {
      expect(
        QrChallenge.tryParse('https://s.team/q/1/123'),
        equals(const QrChallenge(version: 1, clientId: '123')),
      );
    });
  });
}
