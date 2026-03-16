import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sda_flutter/core/models/steam_guard_account.dart';
import 'package:sda_flutter/core/models/session_data.dart';

void main() {
  group('SteamGuardAccount JSON serialization', () {
    test('round-trip serialization preserves all fields', () {
      final account = SteamGuardAccount(
        sharedSecret: 'dGVzdHNlY3JldA==',
        serialNumber: '12345',
        revocationCode: 'R12345',
        uri: 'otpauth://totp/Steam:testuser',
        serverTime: 1700000000,
        accountName: 'testuser',
        tokenGid: 'gid123',
        identitySecret: 'aWRlbnRpdHk=',
        secret1: 'c2VjcmV0MQ==',
        status: 1,
        deviceId: 'android:12345678-1234-1234-1234-123456789012',
        phoneNumberHint: '42',
        confirmType: 2,
        fullyEnrolled: true,
        session: SessionData(
          steamID: 76561198123456789,
          accessToken: 'access_token_here',
          refreshToken: 'refresh_token_here',
          sessionID: 'abcdef1234567890abcdef1234567890',
        ),
      );

      final jsonMap = account.toJson();
      final jsonStr = json.encode(jsonMap);
      final decoded = SteamGuardAccount.fromJson(json.decode(jsonStr));

      expect(decoded.sharedSecret, equals('dGVzdHNlY3JldA=='));
      expect(decoded.serialNumber, equals('12345'));
      expect(decoded.revocationCode, equals('R12345'));
      expect(decoded.accountName, equals('testuser'));
      expect(decoded.identitySecret, equals('aWRlbnRpdHk='));
      expect(decoded.deviceId,
          equals('android:12345678-1234-1234-1234-123456789012'));
      expect(decoded.fullyEnrolled, isTrue);
      expect(decoded.status, equals(1));
      expect(decoded.session, isNotNull);
      expect(decoded.session!.steamID, equals(76561198123456789));
      expect(decoded.session!.accessToken, equals('access_token_here'));
    });

    test('JSON keys match C# maFile format exactly', () {
      final account = SteamGuardAccount(
        sharedSecret: 'abc',
        accountName: 'test',
        fullyEnrolled: false,
      );

      final jsonMap = account.toJson();
      // Verify exact C# JSON key names
      expect(jsonMap.containsKey('shared_secret'), isTrue);
      expect(jsonMap.containsKey('serial_number'), isTrue);
      expect(jsonMap.containsKey('revocation_code'), isTrue);
      expect(jsonMap.containsKey('server_time'), isTrue);
      expect(jsonMap.containsKey('account_name'), isTrue);
      expect(jsonMap.containsKey('token_gid'), isTrue);
      expect(jsonMap.containsKey('identity_secret'), isTrue);
      expect(jsonMap.containsKey('secret_1'), isTrue);
      expect(jsonMap.containsKey('device_id'), isTrue);
      expect(jsonMap.containsKey('phone_number_hint'), isTrue);
      expect(jsonMap.containsKey('confirm_type'), isTrue);
      expect(jsonMap.containsKey('fully_enrolled'), isTrue);
      expect(jsonMap.containsKey('Session'), isTrue);
    });

    test('deserializes from C#-compatible JSON format', () {
      const maFileJson = '''
      {
        "shared_secret": "AAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "serial_number": "SN-12345",
        "revocation_code": "R99999",
        "uri": "otpauth://totp/Steam:myaccount",
        "server_time": 1700000000,
        "account_name": "myaccount",
        "token_gid": "gid-abc",
        "identity_secret": "BBBBBBBBBBBBBBBBBBBBBBBBBBBB",
        "secret_1": "CCCCCCCCCCCCCCCC",
        "status": 1,
        "device_id": "android:abcdefgh-1234-5678-9012-abcdefghijkl",
        "phone_number_hint": "56",
        "confirm_type": 2,
        "fully_enrolled": true,
        "Session": {
          "SteamID": 76561198000000000,
          "AccessToken": "eyJhbGciOiJIUzI1NiJ9.test.sig",
          "RefreshToken": "eyJhbGciOiJIUzI1NiJ9.refresh.sig",
          "SessionID": "0123456789abcdef0123456789abcdef"
        }
      }
      ''';

      final account = SteamGuardAccount.fromJson(json.decode(maFileJson));
      expect(account.sharedSecret, equals('AAAAAAAAAAAAAAAAAAAAAAAAAAAA'));
      expect(account.accountName, equals('myaccount'));
      expect(account.fullyEnrolled, isTrue);
      expect(account.session, isNotNull);
      expect(account.session!.steamID, equals(76561198000000000));
    });
  });

  group('SessionData', () {
    test('generateSessionID returns 32-char hex string', () {
      final id = SessionData.generateSessionID();
      expect(id.length, equals(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });

    test('getSteamLoginSecure returns correct format', () {
      final session = SessionData(
        steamID: 76561198123456789,
        accessToken: 'mytoken123',
      );
      expect(session.getSteamLoginSecure(),
          equals('76561198123456789%7C%7Cmytoken123'));
    });

    test('getCookieMap includes all required cookies', () {
      final session = SessionData(
        steamID: 76561198123456789,
        accessToken: 'token',
        sessionID: 'sessid',
      );
      final cookies = session.getCookieMap();
      expect(cookies.containsKey('steamLoginSecure'), isTrue);
      expect(cookies.containsKey('sessionid'), isTrue);
      expect(cookies.containsKey('mobileClient'), isTrue);
      expect(cookies.containsKey('mobileClientVersion'), isTrue);
      expect(cookies['mobileClient'], equals('android'));
      expect(cookies['mobileClientVersion'], equals('777777 3.6.4'));
    });
  });
}
