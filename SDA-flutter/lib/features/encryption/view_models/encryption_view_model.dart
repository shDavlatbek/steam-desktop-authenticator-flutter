import 'package:flutter/foundation.dart';

import '../../../core/repositories/manifest_repository.dart';

/// Manages the encryption state of the manifest and its account files.
class EncryptionViewModel extends ChangeNotifier {
  final ManifestRepository _manifestRepo;

  EncryptionViewModel({required ManifestRepository manifestRepo})
      : _manifestRepo = manifestRepo;

  bool isEncrypted = false;
  bool isProcessing = false;
  String? errorMessage;
  String? successMessage;

  /// Loads the current encryption state from the manifest.
  Future<void> loadState() async {
    errorMessage = null;
    successMessage = null;
    try {
      final manifest = await _manifestRepo.getManifest();
      isEncrypted = manifest.encrypted;
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Encrypts all account files with [newKey].
  ///
  /// Only valid when the manifest is not already encrypted.
  /// Returns `true` on success.
  Future<bool> setupPassKey(String newKey) async {
    if (newKey.isEmpty) {
      errorMessage = 'Passkey cannot be empty.';
      notifyListeners();
      return false;
    }

    isProcessing = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final result = await _manifestRepo.changeEncryptionKey(null, newKey);
      if (result) {
        isEncrypted = true;
        successMessage = 'Encryption has been enabled.';
      } else {
        errorMessage = 'Failed to set up encryption.';
      }
      isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      errorMessage = e.toString();
      isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Changes the encryption passkey from [oldKey] to [newKey].
  ///
  /// Returns `true` on success.
  Future<bool> changePassKey(String oldKey, String newKey) async {
    if (oldKey.isEmpty || newKey.isEmpty) {
      errorMessage = 'Both the current and new passkeys are required.';
      notifyListeners();
      return false;
    }

    isProcessing = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final result = await _manifestRepo.changeEncryptionKey(oldKey, newKey);
      if (result) {
        successMessage = 'Passkey has been changed.';
      } else {
        errorMessage = 'Failed to change passkey. Is the current passkey correct?';
      }
      isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      errorMessage = e.toString();
      isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Removes encryption, decrypting all account files.
  ///
  /// Returns `true` on success.
  Future<bool> removeEncryption(String currentKey) async {
    if (currentKey.isEmpty) {
      errorMessage = 'Current passkey is required.';
      notifyListeners();
      return false;
    }

    isProcessing = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final result =
          await _manifestRepo.changeEncryptionKey(currentKey, null);
      if (result) {
        isEncrypted = false;
        successMessage = 'Encryption has been removed.';
      } else {
        errorMessage =
            'Failed to remove encryption. Is the passkey correct?';
      }
      isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      errorMessage = e.toString();
      isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
