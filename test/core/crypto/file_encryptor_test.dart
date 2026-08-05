import 'package:flutter_test/flutter_test.dart';
import 'package:sda_flutter/core/crypto/file_encryptor.dart';

void main() {
  group('FileEncryptor', () {
    test('encrypt then decrypt returns original plaintext', () {
      const password = 'testpassword123';
      final salt = FileEncryptor.getRandomSalt();
      final iv = FileEncryptor.getInitializationVector();
      const plaintext = '{"shared_secret":"abc123","account_name":"testuser"}';

      final encrypted = FileEncryptor.encryptData(password, salt, iv, plaintext);
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(equals(plaintext)));

      final decrypted = FileEncryptor.decryptData(password, salt, iv, encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('wrong password returns null', () {
      const password = 'correctpassword';
      final salt = FileEncryptor.getRandomSalt();
      final iv = FileEncryptor.getInitializationVector();
      const plaintext = 'test data here';

      final encrypted =
          FileEncryptor.encryptData(password, salt, iv, plaintext);
      final decrypted =
          FileEncryptor.decryptData('wrongpassword', salt, iv, encrypted);
      expect(decrypted, isNull);
    });

    test('different salts produce different ciphertexts', () {
      const password = 'testpassword';
      final salt1 = FileEncryptor.getRandomSalt();
      final salt2 = FileEncryptor.getRandomSalt();
      final iv = FileEncryptor.getInitializationVector();
      const plaintext = 'same plaintext for both';

      final encrypted1 =
          FileEncryptor.encryptData(password, salt1, iv, plaintext);
      final encrypted2 =
          FileEncryptor.encryptData(password, salt2, iv, plaintext);
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('different IVs produce different ciphertexts', () {
      const password = 'testpassword';
      final salt = FileEncryptor.getRandomSalt();
      final iv1 = FileEncryptor.getInitializationVector();
      final iv2 = FileEncryptor.getInitializationVector();
      const plaintext = 'same plaintext for both';

      final encrypted1 =
          FileEncryptor.encryptData(password, salt, iv1, plaintext);
      final encrypted2 =
          FileEncryptor.encryptData(password, salt, iv2, plaintext);
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('getRandomSalt returns base64 string of correct length', () {
      final salt = FileEncryptor.getRandomSalt();
      expect(salt.isNotEmpty, isTrue);
      // 8 bytes in base64 = 12 characters (ceil(8/3)*4)
      expect(salt.length, equals(12));
    });

    test('getInitializationVector returns base64 string of correct length', () {
      final iv = FileEncryptor.getInitializationVector();
      expect(iv.isNotEmpty, isTrue);
      // 16 bytes in base64 = 24 characters (ceil(16/3)*4)
      expect(iv.length, equals(24));
    });

    test('throws on empty password', () {
      expect(
        () => FileEncryptor.encryptData(
            '', FileEncryptor.getRandomSalt(),
            FileEncryptor.getInitializationVector(), 'data'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty salt', () {
      expect(
        () => FileEncryptor.encryptData(
            'password', '',
            FileEncryptor.getInitializationVector(), 'data'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles large plaintext', () {
      const password = 'testpassword';
      final salt = FileEncryptor.getRandomSalt();
      final iv = FileEncryptor.getInitializationVector();
      final largePlaintext = 'x' * 10000;

      final encrypted =
          FileEncryptor.encryptData(password, salt, iv, largePlaintext);
      final decrypted =
          FileEncryptor.decryptData(password, salt, iv, encrypted);
      expect(decrypted, equals(largePlaintext));
    });

    test('handles unicode plaintext', () {
      const password = 'testpassword';
      final salt = FileEncryptor.getRandomSalt();
      final iv = FileEncryptor.getInitializationVector();
      const plaintext = '{"name":"тест","emoji":"🔒"}';

      final encrypted =
          FileEncryptor.encryptData(password, salt, iv, plaintext);
      final decrypted =
          FileEncryptor.decryptData(password, salt, iv, encrypted);
      expect(decrypted, equals(plaintext));
    });
  });
}
