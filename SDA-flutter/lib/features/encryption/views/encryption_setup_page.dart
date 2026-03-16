import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/repositories/manifest_repository.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../view_models/encryption_view_model.dart';
import 'passkey_dialog.dart';

/// Page for managing the encryption state of the manifest and account files.
class EncryptionSetupPage extends StatefulWidget {
  const EncryptionSetupPage({super.key});

  @override
  State<EncryptionSetupPage> createState() => _EncryptionSetupPageState();
}

class _EncryptionSetupPageState extends State<EncryptionSetupPage> {
  late final EncryptionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = EncryptionViewModel(
      manifestRepo: context.read<ManifestRepository>(),
    );
    _viewModel.loadState();
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
        appBar: AppBar(title: const Text('Encryption')),
        body: Consumer<EncryptionViewModel>(
          builder: (context, vm, _) {
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Status card ────────────────────────────────
                      _buildStatusCard(vm),

                      const SizedBox(height: 24),

                      // ── Actions ────────────────────────────────────
                      if (!vm.isEncrypted) ...[
                        _sectionHeader('Set up encryption'),
                        const SizedBox(height: 8),
                        const Text(
                          'Encrypt your account files with a passkey to protect '
                          'them from unauthorized access.',
                          style: TextStyle(
                            color: SteamColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                vm.isProcessing ? null : () => _setupEncryption(vm),
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: const Text('Set Up Encryption'),
                          ),
                        ),
                      ] else ...[
                        _sectionHeader('Manage encryption'),
                        const SizedBox(height: 8),
                        const Text(
                          'Your account files are currently encrypted. You can '
                          'change your passkey or remove encryption entirely.',
                          style: TextStyle(
                            color: SteamColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                vm.isProcessing ? null : () => _changePassKey(vm),
                            icon: const Icon(Icons.key, size: 18),
                            label: const Text('Change Passkey'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: vm.isProcessing
                                ? null
                                : () => _removeEncryption(vm),
                            icon: const Icon(Icons.lock_open, size: 18),
                            label: const Text('Remove Encryption'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SteamColors.error,
                              side: const BorderSide(color: SteamColors.error),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Messages ───────────────────────────────────
                      if (vm.errorMessage != null)
                        _messageBanner(vm.errorMessage!, isError: true),
                      if (vm.successMessage != null)
                        _messageBanner(vm.successMessage!, isError: false),
                    ],
                  ),
                ),

                // ── Processing overlay ─────────────────────────────
                if (vm.isProcessing)
                  const LoadingOverlay(message: 'Processing encryption...'),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildStatusCard(EncryptionViewModel vm) {
    final icon = vm.isEncrypted ? Icons.lock : Icons.lock_open;
    final statusText = vm.isEncrypted ? 'Encrypted' : 'Not encrypted';
    final statusColor =
        vm.isEncrypted ? SteamColors.steamGreen : SteamColors.warning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Encryption Status',
                    style: TextStyle(
                      color: SteamColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: SteamColors.steamBlue,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _messageBanner(String message, {required bool isError}) {
    final color = isError ? SteamColors.error : SteamColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _setupEncryption(EncryptionViewModel vm) async {
    final passkey = await showPasskeyDialog(
      context,
      title: 'Set Up Encryption',
      requireConfirmation: true,
    );
    if (passkey != null && passkey.isNotEmpty) {
      await vm.setupPassKey(passkey);
    }
  }

  Future<void> _changePassKey(EncryptionViewModel vm) async {
    final oldKey = await showPasskeyDialog(
      context,
      title: 'Enter Current Passkey',
    );
    if (oldKey == null || oldKey.isEmpty) return;

    if (!mounted) return;
    final newKey = await showPasskeyDialog(
      context,
      title: 'Enter New Passkey',
      requireConfirmation: true,
    );
    if (newKey == null || newKey.isEmpty) return;

    await vm.changePassKey(oldKey, newKey);
  }

  Future<void> _removeEncryption(EncryptionViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Encryption'),
        content: const Text(
          'Are you sure you want to remove encryption? '
          'Your account files will be stored in plain text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SteamColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    final passkey = await showPasskeyDialog(
      context,
      title: 'Enter Current Passkey',
    );
    if (passkey != null && passkey.isNotEmpty) {
      await vm.removeEncryption(passkey);
    }
  }
}
