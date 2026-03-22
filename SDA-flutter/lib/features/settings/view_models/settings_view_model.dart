import 'package:flutter/foundation.dart';

import '../../../core/repositories/manifest_repository.dart';
import '../../../core/services/debug_logger.dart';

/// Manages the application-wide settings stored in the manifest.
class SettingsViewModel extends ChangeNotifier {
  final ManifestRepository _manifestRepo;

  SettingsViewModel({required ManifestRepository manifestRepo})
      : _manifestRepo = manifestRepo;

  bool periodicChecking = false;
  int periodicCheckingInterval = 5;
  bool checkAllAccounts = false;
  bool autoConfirmMarketTransactions = false;
  bool autoConfirmTrades = false;
  bool debugMode = false;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? successMessage;

  /// Loads current settings from the manifest file.
  Future<void> loadSettings() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final manifest = await _manifestRepo.getManifest();
      periodicChecking = manifest.periodicChecking;
      periodicCheckingInterval = manifest.periodicCheckingInterval;
      checkAllAccounts = manifest.checkAllAccounts;
      autoConfirmMarketTransactions = manifest.autoConfirmMarketTransactions;
      autoConfirmTrades = manifest.autoConfirmTrades;
      debugMode = manifest.debugMode;
      DebugLogger().setEnabled(debugMode);
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  /// Persists current settings to the manifest file.
  Future<void> saveSettings() async {
    isSaving = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();
    try {
      final manifest = await _manifestRepo.getManifest();
      manifest.periodicChecking = periodicChecking;
      manifest.periodicCheckingInterval = periodicCheckingInterval;
      manifest.checkAllAccounts = checkAllAccounts;
      manifest.autoConfirmMarketTransactions = autoConfirmMarketTransactions;
      manifest.autoConfirmTrades = autoConfirmTrades;
      manifest.debugMode = debugMode;
      final saved = await _manifestRepo.save();
      if (saved) {
        successMessage = 'Settings saved successfully.';
      } else {
        errorMessage = 'Failed to save settings.';
      }
    } catch (e) {
      errorMessage = e.toString();
    }
    isSaving = false;
    notifyListeners();
  }

  void setPeriodicChecking(bool value) {
    periodicChecking = value;
    notifyListeners();
  }

  void setPeriodicCheckingInterval(int value) {
    if (value >= 5) {
      periodicCheckingInterval = value;
      notifyListeners();
    }
  }

  void setCheckAllAccounts(bool value) {
    checkAllAccounts = value;
    notifyListeners();
  }

  void setAutoConfirmMarketTransactions(bool value) {
    autoConfirmMarketTransactions = value;
    notifyListeners();
  }

  void setAutoConfirmTrades(bool value) {
    autoConfirmTrades = value;
    notifyListeners();
  }

  void setDebugMode(bool value) {
    debugMode = value;
    DebugLogger().setEnabled(value);
    notifyListeners();
  }
}
