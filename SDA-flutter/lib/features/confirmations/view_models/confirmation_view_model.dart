import 'package:flutter/foundation.dart';

import '../../../core/models/confirmation.dart';
import '../../../core/models/steam_guard_account.dart';
import '../../../core/repositories/confirmation_repository.dart';

/// Manages the state for fetching and acting on Steam trade/market
/// confirmations.
class ConfirmationViewModel extends ChangeNotifier {
  final ConfirmationRepository _confirmationRepo;

  ConfirmationViewModel({required ConfirmationRepository confirmationRepo})
      : _confirmationRepo = confirmationRepo;

  List<Confirmation> confirmations = [];
  bool isLoading = false;
  String? errorMessage;

  /// The set of confirmation IDs currently being processed (accept/deny).
  final Set<int> _processingIds = {};

  bool isProcessing(int confirmationId) =>
      _processingIds.contains(confirmationId);

  /// Fetches all pending confirmations for [account].
  Future<void> loadConfirmations(SteamGuardAccount account) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      confirmations = await _confirmationRepo.fetchConfirmations(account);
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  /// Accepts a single confirmation and refreshes the list.
  Future<void> acceptConfirmation(
    SteamGuardAccount account,
    Confirmation conf,
  ) async {
    _processingIds.add(conf.id);
    notifyListeners();
    try {
      await _confirmationRepo.acceptConfirmation(account, conf);
      await loadConfirmations(account);
    } catch (e) {
      errorMessage = e.toString();
      _processingIds.remove(conf.id);
      notifyListeners();
    }
  }

  /// Denies a single confirmation and refreshes the list.
  Future<void> denyConfirmation(
    SteamGuardAccount account,
    Confirmation conf,
  ) async {
    _processingIds.add(conf.id);
    notifyListeners();
    try {
      await _confirmationRepo.denyConfirmation(account, conf);
      await loadConfirmations(account);
    } catch (e) {
      errorMessage = e.toString();
      _processingIds.remove(conf.id);
      notifyListeners();
    }
  }
}
