import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/colors.dart';
import '../view_models/home_view_model.dart';
import 'account_list_widget.dart';
import 'totp_display_widget.dart';

/// The main screen of Steam Desktop Authenticator.
///
/// Uses a responsive layout:
/// - Wide screens (>800px): side-by-side with account list on the left and
///   TOTP display on the right.
/// - Narrow screens: single column with the account list and TOTP display
///   stacked vertically.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Kick off initialization after the first frame so the widget tree is
    // fully built and Provider look-ups work correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context, vm),
          bottomNavigationBar: _buildBottomBar(context, vm),
        );
      },
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, HomeViewModel vm) {
    return AppBar(
      title: const Text('Steam Desktop Authenticator'),
      actions: [
        // Context menu for the currently selected account.
        if (vm.currentAccount != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, size: 22),
            tooltip: 'Account actions',
            onSelected: (value) => _onAccountAction(context, vm, value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'login_again',
                child: _MenuRow(
                  icon: Icons.login,
                  label: 'Login Again',
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: 'Remove from Manifest',
                ),
              ),
              const PopupMenuItem(
                value: 'deactivate',
                child: _MenuRow(
                  icon: Icons.security,
                  label: 'Deactivate Authenticator',
                ),
              ),
            ],
          ),

        // Global popup menu.
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: (value) => _onGlobalAction(context, vm, value),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'import',
              child: _MenuRow(
                icon: Icons.file_download_outlined,
                label: 'Import Account',
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: _MenuRow(icon: Icons.settings_outlined, label: 'Settings'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'quit',
              child: _MenuRow(icon: Icons.exit_to_app, label: 'Quit'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, HomeViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            children: [
              // Left panel: account list.
              SizedBox(
                width: 300,
                child: Container(
                  decoration: const BoxDecoration(
                    color: SteamColors.darkBackground,
                    border: Border(
                      right: BorderSide(color: SteamColors.divider),
                    ),
                  ),
                  child: const AccountListWidget(),
                ),
              ),
              // Right panel: TOTP display.
              const Expanded(child: TotpDisplayWidget()),
            ],
          );
        }

        // Narrow layout: stacked vertically.
        return Column(
          children: [
            // TOTP display takes roughly the top third.
            const SizedBox(
              height: 300,
              child: TotpDisplayWidget(),
            ),
            const Divider(height: 1),
            // Account list fills the rest.
            const Expanded(child: AccountListWidget()),
          ],
        );
      },
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, HomeViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        color: SteamColors.darkBackground,
        border: Border(
          top: BorderSide(color: SteamColors.divider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action buttons.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onGlobalAction(context, vm, 'add'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Account'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.currentAccount != null
                        ? () =>
                            _onGlobalAction(context, vm, 'confirmations')
                        : null,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmations'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _onGlobalAction(context, vm, 'encryption'),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Encryption'),
                  ),
                ),
              ],
            ),
          ),

          // Status bar.
          if (vm.statusMessage != null && vm.statusMessage!.isNotEmpty)
            Container(
              width: double.infinity,
              color: SteamColors.darkerBackground,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                vm.statusMessage!,
                style: const TextStyle(
                  color: SteamColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // ── Action handlers ──────────────────────────────────────────────────

  void _onAccountAction(
    BuildContext context,
    HomeViewModel vm,
    String action,
  ) {
    switch (action) {
      case 'login_again':
        // TODO: Navigate to login flow for current account.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Again - not yet implemented')),
        );
        break;

      case 'remove':
        _confirmRemoveAccount(context, vm);
        break;

      case 'deactivate':
        _confirmDeactivate(context, vm);
        break;
    }
  }

  void _onGlobalAction(
    BuildContext context,
    HomeViewModel vm,
    String action,
  ) {
    switch (action) {
      case 'import':
        // TODO: Navigate to import screen.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Import Account - not yet implemented')),
        );
        break;

      case 'settings':
        // TODO: Navigate to settings screen.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings - not yet implemented')),
        );
        break;

      case 'quit':
        // TODO: Implement proper app exit (window_manager close).
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quit - not yet implemented')),
        );
        break;

      case 'add':
        // TODO: Navigate to add-account / setup flow.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add Account - not yet implemented')),
        );
        break;

      case 'confirmations':
        // TODO: Navigate to confirmations screen for current account.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Confirmations - not yet implemented')),
        );
        break;

      case 'encryption':
        // TODO: Navigate to encryption management screen.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Manage Encryption - not yet implemented')),
        );
        break;
    }
  }

  // ── Confirmation dialogs ─────────────────────────────────────────────

  Future<void> _confirmRemoveAccount(
    BuildContext context,
    HomeViewModel vm,
  ) async {
    final account = vm.currentAccount;
    if (account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Account'),
        content: Text(
          'Are you sure you want to remove '
          '"${account.accountName ?? 'this account'}" from the manifest?\n\n'
          'This will delete the account file from disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: SteamColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await vm.removeAccount(account);
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    HomeViewModel vm,
  ) async {
    final account = vm.currentAccount;
    if (account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Authenticator'),
        content: Text(
          'Are you sure you want to deactivate the authenticator for '
          '"${account.accountName ?? 'this account'}"?\n\n'
          'You will no longer be able to generate codes for this account. '
          'Steam will revert to email-based confirmations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: SteamColors.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await vm.deactivateAuthenticator(account);
    }
  }
}

/// A small helper widget used in popup menus to show an icon + label row.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SteamColors.textSecondary),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
