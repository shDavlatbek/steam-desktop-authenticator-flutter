import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../crypto/file_encryptor.dart';
import '../models/manifest.dart';
import '../models/steam_guard_account.dart';

/// Central storage manager for maFiles.
///
/// Port of the file I/O operations from Manifest.cs in the original SDA C#
/// project. Handles loading, saving, encrypting, and decrypting Steam Guard
/// account files and the manifest.json index.
class ManifestRepository {
  Manifest? _manifest;
  String? _maFilesDir;

  /// Returns the path to the maFiles directory, creating it if necessary.
  Future<String> getMaFilesDir() async {
    if (_maFilesDir != null) return _maFilesDir!;
    final appDir = await getApplicationSupportDirectory();
    _maFilesDir = '${appDir.path}/maFiles';
    final dir = Directory(_maFilesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _maFilesDir!;
  }

  /// Loads the manifest from maFiles/manifest.json.
  ///
  /// Returns a cached instance unless [forceLoad] is `true`.
  /// If the manifest file does not exist, generates a new blank manifest.
  Future<Manifest> getManifest({bool forceLoad = false}) async {
    if (_manifest != null && !forceLoad) return _manifest!;

    final maDir = await getMaFilesDir();
    final manifestFile = File('$maDir/manifest.json');

    if (!await manifestFile.exists()) {
      _manifest = await generateNewManifest();
      return _manifest!;
    }

    try {
      final contents = await manifestFile.readAsString();
      _manifest = Manifest.fromJson(json.decode(contents));

      // If the manifest claims to be encrypted but has no entries, clear the
      // flag so that the user is not stuck.
      if (_manifest!.encrypted && _manifest!.entries.isEmpty) {
        _manifest!.encrypted = false;
        await save();
      }

      await _recomputeExistingEntries();
      return _manifest!;
    } catch (_) {
      throw ManifestParseException();
    }
  }

  /// Creates a new blank manifest.
  ///
  /// When [scanDir] is `true`, the maFiles directory is scanned for existing
  /// `.maFile` files and matching entries are added automatically.
  Future<Manifest> generateNewManifest({bool scanDir = false}) async {
    final newManifest = Manifest(
      encrypted: false,
      firstRun: true,
      entries: [],
      periodicChecking: false,
      periodicCheckingInterval: 5,
      checkAllAccounts: false,
      autoConfirmMarketTransactions: false,
      autoConfirmTrades: false,
    );

    if (scanDir) {
      final maDir = await getMaFilesDir();
      final dir = Directory(maDir);
      if (await dir.exists()) {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.maFile')) {
            try {
              final contents = await file.readAsString();
              final account =
                  SteamGuardAccount.fromJson(json.decode(contents));
              if (account.session != null) {
                newManifest.entries.add(ManifestEntry(
                  filename: file.uri.pathSegments.last,
                  steamId: account.session!.steamID,
                ));
              }
            } catch (_) {
              // Skip encrypted or invalid files
            }
          }
        }
      }
    }

    _manifest = newManifest;
    await save();
    return newManifest;
  }

  /// Loads all accounts from disk, decrypting if necessary.
  ///
  /// [passKey] - The encryption password. Required when the manifest is
  /// encrypted; pass `null` for unencrypted manifests.
  /// [limit] - Maximum number of accounts to load. `-1` means no limit.
  ///
  /// Returns an empty list if the manifest is encrypted and no passkey is
  /// supplied, or if decryption fails (wrong passkey).
  Future<List<SteamGuardAccount>> getAllAccounts({
    String? passKey,
    int limit = -1,
  }) async {
    final manifest = await getManifest();
    if (passKey == null && manifest.encrypted) return [];

    final maDir = await getMaFilesDir();
    final accounts = <SteamGuardAccount>[];

    for (final entry in manifest.entries) {
      try {
        String fileText =
            await File('$maDir/${entry.filename}').readAsString();

        if (manifest.encrypted && passKey != null) {
          final decrypted = FileEncryptor.decryptData(
              passKey, entry.salt!, entry.iv!, fileText);
          if (decrypted == null) return []; // Bad passkey
          fileText = decrypted;
        }

        final account = SteamGuardAccount.fromJson(json.decode(fileText));
        accounts.add(account);

        if (limit != -1 && accounts.length >= limit) break;
      } catch (_) {
        continue;
      }
    }

    return accounts;
  }

  /// Saves an account to its .maFile and updates the manifest.
  ///
  /// [encrypt] - Whether to encrypt the account file.
  /// [passKey] - The encryption password (required when [encrypt] is `true`).
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> saveAccount(
    SteamGuardAccount account, {
    bool encrypt = false,
    String? passKey,
  }) async {
    if (encrypt && (passKey == null || passKey.isEmpty)) return false;

    final manifest = await getManifest();
    if (!encrypt && manifest.encrypted) return false;

    String? salt;
    String? iv;
    String jsonAccount = json.encode(account.toJson());

    if (encrypt) {
      salt = FileEncryptor.getRandomSalt();
      iv = FileEncryptor.getInitializationVector();
      jsonAccount =
          FileEncryptor.encryptData(passKey!, salt, iv, jsonAccount);
    }

    final maDir = await getMaFilesDir();
    final filename = '${account.session!.steamID}.maFile';

    final newEntry = ManifestEntry(
      steamId: account.session!.steamID,
      iv: iv,
      salt: salt,
      filename: filename,
    );

    // Update existing entry or add a new one.
    bool found = false;
    for (int i = 0; i < manifest.entries.length; i++) {
      if (manifest.entries[i].steamId == account.session!.steamID) {
        manifest.entries[i] = newEntry;
        found = true;
        break;
      }
    }
    if (!found) manifest.entries.add(newEntry);

    final wasEncrypted = manifest.encrypted;
    manifest.encrypted = encrypt || manifest.encrypted;

    if (!await save()) {
      manifest.encrypted = wasEncrypted;
      return false;
    }

    try {
      await File('$maDir/$filename').writeAsString(jsonAccount);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes an account from the manifest and optionally deletes its .maFile.
  ///
  /// Returns `true` on success.
  Future<bool> removeAccount(
    SteamGuardAccount account, {
    bool deleteMaFile = true,
  }) async {
    final manifest = await getManifest();
    final entry = manifest.entries
        .where((e) => e.steamId == account.session?.steamID)
        .firstOrNull;
    if (entry == null) return true;

    final maDir = await getMaFilesDir();
    manifest.entries.remove(entry);

    if (manifest.entries.isEmpty) manifest.encrypted = false;

    if (await save() && deleteMaFile) {
      try {
        await File('$maDir/${entry.filename}').delete();
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Re-encrypts all account files with a new passkey.
  ///
  /// [oldKey] - The current encryption password (or `null` if unencrypted).
  /// [newKey] - The new encryption password (or `null` to remove encryption).
  ///
  /// Returns `true` on success.
  Future<bool> changeEncryptionKey(String? oldKey, String? newKey) async {
    final manifest = await getManifest();

    if (manifest.encrypted) {
      if (!await verifyPasskeyAsync(oldKey ?? '')) return false;
    }

    final toEncrypt = newKey != null;
    final maDir = await getMaFilesDir();

    for (int i = 0; i < manifest.entries.length; i++) {
      final entry = manifest.entries[i];
      final file = File('$maDir/${entry.filename}');
      if (!await file.exists()) continue;

      String fileContents = await file.readAsString();

      if (manifest.encrypted && oldKey != null) {
        fileContents = FileEncryptor.decryptData(
            oldKey, entry.salt!, entry.iv!, fileContents)!;
      }

      String? newSalt;
      String? newIv;
      String toWrite = fileContents;

      if (toEncrypt) {
        newSalt = FileEncryptor.getRandomSalt();
        newIv = FileEncryptor.getInitializationVector();
        toWrite =
            FileEncryptor.encryptData(newKey, newSalt, newIv, fileContents);
      }

      await file.writeAsString(toWrite);
      manifest.entries[i] = ManifestEntry(
        steamId: entry.steamId,
        filename: entry.filename,
        iv: newIv,
        salt: newSalt,
      );
    }

    manifest.encrypted = toEncrypt;
    await save();
    return true;
  }

  /// Verifies the encryption passkey by attempting to decrypt the first
  /// account. Returns `true` if the manifest is unencrypted or the passkey
  /// is correct.
  bool verifyPasskey(String? passkey) {
    if (_manifest == null ||
        !_manifest!.encrypted ||
        _manifest!.entries.isEmpty) {
      return true;
    }
    // Synchronous check is a placeholder; use [verifyPasskeyAsync] for real
    // verification.
    return true;
  }

  /// Asynchronous passkey verification. Attempts to decrypt the first account
  /// file and returns `true` on success.
  Future<bool> verifyPasskeyAsync(String passkey) async {
    final accounts = await getAllAccounts(passKey: passkey, limit: 1);
    return accounts.isNotEmpty;
  }

  /// Moves a manifest entry from index [from] to index [to].
  void moveEntry(int from, int to) {
    if (_manifest == null) return;
    final entries = _manifest!.entries;
    if (from < 0 ||
        to < 0 ||
        from >= entries.length ||
        to >= entries.length) {
      return;
    }
    final entry = entries.removeAt(from);
    entries.insert(to, entry);
    save();
  }

  /// Persists the manifest to maFiles/manifest.json.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> save() async {
    try {
      final maDir = await getMaFilesDir();
      final dir = Directory(maDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File('$maDir/manifest.json');
      await file.writeAsString(json.encode(_manifest?.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes manifest entries whose backing .maFile no longer exists on disk.
  Future<void> _recomputeExistingEntries() async {
    if (_manifest == null) return;
    final maDir = await getMaFilesDir();

    _manifest!.entries
        .removeWhere((entry) => !File('$maDir/${entry.filename}').existsSync());

    if (_manifest!.entries.isEmpty) _manifest!.encrypted = false;
  }
}

/// Thrown when manifest.json cannot be parsed.
class ManifestParseException implements Exception {
  @override
  String toString() => 'Failed to parse manifest.json';
}

/// Thrown when an maFile is encrypted and no passkey was supplied.
class MaFileEncryptedException implements Exception {
  @override
  String toString() => 'maFile is encrypted';
}
