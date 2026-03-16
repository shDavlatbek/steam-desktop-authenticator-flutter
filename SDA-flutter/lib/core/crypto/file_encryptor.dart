import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypts and decrypts maFile data using AES-256-CBC with PBKDF2 key derivation.
/// Direct port of FileEncryptor.cs from C#.
///
/// Encryption scheme:
/// - PBKDF2 with 50,000 iterations (SHA1) to derive 32-byte key from password + salt
/// - AES-256 in CBC mode with PKCS7 padding
/// - 8-byte random salt, 16-byte random IV
class FileEncryptor {
  static const int _pbkdf2Iterations = 50000;
  static const int _saltLength = 8;
  static const int _keySizeBytes = 32;
  static const int _ivLength = 16;

  /// Returns an 8-byte cryptographically random salt as Base64 string.
  static String getRandomSalt() {
    final salt = _getRandomBytes(_saltLength);
    return base64.encode(salt);
  }

  /// Returns a 16-byte cryptographically random IV as Base64 string.
  static String getInitializationVector() {
    final iv = _getRandomBytes(_ivLength);
    return base64.encode(iv);
  }

  /// Derives a 32-byte encryption key from password and salt using PBKDF2-SHA1.
  static Uint8List _getEncryptionKey(String password, String salt) {
    if (password.isEmpty) throw ArgumentError('Password is empty');
    if (salt.isEmpty) throw ArgumentError('Salt is empty');

    final saltBytes = base64.decode(salt);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(saltBytes),
        _pbkdf2Iterations,
        _keySizeBytes,
      ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts plaintext using AES-256-CBC and returns Base64-encoded ciphertext.
  ///
  /// [password] - User's encryption password.
  /// [passwordSalt] - Base64-encoded 8-byte salt.
  /// [iv] - Base64-encoded 16-byte initialization vector.
  /// [plaintext] - The data to encrypt.
  static String encryptData(
      String password, String passwordSalt, String iv, String plaintext) {
    if (password.isEmpty) throw ArgumentError('Password is empty');
    if (passwordSalt.isEmpty) throw ArgumentError('Salt is empty');
    if (iv.isEmpty) throw ArgumentError('Initialization Vector is empty');
    if (plaintext.isEmpty) throw ArgumentError('Plaintext data is empty');

    final key = _getEncryptionKey(password, passwordSalt);
    final ivBytes = Uint8List.fromList(base64.decode(iv));

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), ivBytes),
          null,
        ),
      );

    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final ciphertext = cipher.process(plaintextBytes);
    return base64.encode(ciphertext);
  }

  /// Decrypts Base64-encoded ciphertext using AES-256-CBC.
  /// Returns plaintext string, or null if the password is wrong.
  ///
  /// [password] - User's encryption password.
  /// [passwordSalt] - Base64-encoded 8-byte salt.
  /// [iv] - Base64-encoded 16-byte initialization vector.
  /// [encryptedData] - Base64-encoded ciphertext.
  static String? decryptData(
      String password, String passwordSalt, String iv, String encryptedData) {
    if (password.isEmpty) throw ArgumentError('Password is empty');
    if (passwordSalt.isEmpty) throw ArgumentError('Salt is empty');
    if (iv.isEmpty) throw ArgumentError('Initialization Vector is empty');
    if (encryptedData.isEmpty) throw ArgumentError('Encrypted data is empty');

    final key = _getEncryptionKey(password, passwordSalt);
    final ivBytes = Uint8List.fromList(base64.decode(iv));
    final ciphertext = Uint8List.fromList(base64.decode(encryptedData));

    try {
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          PaddedBlockCipherParameters(
            ParametersWithIV(KeyParameter(key), ivBytes),
            null,
          ),
        );

      final plaintext = cipher.process(ciphertext);
      return utf8.decode(plaintext);
    } catch (_) {
      // Bad password yields a bad key → decryption error
      return null;
    }
  }

  static Uint8List _getRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }
}
