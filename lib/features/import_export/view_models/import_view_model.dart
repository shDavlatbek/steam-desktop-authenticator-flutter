import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/steam_guard_account.dart';
import '../../../core/repositories/manifest_repository.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Handles importing .maFile account files into the manifest.
class ImportViewModel extends ChangeNotifier {
  final ManifestRepository _manifestRepo;

  ImportViewModel({required ManifestRepository manifestRepo})
      : _manifestRepo = manifestRepo;

  bool isImporting = false;
  String? errorMessage;
  String? successMessage;

  /// Opens a file picker for the user to select a single `.maFile` and imports
  /// it into the manifest.
  ///
  /// If the file is encrypted, [encryptionKey] must be provided to decrypt it
  /// before saving.
  Future<void> importMaFile({String? encryptionKey}) async {
    isImporting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      // Android doesn't support custom extensions like 'maFile' — use any type
      // and filter manually.
      final result = await FilePicker.platform.pickFiles(
        type: _isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: _isAndroid ? null : ['maFile'],
        dialogTitle: 'Select .maFile to import',
      );

      if (result == null || result.files.single.path == null) {
        isImporting = false;
        notifyListeners();
        return;
      }

      final filePath = result.files.single.path!;

      // On Android with FileType.any the user could pick anything — sanity
      // check that the file content looks like JSON before importing.
      if (_isAndroid && !filePath.endsWith('.maFile')) {
        // Still try to import — the file might just have a different name
        // but valid JSON content.
        final contents = await File(filePath).readAsString();
        try {
          json.decode(contents);
        } catch (_) {
          errorMessage =
              'The selected file does not appear to be a valid .maFile.';
          isImporting = false;
          notifyListeners();
          return;
        }
      }

      await _importSingleFile(filePath, encryptionKey: encryptionKey);
    } catch (e) {
      errorMessage = e.toString();
    }

    isImporting = false;
    notifyListeners();
  }

  /// Scans a directory for `.maFile` files and imports all of them.
  ///
  /// On Android, [getDirectoryPath] returns a content URI that `dart:io`
  /// cannot traverse directly. Instead we use [FilePicker.pickFiles] with
  /// [allowMultiple] to let the user select the individual maFiles from that
  /// directory.  The [importFromDirectoryViaMultiPick] helper is used in that
  /// case, called from the view layer.
  Future<void> importFromDirectory(String path) async {
    isImporting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        errorMessage = 'Directory does not exist.';
        isImporting = false;
        notifyListeners();
        return;
      }

      int imported = 0;
      int failed = 0;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.maFile')) {
          try {
            await _importSingleFile(entity.path);
            imported++;
          } catch (_) {
            failed++;
          }
        }
      }

      if (imported == 0 && failed == 0) {
        errorMessage = 'No .maFile files found in the selected directory.';
      } else if (failed > 0) {
        successMessage =
            'Imported $imported account(s). $failed file(s) could not be imported.';
      } else {
        successMessage = 'Successfully imported $imported account(s).';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isImporting = false;
    notifyListeners();
  }

  /// Android-specific: let the user multi-pick files instead of choosing a
  /// directory (SAF content URIs are not traversable via dart:io).
  Future<void> importFromMultiPick() async {
    isImporting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        dialogTitle: 'Select .maFile files to import',
      );

      if (result == null || result.files.isEmpty) {
        isImporting = false;
        notifyListeners();
        return;
      }

      int imported = 0;
      int failed = 0;

      for (final file in result.files) {
        if (file.path == null) continue;
        try {
          // Try reading as JSON to validate
          final contents = await File(file.path!).readAsString();
          json.decode(contents); // throws if not valid JSON
          await _importSingleFile(file.path!);
          imported++;
        } catch (_) {
          failed++;
        }
      }

      if (imported == 0 && failed == 0) {
        errorMessage = 'No valid .maFile files were selected.';
      } else if (failed > 0) {
        successMessage =
            'Imported $imported account(s). $failed file(s) could not be imported.';
      } else {
        successMessage = 'Successfully imported $imported account(s).';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isImporting = false;
    notifyListeners();
  }

  /// Imports a single .maFile from [filePath].
  Future<void> _importSingleFile(
    String filePath, {
    String? encryptionKey,
  }) async {
    String contents = await File(filePath).readAsString();

    // If an encryption key was provided, attempt to decrypt.
    if (encryptionKey != null && encryptionKey.isNotEmpty) {
      // Try to parse as-is first; if that fails, attempt decryption.
      try {
        json.decode(contents);
      } catch (_) {
        // The file is likely encrypted. We need salt/iv from the manifest entry
        // but since this is a standalone import we try a simple Base64 check.
        // For externally encrypted files the user should supply the key used
        // with the original SDA's manifest (salt+iv are per-entry). In
        // practice, imported files from another SDA install are typically
        // accompanied by the manifest that holds the salt/iv.
        errorMessage = 'Encrypted file detected but no salt/IV available. '
            'Import the entire SDA directory instead.';
        return;
      }
    }

    final Map<String, dynamic> accountJson;
    try {
      accountJson = json.decode(contents) as Map<String, dynamic>;
    } catch (_) {
      throw FormatException('File is not valid JSON: $filePath');
    }

    final account = SteamGuardAccount.fromJson(accountJson);

    final manifest = await _manifestRepo.getManifest();
    final shouldEncrypt = manifest.encrypted;
    String? passKey;
    if (shouldEncrypt) {
      passKey = encryptionKey;
    }

    final saved = await _manifestRepo.saveAccount(
      account,
      encrypt: shouldEncrypt,
      passKey: passKey,
    );

    if (!saved) {
      throw Exception('Failed to save account from $filePath');
    }

    successMessage = 'Successfully imported ${account.accountName ?? 'account'}.';
  }
}
