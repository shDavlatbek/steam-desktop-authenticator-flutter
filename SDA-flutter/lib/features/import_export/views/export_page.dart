import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/manifest.dart';
import '../../../core/repositories/manifest_repository.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../view_models/export_view_model.dart';

/// Page for exporting .maFile account files and manifest.json.
/// Allows exporting all accounts or selecting specific ones.
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  late final ExportViewModel _viewModel;
  final Set<int> _selectedSteamIds = {};
  List<ManifestEntry> _entries = [];
  bool _isLoading = true;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ExportViewModel(
      manifestRepo: context.read<ManifestRepository>(),
    );
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final manifest =
        await context.read<ManifestRepository>().getManifest();
    setState(() {
      _entries = manifest.entries;
      _selectedSteamIds.addAll(_entries.map((e) => e.steamId));
      _isLoading = false;
    });
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
        appBar: AppBar(title: const Text('Export Accounts')),
        body: Consumer<ExportViewModel>(
          builder: (context, vm, _) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              children: [
                Column(
                  children: [
                    // ── Select all toggle ──────────────────────────────
                    Card(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: CheckboxListTile(
                        title: const Text('Select All',
                            style:
                                TextStyle(color: SteamColors.textPrimary)),
                        subtitle: Text(
                          '${_selectedSteamIds.length} of ${_entries.length} selected',
                          style: const TextStyle(
                              color: SteamColors.textSecondary,
                              fontSize: 12),
                        ),
                        value: _selectAll,
                        onChanged: (val) {
                          setState(() {
                            _selectAll = val ?? false;
                            if (_selectAll) {
                              _selectedSteamIds
                                  .addAll(_entries.map((e) => e.steamId));
                            } else {
                              _selectedSteamIds.clear();
                            }
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Account list ───────────────────────────────────
                    Expanded(
                      child: _entries.isEmpty
                          ? const Center(
                              child: Text(
                                'No accounts to export.',
                                style: TextStyle(
                                    color: SteamColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                final selected = _selectedSteamIds
                                    .contains(entry.steamId);
                                return Card(
                                  child: CheckboxListTile(
                                    title: Text(
                                      entry.filename,
                                      style: const TextStyle(
                                          color: SteamColors.textPrimary,
                                          fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Steam ID: ${entry.steamId}',
                                      style: const TextStyle(
                                          color: SteamColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                    value: selected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedSteamIds
                                              .add(entry.steamId);
                                        } else {
                                          _selectedSteamIds
                                              .remove(entry.steamId);
                                        }
                                        _selectAll =
                                            _selectedSteamIds.length ==
                                                _entries.length;
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),

                    // ── Messages ───────────────────────────────────────
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _messageBanner(vm.errorMessage!,
                            isError: true),
                      ),
                    if (vm.successMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _messageBanner(vm.successMessage!,
                            isError: false),
                      ),

                    // ── Export button ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: vm.isExporting ||
                                  _selectedSteamIds.isEmpty
                              ? null
                              : () => _viewModel.exportAccounts(
                                    selectedSteamIds:
                                        _selectAll ? null : _selectedSteamIds,
                                  ),
                          icon: const Icon(Icons.file_upload_outlined,
                              size: 18),
                          label: Text(_selectAll
                              ? 'Export All (${_entries.length})'
                              : 'Export Selected (${_selectedSteamIds.length})'),
                        ),
                      ),
                    ),
                  ],
                ),

                if (vm.isExporting)
                  const LoadingOverlay(message: 'Exporting...'),
              ],
            );
          },
        ),
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
}
