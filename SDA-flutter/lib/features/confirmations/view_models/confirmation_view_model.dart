import 'package:flutter/foundation.dart';

import '../../../core/models/confirmation.dart';
import '../../../core/models/steam_guard_account.dart';
import '../../../core/repositories/confirmation_repository.dart';
import '../../../core/services/debug_logger.dart';

/// Manages the state for fetching and acting on Steam trade/market
/// confirmations.
class ConfirmationViewModel extends ChangeNotifier {
  final ConfirmationRepository _confirmationRepo;
  final DebugLogger _log = DebugLogger();

  ConfirmationViewModel({required ConfirmationRepository confirmationRepo})
      : _confirmationRepo = confirmationRepo;

  List<Confirmation> confirmations = [];
  bool isLoading = false;
  String? errorMessage;

  /// The set of confirmation IDs currently being processed (accept/deny).
  final Set<String> _processingIds = {};

  bool isProcessing(String confirmationId) =>
      _processingIds.contains(confirmationId);

  /// Fetches all pending confirmations for [account].
  Future<void> loadConfirmations(SteamGuardAccount account) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      confirmations = await _confirmationRepo.fetchConfirmations(account);
      _log.info('ConfirmationVM',
          'Loaded ${confirmations.length} confirmations');
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Load failed: $e', detail: st.toString());
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
      _log.info('ConfirmationVM', 'Accepted confirmation ${conf.id}');
      await loadConfirmations(account);
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Accept failed: $e',
          detail: st.toString());
      _processingIds.remove(conf.id);
      notifyListeners();
    }
  }

  /// Accepts all current confirmations in a single bulk request.
  Future<void> acceptAll(SteamGuardAccount account) async {
    if (confirmations.isEmpty) return;
    final count = confirmations.length;
    for (final c in confirmations) {
      _processingIds.add(c.id);
    }
    notifyListeners();
    try {
      final success = await _confirmationRepo.acceptMultipleConfirmations(
          account, List.of(confirmations));
      if (!success) {
        _log.error('ConfirmationVM', 'Bulk accept returned false');
        errorMessage = 'Failed to accept confirmations.';
      } else {
        _log.info('ConfirmationVM', 'Bulk accepted $count confirmations');
      }
      _processingIds.clear();
      await loadConfirmations(account);
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Bulk accept failed: $e',
          detail: st.toString());
      _processingIds.clear();
      notifyListeners();
    }
  }

  /// Denies all current confirmations in a single bulk request.
  Future<void> denyAll(SteamGuardAccount account) async {
    if (confirmations.isEmpty) return;
    final count = confirmations.length;
    for (final c in confirmations) {
      _processingIds.add(c.id);
    }
    notifyListeners();
    try {
      final success = await _confirmationRepo.denyMultipleConfirmations(
          account, List.of(confirmations));
      if (!success) {
        _log.error('ConfirmationVM', 'Bulk deny returned false');
        errorMessage = 'Failed to deny confirmations.';
      } else {
        _log.info('ConfirmationVM', 'Bulk denied $count confirmations');
      }
      _processingIds.clear();
      await loadConfirmations(account);
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Bulk deny failed: $e',
          detail: st.toString());
      _processingIds.clear();
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
      _log.info('ConfirmationVM', 'Denied confirmation ${conf.id}');
      await loadConfirmations(account);
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Deny failed: $e',
          detail: st.toString());
      _processingIds.remove(conf.id);
      notifyListeners();
    }
  }
}
