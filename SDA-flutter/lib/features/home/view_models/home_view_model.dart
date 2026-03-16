import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/models/manifest.dart';
import '../../../core/models/steam_guard_account.dart';
import '../../../core/repositories/account_repository.dart';
import '../../../core/repositories/confirmation_repository.dart';
import '../../../core/repositories/manifest_repository.dart';

/// Main state manager for the home screen.
///
/// Port of MainForm.cs logic from the original SDA C# project. Manages the
/// account list, TOTP code generation timer, search filtering, and account
/// reordering.
class HomeViewModel extends ChangeNotifier {
  final ManifestRepository _manifestRepo;
  final AccountRepository _accountRepo;
  final ConfirmationRepository _confirmationRepo;

  HomeViewModel({
    required ManifestRepository manifestRepo,
    required AccountRepository accountRepo,
    required ConfirmationRepository confirmationRepo,
  })  : _manifestRepo = manifestRepo,
        _accountRepo = accountRepo,
        _confirmationRepo = confirmationRepo;

  // ── State ──────────────────────────────────────────────────────────────

  List<SteamGuardAccount> _allAccounts = [];
  List<SteamGuardAccount> get allAccounts => _allAccounts;

  List<SteamGuardAccount> _filteredAccounts = [];
  List<SteamGuardAccount> get filteredAccounts => _filteredAccounts;

  SteamGuardAccount? _currentAccount;
  SteamGuardAccount? get currentAccount => _currentAccount;

  String _currentCode = '';
  String get currentCode => _currentCode;

  int _secondsRemaining = 0;
  int get secondsRemaining => _secondsRemaining;

  String _searchFilter = '';
  String get searchFilter => _searchFilter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  String? _passKey;
  String? get passKey => _passKey;
  set passKey(String? value) {
    _passKey = value;
    notifyListeners();
  }

  bool _isFirstRun = false;
  bool get isFirstRun => _isFirstRun;

  Manifest? _manifest;
  Manifest? get manifest => _manifest;

  Timer? _steamGuardTimer;

  // Expose repositories for child widgets that need them (e.g. confirmations).
  ManifestRepository get manifestRepo => _manifestRepo;
  AccountRepository get accountRepo => _accountRepo;
  ConfirmationRepository get confirmationRepo => _confirmationRepo;

  // ── Initialization ─────────────────────────────────────────────────────

  /// Loads the manifest, checks whether this is a first run, loads all
  /// accounts from disk, and starts the TOTP refresh timer.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _manifest = await _manifestRepo.getManifest();
      _isFirstRun = _manifest!.firstRun;

      if (_manifest!.encrypted && _passKey == null) {
        _statusMessage = 'Manifest is encrypted. Please enter your passkey.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await loadAccounts();

      if (_allAccounts.isNotEmpty) {
        _currentAccount = _allAccounts.first;
      }

      _startSteamGuardTimer();
      _statusMessage = 'Loaded ${_allAccounts.length} account(s).';
    } catch (e) {
      _statusMessage = 'Error during initialization: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Account selection ──────────────────────────────────────────────────

  /// Switches the active account to the one at [index] in the filtered list.
  void selectAccount(int index) {
    if (index < 0 || index >= _filteredAccounts.length) return;
    _currentAccount = _filteredAccounts[index];
    _currentCode = '';
    notifyListeners();
    // Immediately generate a code for the newly selected account.
    _onSteamGuardTick();
  }

  // ── Filtering ──────────────────────────────────────────────────────────

  /// Filters the displayed account list by [query].
  ///
  /// If the query starts with `~`, it is treated as a regular expression.
  /// Otherwise a case-insensitive substring match is used.
  void filterAccounts(String query) {
    _searchFilter = query;

    if (query.isEmpty) {
      _filteredAccounts = List.of(_allAccounts);
    } else if (query.startsWith('~') && query.length > 1) {
      try {
        final regex = RegExp(query.substring(1), caseSensitive: false);
        _filteredAccounts = _allAccounts
            .where((a) => regex.hasMatch(a.accountName ?? ''))
            .toList();
      } catch (_) {
        // Invalid regex - show nothing rather than crash.
        _filteredAccounts = [];
      }
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredAccounts = _allAccounts
          .where((a) =>
              (a.accountName ?? '').toLowerCase().contains(lowerQuery))
          .toList();
    }

    notifyListeners();
  }

  // ── Clipboard ──────────────────────────────────────────────────────────

  /// Copies the current TOTP code to the system clipboard and updates the
  /// status message.
  Future<void> copyCodeToClipboard() async {
    if (_currentCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _currentCode));
    _statusMessage = 'Code copied to clipboard.';
    notifyListeners();
  }

  // ── Account loading ────────────────────────────────────────────────────

  /// (Re)loads all accounts from the manifest.
  Future<void> loadAccounts() async {
    _allAccounts =
        await _manifestRepo.getAllAccounts(passKey: _passKey);
    _filteredAccounts = List.of(_allAccounts);

    // If the previously selected account is no longer present, clear it.
    if (_currentAccount != null &&
        !_allAccounts.contains(_currentAccount)) {
      _currentAccount =
          _allAccounts.isNotEmpty ? _allAccounts.first : null;
    }

    notifyListeners();
  }

  // ── Reorder ────────────────────────────────────────────────────────────

  /// Reorders the account list by moving the item at [from] to [to].
  void reorderAccount(int from, int to) {
    if (from < 0 || to < 0 || from >= _allAccounts.length) return;
    if (to > from) to -= 1;

    final account = _allAccounts.removeAt(from);
    _allAccounts.insert(to, account);

    // Keep the manifest entry order in sync.
    _manifestRepo.moveEntry(from, to);

    // Re-apply current filter.
    filterAccounts(_searchFilter);
  }

  // ── TOTP timer ─────────────────────────────────────────────────────────

  void _startSteamGuardTimer() {
    _steamGuardTimer?.cancel();
    _steamGuardTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onSteamGuardTick(),
    );
    // Run once immediately so there is no 1-second gap at startup.
    _onSteamGuardTick();
  }

  Future<void> _onSteamGuardTick() async {
    if (_currentAccount == null) {
      _currentCode = '';
      _secondsRemaining = 0;
      notifyListeners();
      return;
    }

    try {
      final time = await _accountRepo.getSteamTime();
      _secondsRemaining = 30 - (time % 30);

      final code =
          await _accountRepo.generateSteamGuardCode(_currentAccount!);
      _currentCode = code ?? '';
    } catch (_) {
      // If time sync or code generation fails, keep the last known values.
    }

    notifyListeners();
  }

  // ── Account actions ────────────────────────────────────────────────────

  /// Removes [account] from the manifest and refreshes the list.
  Future<void> removeAccount(SteamGuardAccount account) async {
    await _manifestRepo.removeAccount(account);
    await loadAccounts();
    _statusMessage = 'Account removed.';
    notifyListeners();
  }

  /// Deactivates the authenticator on [account] and removes it.
  Future<bool> deactivateAuthenticator(SteamGuardAccount account) async {
    try {
      final success = await _accountRepo.deactivateAuthenticator(account, 1);
      if (success) {
        await _manifestRepo.removeAccount(account);
        await loadAccounts();
        _statusMessage = 'Authenticator deactivated and account removed.';
        notifyListeners();
      }
      return success;
    } catch (e) {
      _statusMessage = 'Failed to deactivate authenticator: $e';
      notifyListeners();
      return false;
    }
  }

  /// Marks first run as complete and persists the manifest.
  Future<void> completeFirstRun() async {
    if (_manifest != null) {
      _manifest!.firstRun = false;
      _isFirstRun = false;
      await _manifestRepo.save();
      notifyListeners();
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _steamGuardTimer?.cancel();
    super.dispose();
  }
}
