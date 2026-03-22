import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/manifest.dart';
import '../../../core/repositories/manifest_repository.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Handles exporting .maFile account files and manifest.json.
class ExportViewModel extends ChangeNotifier {
  final ManifestRepository _manifestRepo;

  ExportViewModel({required ManifestRepository manifestRepo})
      : _manifestRepo = manifestRepo;

  bool isExporting = false;
  String? errorMessage;
  String? successMessage;

  /// Exports selected accounts (by steamId) to a user-chosen directory.
  /// If [selectedSteamIds] is null or empty, exports all accounts.
  Future<void> exportAccounts({Set<int>? selectedSteamIds}) async {
    isExporting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final manifest = await _manifestRepo.getManifest();
      final maDir = await _manifestRepo.getMaFilesDir();

      // Filter entries to export
      final entriesToExport = selectedSteamIds == null || selectedSteamIds.isEmpty
          ? manifest.entries
          : manifest.entries
              .where((e) => selectedSteamIds.contains(e.steamId))
              .toList();

      if (entriesToExport.isEmpty) {
        errorMessage = 'No accounts to export.';
        isExporting = false;
        notifyListeners();
        return;
      }

      // Pick destination
      final destPath = await _pickExportDirectory();
      if (destPath == null) {
        isExporting = false;
        notifyListeners();
        return;
      }

      int exported = 0;

      // Copy each maFile
      for (final entry in entriesToExport) {
        final srcFile = File('$maDir/${entry.filename}');
        if (!await srcFile.exists()) continue;
        final destFile = File('$destPath/${entry.filename}');
        await srcFile.copy(destFile.path);
        exported++;
      }

      // Build a manifest.json with only the exported entries
      final exportManifest = Manifest(
        encrypted: manifest.encrypted,
        firstRun: false,
        entries: entriesToExport.toList(),
        periodicChecking: manifest.periodicChecking,
        periodicCheckingInterval: manifest.periodicCheckingInterval,
        checkAllAccounts: manifest.checkAllAccounts,
        autoConfirmMarketTransactions: manifest.autoConfirmMarketTransactions,
        autoConfirmTrades: manifest.autoConfirmTrades,
      );
      final manifestFile = File('$destPath/manifest.json');
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportManifest.toJson()),
      );

      successMessage = 'Exported $exported account(s) to ${_isAndroid ? 'Downloads' : destPath}';
    } catch (e) {
      errorMessage = e.toString();
    }

    isExporting = false;
    notifyListeners();
  }

  /// Returns a directory path for export.
  /// On Android uses Downloads directory; on desktop uses a folder picker.
  Future<String?> _pickExportDirectory() async {
    if (_isAndroid) {
      // On Android, use a subdirectory in external storage Downloads
      final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        final exportDir = Directory('${dirs.first.path}/SDA-Export');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        return exportDir.path;
      }
      // Fallback: app support directory
      final appDir = await getApplicationSupportDirectory();
      final exportDir = Directory('${appDir.path}/SDA-Export');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      return exportDir.path;
    } else {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Directory',
      );
    }
  }
}
