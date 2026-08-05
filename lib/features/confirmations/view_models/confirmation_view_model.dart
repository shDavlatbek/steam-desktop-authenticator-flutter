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

  /// The set of confirmation IDs currently selected by the user.
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  bool get selectionMode => _selectionMode;
  int get selectedCount => _selectedIds.length;

  bool isProcessing(String confirmationId) =>
      _processingIds.contains(confirmationId);

  bool isSelected(String confirmationId) =>
      _selectedIds.contains(confirmationId);

  void toggleSelection(String confirmationId) {
    _selectionMode = true;
    if (_selectedIds.contains(confirmationId)) {
      _selectedIds.remove(confirmationId);
    } else {
      _selectedIds.add(confirmationId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectionMode = true;
    _selectedIds.addAll(confirmations.map((c) => c.id));
    notifyListeners();
  }

  void clearSelection() {
    _selectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

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

  /// Accepts only the selected confirmations.
  Future<void> acceptSelected(SteamGuardAccount account) async {
    final selected = confirmations
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    if (selected.isEmpty) return;
    final count = selected.length;
    for (final c in selected) {
      _processingIds.add(c.id);
    }
    notifyListeners();
    try {
      final success = await _confirmationRepo.acceptMultipleConfirmations(
          account, selected);
      if (!success) {
        errorMessage = 'Failed to accept selected confirmations.';
      } else {
        _log.info('ConfirmationVM', 'Accepted $count selected confirmations');
      }
      _processingIds.clear();
      _selectedIds.clear();
      await loadConfirmations(account);
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Accept selected failed: $e',
          detail: st.toString());
      _processingIds.clear();
      notifyListeners();
    }
  }

  /// Denies only the selected confirmations.
  Future<void> denySelected(SteamGuardAccount account) async {
    final selected = confirmations
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    if (selected.isEmpty) return;
    final count = selected.length;
    for (final c in selected) {
      _processingIds.add(c.id);
    }
    notifyListeners();
    try {
      final success = await _confirmationRepo.denyMultipleConfirmations(
          account, selected);
      if (!success) {
        errorMessage = 'Failed to deny selected confirmations.';
      } else {
        _log.info('ConfirmationVM', 'Denied $count selected confirmations');
      }
      _processingIds.clear();
      _selectedIds.clear();
      await loadConfirmations(account);
    } catch (e, st) {
      errorMessage = e.toString();
      _log.error('ConfirmationVM', 'Deny selected failed: $e',
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
