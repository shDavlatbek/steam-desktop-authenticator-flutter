import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/repositories/manifest_repository.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../view_models/import_view_model.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// First-run welcome screen shown when no accounts exist yet.
///
/// Offers the user the choice to get started with a fresh setup or import
/// an existing SDA configuration directory.
class WelcomePage extends StatefulWidget {
  /// Called when the user finishes onboarding and should be taken to the
  /// main home screen.
  final VoidCallback onGetStarted;

  const WelcomePage({super.key, required this.onGetStarted});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final ImportViewModel _importVm;

  @override
  void initState() {
    super.initState();
    _importVm = ImportViewModel(
      manifestRepo: context.read<ManifestRepository>(),
    );
  }

  @override
  void dispose() {
    _importVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _importVm,
      child: Scaffold(
        body: Consumer<ImportViewModel>(
          builder: (context, vm, _) {
            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo / icon area ─────────────────────────
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: SteamColors.steamBlue.withAlpha(25),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.security,
                            size: 48,
                            color: SteamColors.steamBlue,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Title ────────────────────────────────────
                        const Text(
                          'Welcome to',
                          style: TextStyle(
                            color: SteamColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Steam Desktop\nAuthenticator',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: SteamColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'A free, open-source implementation of Steam\'s '
                          'mobile authenticator for your desktop.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: SteamColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── Get Started button ───────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                vm.isImporting ? null : widget.onGetStarted,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Get Started'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Import button ────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                vm.isImporting ? null : _importExistingConfig,
                            icon: Icon(
                              _isAndroid
                                  ? Icons.file_copy
                                  : Icons.folder_open,
                              size: 18,
                            ),
                            label: Text(_isAndroid
                                ? 'Import .maFile Files'
                                : 'Import Existing Config'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),

                        // ── Status messages ──────────────────────────
                        if (vm.errorMessage != null) ...[
                          const SizedBox(height: 24),
                          _messageBanner(vm.errorMessage!, isError: true),
                        ],
                        if (vm.successMessage != null) ...[
                          const SizedBox(height: 24),
                          _messageBanner(vm.successMessage!, isError: false),
                        ],
                      ],
                    ),
                  ),
                ),

                if (vm.isImporting)
                  const LoadingOverlay(
                      message: 'Importing configuration...'),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _messageBanner(String message, {required bool isError}) {
    final color = isError ? SteamColors.error : SteamColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _importExistingConfig() async {
    if (_isAndroid) {
      // Android can't traverse SAF directories — use multi-file picker instead.
      await _importVm.importFromMultiPick();
    } else {
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select SDA maFiles Directory',
      );
      if (dirPath == null) return;
      await _importVm.importFromDirectory(dirPath);
    }

    // If import was successful, proceed to the home screen.
    if (_importVm.errorMessage == null && _importVm.successMessage != null) {
      if (mounted) {
        widget.onGetStarted();
      }
    }
  }
}
