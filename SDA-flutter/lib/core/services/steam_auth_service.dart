import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Handles Steam web authentication flows (login, RSA encryption, guard codes).
///
/// Replaces the SteamKit2 dependency from the original C# project by using
/// Steam's public web authentication API directly.
class SteamAuthService {
  final SteamWebService _web;

  SteamAuthService(this._web);

  /// Fetches the RSA public key that Steam uses to encrypt login passwords for
  /// the given [accountName].
  ///
  /// Returns a [Map] with keys `'publickey_mod'`, `'publickey_exp'`, and
  /// `'timestamp'`.
  Future<Map<String, String>> getPasswordRsaPublicKey(
    String accountName,
  ) async {
    final url =
        '${ApiEndpoints.authGetPasswordRsaPublicKey}?account_name=$accountName';
    final responseBody = await _web.getRequest(url);
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;

    return {
      'publickey_mod': response['publickey_mod'] as String,
      'publickey_exp': response['publickey_exp'] as String,
      'timestamp': response['timestamp'] as String,
    };
  }

  /// RSA-encrypts [password] using the public key components returned by
  /// [getPasswordRsaPublicKey].
  ///
  /// [modHex] and [expHex] are hexadecimal strings representing the RSA
  /// modulus and exponent respectively.
  ///
  /// Returns the encrypted password as a Base64-encoded string.
  String encryptPassword(String password, String modHex, String expHex) {
    final modulus = BigInt.parse(modHex, radix: 16);
    final exponent = BigInt.parse(expHex, radix: 16);

    final rsaPublicKey = RSAPublicKey(modulus, exponent);

    final encryptor = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));

    final input = Uint8List.fromList(utf8.encode(password));
    final encrypted = encryptor.process(input);

    return base64Encode(encrypted);
  }

  /// Begins a new credential-based authentication session with Steam.
  ///
  /// [accountName] - The user's Steam account name.
  /// [encryptedPassword] - The password encrypted via [encryptPassword].
  /// [rsaTimestamp] - The timestamp returned with the RSA public key.
  ///
  /// Returns a [Map] containing `'client_id'`, `'request_id'`, `'steamid'`,
  /// `'allowed_confirmations'`, and `'interval'`.
  Future<Map<String, dynamic>> beginAuthSession(
    String accountName,
    String encryptedPassword,
    String rsaTimestamp,
  ) async {
    final responseBody = await _web.postRequest(
      ApiEndpoints.authBeginSessionViaCredentials,
      body: {
        'account_name': accountName,
        'encrypted_password': encryptedPassword,
        'encryption_timestamp': rsaTimestamp,
        'persistence': '1',
        'platform_type': '3', // MobileApp
      },
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;

    return {
      'client_id': response['client_id'].toString(),
      'request_id': response['request_id'] as String,
      'steamid': response['steamid'].toString(),
      'allowed_confirmations': response['allowed_confirmations'],
      'interval': response['interval'],
    };
  }

  /// Polls the status of an ongoing authentication session.
  ///
  /// Returns a [Map] containing `'access_token'`, `'refresh_token'`,
  /// `'account_name'`, and `'new_client_id'` once the session is approved.
  Future<Map<String, dynamic>> pollAuthSessionStatus(
    String clientId,
    String requestId,
  ) async {
    final responseBody = await _web.postRequest(
      ApiEndpoints.authPollSessionStatus,
      body: {
        'client_id': clientId,
        'request_id': requestId,
      },
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;

    return {
      'access_token': response['access_token'] as String?,
      'refresh_token': response['refresh_token'] as String?,
      'account_name': response['account_name'] as String?,
      'new_client_id': response['new_client_id']?.toString(),
    };
  }

  /// Submits a Steam Guard code (email or TOTP) to an active auth session.
  ///
  /// [codeType] values:
  ///   - `2` = email code
  ///   - `3` = TOTP code (authenticator app)
  Future<void> updateWithSteamGuardCode(
    String clientId,
    String steamId,
    String code,
    int codeType,
  ) async {
    await _web.postRequest(
      ApiEndpoints.authUpdateWithSteamGuardCode,
      body: {
        'client_id': clientId,
        'steamid': steamId,
        'code': code,
        'code_type': codeType.toString(),
      },
    );
  }
}
