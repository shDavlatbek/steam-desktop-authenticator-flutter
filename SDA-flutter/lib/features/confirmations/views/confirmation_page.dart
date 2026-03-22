import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/steam_guard_account.dart';
import '../../../core/repositories/confirmation_repository.dart';
import '../../../shared/theme/colors.dart';
import '../view_models/confirmation_view_model.dart';
import 'confirmation_card.dart';

/// Page that displays all pending Steam confirmations for a given account
/// and allows the user to accept or deny each one.
class ConfirmationPage extends StatefulWidget {
  final SteamGuardAccount account;

  const ConfirmationPage({super.key, required this.account});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  late final ConfirmationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ConfirmationViewModel(
      confirmationRepo: context.read<ConfirmationRepository>(),
    );
    _viewModel.loadConfirmations(widget.account);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirmations'),
          actions: [
            Consumer<ConfirmationViewModel>(
              builder: (_, vm, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vm.confirmations.length > 1) ...[
                    IconButton(
                      icon: const Icon(Icons.done_all, size: 22),
                      tooltip: 'Accept All',
                      onPressed: vm.isLoading
                          ? null
                          : () => _confirmBulkAction(
                                context, vm, accept: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all, size: 22),
                      tooltip: 'Deny All',
                      onPressed: vm.isLoading
                          ? null
                          : () => _confirmBulkAction(
                                context, vm, accept: false),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: vm.isLoading
                        ? null
                        : () => vm.loadConfirmations(widget.account),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Consumer<ConfirmationViewModel>(
          builder: (context, vm, _) {
            // ── Loading state ────────────────────────────────────────
            if (vm.isLoading && vm.confirmations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // ── Error state ──────────────────────────────────────────
            if (vm.errorMessage != null && vm.confirmations.isEmpty) {
              return _buildErrorState(vm);
            }

            // ── Empty state ──────────────────────────────────────────
            if (vm.confirmations.isEmpty) {
              return _buildEmptyState();
            }

            // ── Confirmation list ────────────────────────────────────
            return RefreshIndicator(
              color: SteamColors.steamBlue,
              backgroundColor: Theme.of(context).cardColor,
              onRefresh: () => vm.loadConfirmations(widget.account),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: vm.confirmations.length + _errorBannerCount(vm),
                itemBuilder: (context, index) {
                  // Show error banner at top if there's an error but we still
                  // have cached confirmations.
                  if (vm.errorMessage != null && index == 0) {
                    return _buildErrorBanner(vm);
                  }

                  final confIndex =
                      vm.errorMessage != null ? index - 1 : index;
                  final conf = vm.confirmations[confIndex];

                  return ConfirmationCard(
                    confirmation: conf,
                    isProcessing: vm.isProcessing(conf.id),
                    onAccept: () =>
                        vm.acceptConfirmation(widget.account, conf),
                    onDeny: () =>
                        vm.denyConfirmation(widget.account, conf),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  int _errorBannerCount(ConfirmationViewModel vm) =>
      vm.errorMessage != null && vm.confirmations.isNotEmpty ? 1 : 0;

  Widget _buildErrorState(ConfirmationViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: SteamColors.error),
            const SizedBox(height: 16),
            Text(
              vm.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => vm.loadConfirmations(widget.account),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: SteamColors.steamBlue.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              'No confirmations',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no pending confirmations for this account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBulkAction(
    BuildContext context,
    ConfirmationViewModel vm, {
    required bool accept,
  }) async {
    final action = accept ? 'accept' : 'deny';
    final count = vm.confirmations.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${accept ? 'Accept' : 'Deny'} All'),
        content: Text(
          'Are you sure you want to $action all $count confirmation(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  accept ? SteamColors.steamGreen : SteamColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('${accept ? 'Accept' : 'Deny'} All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (accept) {
        await vm.acceptAll(widget.account);
      } else {
        await vm.denyAll(widget.account);
      }
    }
  }

  Widget _buildErrorBanner(ConfirmationViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SteamColors.error.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SteamColors.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: SteamColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              vm.errorMessage!,
              style: const TextStyle(color: SteamColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
