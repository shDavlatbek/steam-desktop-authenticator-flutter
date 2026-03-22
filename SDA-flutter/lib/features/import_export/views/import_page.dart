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

/// Page for importing .maFile account files, either individually or from
/// an existing SDA directory.
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  late final ImportViewModel _viewModel;
  final _encryptionKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ImportViewModel(
      manifestRepo: context.read<ManifestRepository>(),
    );
  }

  @override
  void dispose() {
    _encryptionKeyController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(title: const Text('Import Accounts')),
        body: Consumer<ImportViewModel>(
          builder: (context, vm, _) {
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Description ────────────────────────────────
                      const Text(
                        'Import Steam Guard accounts from .maFile files or '
                        'from an existing Steam Desktop Authenticator directory.',
                        style: TextStyle(
                          color: SteamColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Encryption key field ───────────────────────
                      _sectionHeader('Encryption Key (optional)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _encryptionKeyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: 'Encryption key',
                          hintText: 'Leave blank if files are not encrypted',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: SteamColors.textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Import single file ─────────────────────────
                      _sectionHeader('Import Single File'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: vm.isImporting
                              ? null
                              : () => vm.importMaFile(
                                    encryptionKey:
                                        _encryptionKeyController.text.isNotEmpty
                                            ? _encryptionKeyController.text
                                            : null,
                                  ),
                          icon: const Icon(Icons.file_open, size: 18),
                          label: const Text('Select .maFile'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Import from directory / multi-pick ─────────
                      _sectionHeader('Import Multiple Files'),
                      const SizedBox(height: 8),
                      Text(
                        _isAndroid
                            ? 'Select multiple .maFile files to import at once.'
                            : 'Select an existing SDA maFiles directory to import '
                                'all account files at once.',
                        style: const TextStyle(
                          color: SteamColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: vm.isImporting
                              ? null
                              : _isAndroid
                                  ? () => vm.importFromMultiPick()
                                  : _pickAndImportDirectory,
                          icon: Icon(
                            _isAndroid ? Icons.file_copy : Icons.folder_open,
                            size: 18,
                          ),
                          label: Text(
                              _isAndroid ? 'Select Files' : 'Select Directory'),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Messages ───────────────────────────────────
                      if (vm.errorMessage != null)
                        _messageBanner(vm.errorMessage!, isError: true),
                      if (vm.successMessage != null)
                        _messageBanner(vm.successMessage!, isError: false),
                    ],
                  ),
                ),

                if (vm.isImporting)
                  const LoadingOverlay(message: 'Importing...'),
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

  Future<void> _pickAndImportDirectory() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select SDA maFiles Directory',
    );
    if (dirPath != null) {
      await _viewModel.importFromDirectory(dirPath);
    }
  }
}
