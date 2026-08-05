// ignore_for_file: avoid_print
//
// Emits crypto test vectors as JSON, for cross-checking the Python port in
// telegram-bot/ against this implementation.
//
//   dart run tool/export_crypto_vectors.dart > telegram-bot/tests/fixtures/dart_vectors.json
//
// Every value here comes from the same code the app ships, so if a refactor
// changes any of it the Python test suite fails on the next run.

import 'dart:convert';

import 'package:sda_flutter/core/crypto/confirmation_hash.dart';
import 'package:sda_flutter/core/crypto/file_encryptor.dart';
import 'package:sda_flutter/core/crypto/mobile_confirmation_signature.dart';
import 'package:sda_flutter/core/crypto/steam_totp.dart';

/// Fixed, non-secret inputs. 20 bytes is the real length of a Steam secret.
const sharedSecret = 'AQIDBAUGBwgJCgsMDQ4PEBESExQ=';
const identitySecret = 'FBUWFxgZGhscHR4fICEiIyQlJic=';

void main() {
  final vectors = {
    'inputs': {
      'shared_secret': sharedSecret,
      'identity_secret': identitySecret,
    },
    'totp': [
      for (final time in [0, 1, 29, 30, 31, 1700000000, 1234567890, 2000000000])
        {
          'time': time,
          'code': SteamTotp.generateCodeForTime(sharedSecret, time),
        },
    ],
    'confirmation_hash': [
      for (final entry in [
        {'time': 1700000000, 'tag': 'conf'},
        {'time': 1700000000, 'tag': 'accept'},
        {'time': 1700000000, 'tag': 'reject'},
        {'time': 1234567890, 'tag': 'conf'},
        // Longer than the 32-byte cap, to pin the truncation.
        {'time': 1700000000, 'tag': 'a-very-long-tag-that-exceeds-the-limit-abcdef'},
      ])
        {
          'time': entry['time'],
          'tag': entry['tag'],
          'hash': ConfirmationHash.generateForTime(
              identitySecret, entry['time'] as int, entry['tag'] as String),
        },
    ],
    'mobile_signature': [
      for (final entry in [
        {'version': 1, 'client_id': '2207813151333862682', 'steam_id': '76561198123456789'},
        {'version': 2, 'client_id': '1', 'steam_id': '76561198123456789'},
        {'version': 0, 'client_id': '0', 'steam_id': '0'},
        // Full-width uint64s, where a narrower type would lose precision.
        {'version': 65535, 'client_id': '18446744073709551615', 'steam_id': '18446744073709551615'},
      ])
        {
          'version': entry['version'],
          'client_id': entry['client_id'],
          'steam_id': entry['steam_id'],
          'signature': MobileConfirmationSignature.generateBase64(
            sharedSecret: sharedSecret,
            version: entry['version'] as int,
            clientId: entry['client_id'] as String,
            steamId: entry['steam_id'] as String,
          ),
        },
    ],
    'file_encryption': _encryptionVectors(),
  };

  print(const JsonEncoder.withIndent('  ').convert(vectors));
}

List<Map<String, String>> _encryptionVectors() {
  // Fixed salt and IV so the ciphertext is reproducible across runs.
  const salt = 'AQIDBAUGBwg=';
  const iv = 'AQIDBAUGBwgJCgsMDQ4PEA==';

  const cases = [
    {'password': 'hunter2', 'plaintext': '{"shared_secret":"abc"}'},
    {'password': 'p@ssw0rd with spaces', 'plaintext': 'short'},
    {'password': 'unicode-ключ', 'plaintext': 'Ünïcödé påylöad 🎮'},
    // Exactly one AES block, to pin the PKCS7 padding behaviour.
    {'password': 'blocktest', 'plaintext': '0123456789abcdef'},
  ];

  return [
    for (final c in cases)
      {
        'password': c['password']!,
        'salt': salt,
        'iv': iv,
        'plaintext': c['plaintext']!,
        'ciphertext': FileEncryptor.encryptData(
            c['password']!, salt, iv, c['plaintext']!),
      },
  ];
}
