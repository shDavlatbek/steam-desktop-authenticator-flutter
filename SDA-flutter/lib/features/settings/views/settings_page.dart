import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/repositories/manifest_repository.dart';
import '../../../core/services/debug_logger.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/theme_notifier.dart';
import '../view_models/settings_view_model.dart';
import 'debug_log_page.dart';

/// Settings page that lets the user configure periodic confirmation checking
/// and auto-confirm behaviour.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsViewModel _viewModel;
  late final TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsViewModel(
      manifestRepo: context.read<ManifestRepository>(),
    );
    _intervalController = TextEditingController();
    _viewModel.addListener(_syncIntervalField);
    _viewModel.loadSettings();
  }

  void _syncIntervalField() {
    final text = _viewModel.periodicCheckingInterval.toString();
    if (_intervalController.text != text) {
      _intervalController.text = text;
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncIntervalField);
    _intervalController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Consumer<SettingsViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Appearance section ──────────────────────────
                        _sectionHeader('Appearance'),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Dark mode',
                          subtitle: 'Switch between dark and light theme.',
                          value: vm.darkMode,
                          onChanged: (val) {
                            vm.setDarkMode(val);
                            context.read<ThemeNotifier>().setDark(val);
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── Periodic Checking section ──────────────────
                        _sectionHeader('Periodic Checking'),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Enable periodic confirmation checking',
                          subtitle:
                              'Automatically check for new confirmations at a regular interval.',
                          value: vm.periodicChecking,
                          onChanged: vm.setPeriodicChecking,
                        ),
                        const SizedBox(height: 8),
                        _buildIntervalField(vm),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Check all accounts',
                          subtitle:
                              'When enabled, periodic checking applies to every linked account.',
                          value: vm.checkAllAccounts,
                          onChanged: vm.setCheckAllAccounts,
                        ),

                        const SizedBox(height: 24),

                        // ── Auto-Confirm section ───────────────────────
                        _sectionHeader('Auto-Confirm'),
                        const SizedBox(height: 8),
                        _buildAutoConfirmWarning(),
                        const SizedBox(height: 12),
                        _buildSwitchTile(
                          title: 'Auto-confirm market transactions',
                          subtitle:
                              'Automatically accept Steam Community Market confirmations.',
                          value: vm.autoConfirmMarketTransactions,
                          onChanged: (val) => _handleAutoConfirmToggle(
                            context,
                            value: val,
                            label: 'market transactions',
                            onConfirm: () =>
                                vm.setAutoConfirmMarketTransactions(val),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Auto-confirm trades',
                          subtitle:
                              'Automatically accept trade offer confirmations.',
                          value: vm.autoConfirmTrades,
                          onChanged: (val) => _handleAutoConfirmToggle(
                            context,
                            value: val,
                            label: 'trades',
                            onConfirm: () => vm.setAutoConfirmTrades(val),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Debug section ──────────────────────────────
                        _sectionHeader('Debug'),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Debug mode',
                          subtitle:
                              'Log HTTP requests, responses, and internal operations for troubleshooting.',
                          value: vm.debugMode,
                          onChanged: vm.setDebugMode,
                        ),
                        if (vm.debugMode) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const DebugLogPage()),
                              ),
                              icon: const Icon(Icons.article_outlined,
                                  size: 18),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('View Logs'),
                                  const SizedBox(width: 8),
                                  ListenableBuilder(
                                    listenable: DebugLogger(),
                                    builder: (_, _) {
                                      final count =
                                          DebugLogger().entries.length;
                                      if (count == 0) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: SteamColors.steamBlue
                                              .withAlpha(40),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: SteamColors.steamBlue),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ── Messages ────────────────────────────────────
                        if (vm.errorMessage != null)
                          _messageBanner(vm.errorMessage!, isError: true),
                        if (vm.successMessage != null)
                          _messageBanner(vm.successMessage!,
                              isError: false),
                      ],
                    ),
                  ),
                ),

                // ── Sticky save button ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton(
                      onPressed: vm.isSaving
                          ? null
                          : () async {
                              await vm.saveSettings();
                              if (context.mounted) {
                                context
                                    .read<ThemeNotifier>()
                                    .setDark(vm.darkMode);
                              }
                            },
                      child: vm.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Settings'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(color: SteamColors.textPrimary)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: SteamColors.textSecondary, fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildIntervalField(SettingsViewModel vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Check interval (seconds)',
                      style: TextStyle(color: SteamColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Minimum: 5 seconds',
                      style: TextStyle(
                          color: SteamColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed >= 5) {
                    vm.setPeriodicCheckingInterval(parsed);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoConfirmWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SteamColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SteamColors.warning.withAlpha(80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: SteamColors.warning, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-confirming trades or market listings can be dangerous. '
              'Only enable these if you understand the security implications.',
              style: TextStyle(color: SteamColors.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAutoConfirmToggle(
    BuildContext context, {
    required bool value,
    required String label,
    required VoidCallback onConfirm,
  }) {
    if (!value) {
      // Turning off does not need confirmation.
      onConfirm();
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security Warning'),
        content: Text(
          'Are you sure you want to auto-confirm $label? '
          'This means confirmations will be accepted automatically without '
          'your review, which could put your account at risk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SteamColors.warning,
              foregroundColor: SteamColors.darkerBackground,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) onConfirm();
    });
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
}
