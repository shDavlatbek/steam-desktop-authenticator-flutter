import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:sda_flutter/core/models/steam_guard_account.dart';
import 'package:sda_flutter/core/repositories/login_approval_repository.dart';
import 'package:sda_flutter/features/auth/view_models/qr_approval_view_model.dart';
import 'package:sda_flutter/shared/theme/colors.dart';

/// Approves a Steam login started on another device, the way the official
/// Steam mobile app does when it scans a login QR code.
///
/// Camera scanning is only available where `mobile_scanner` has a
/// implementation — notably not Windows — so desktop falls back to pasting the
/// `s.team` URL.
class QrApprovalPage extends StatefulWidget {
  /// The account that will sign the approval.
  final SteamGuardAccount account;

  final LoginApprovalRepository repository;

  const QrApprovalPage({
    super.key,
    required this.account,
    required this.repository,
  });

  @override
  State<QrApprovalPage> createState() => _QrApprovalPageState();
}

class _QrApprovalPageState extends State<QrApprovalPage> {
  late final QrApprovalViewModel _viewModel;
  MobileScannerController? _scannerController;
  final TextEditingController _urlController = TextEditingController();

  /// Where the user last tapped to focus, in preview coordinates. Drives the
  /// reticle; cleared implicitly when the animation finishes.
  Offset? _focusPoint;

  /// Bumped on every tap so the reticle animation restarts even when the user
  /// taps the same spot twice.
  int _focusTick = 0;

  /// Platforms where mobile_scanner can drive a camera.
  static bool get _cameraSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _viewModel = QrApprovalViewModel(
      repository: widget.repository,
      account: widget.account,
    )..addListener(_onViewModelChanged);

    if (_cameraSupported && _viewModel.canApprove) {
      _scannerController = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _scannerController?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _viewModel.submitCode(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve QR login'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_viewModel.canApprove) return _buildCannotApprove();

    switch (_viewModel.state) {
      case QrApprovalState.awaitingCode:
      case QrApprovalState.error:
        return _buildCaptureStep();
      case QrApprovalState.decodingImage:
      case QrApprovalState.loadingInfo:
        return _buildBusy();
      case QrApprovalState.awaitingDecision:
      case QrApprovalState.submitting:
        return _buildDecisionStep();
      case QrApprovalState.approved:
      case QrApprovalState.denied:
        return _buildOutcome();
    }
  }

  Widget _buildCannotApprove() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.key_off_outlined, size: 48, color: SteamColors.error),
        const SizedBox(height: 16),
        Text(
          'This account cannot approve logins',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Approving requires the account\'s shared secret and an active '
          'session. Import its .maFile, or use "Login Again" first.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: SteamColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCaptureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Approving as ${widget.account.accountName ?? 'this account'}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: SteamColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_scannerController != null) ...[
          _buildScanner(_scannerController!),
          const SizedBox(height: 16),
          _buildDivider('or'),
          const SizedBox(height: 16),
        ] else ...[
          const Icon(Icons.qr_code_scanner,
              size: 48, color: SteamColors.steamBlue),
          const SizedBox(height: 12),
          Text(
            'Camera scanning is not available on this platform. Choose a '
            'screenshot of the code, or paste its link.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: SteamColors.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose QR image'),
          ),
        ),
        const SizedBox(height: 16),
        _buildDivider('or paste the link'),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Login link',
            hintText: 'https://s.team/q/1/...',
            prefixIcon: Icon(Icons.link),
          ),
          onSubmitted: _viewModel.submitCode,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: () => _viewModel.submitCode(_urlController.text),
            child: const Text('Continue'),
          ),
        ),
        if (_viewModel.state == QrApprovalState.error) ...[
          const SizedBox(height: 16),
          _buildMessageRow(_viewModel.statusText, isError: true),
        ],
      ],
    );
  }

  /// The live camera preview, with a torch toggle and tap-to-focus.
  Widget _buildScanner(MobileScannerController controller) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 260,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              // Opaque so taps on the camera texture still reach us.
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _onScannerTap(
                details,
                Size(constraints.maxWidth, constraints.maxHeight),
                controller,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => _buildScannerError(error),
                  ),
                  if (_focusPoint != null) _buildFocusReticle(),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildTorchButton(controller),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text(
                        'Tap to focus',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Focuses the camera where the user tapped. [setFocusPoint] wants the point
  /// normalised to 0..1 within the preview.
  void _onScannerTap(
    TapDownDetails details,
    Size previewSize,
    MobileScannerController controller,
  ) {
    if (previewSize.width <= 0 || previewSize.height <= 0) return;

    final local = details.localPosition;
    controller.setFocusPoint(
      Offset(local.dx / previewSize.width, local.dy / previewSize.height),
    );

    setState(() {
      _focusPoint = local;
      _focusTick++;
    });
  }

  /// A reticle that pulses once where the user tapped, then fades out.
  Widget _buildFocusReticle() {
    const size = 56.0;

    return Positioned(
      left: _focusPoint!.dx - size / 2,
      top: _focusPoint!.dy - size / 2,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          // Keyed on the tap count so tapping the same spot replays it.
          key: ValueKey(_focusTick),
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.85 + 0.25 * t, child: child),
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: SteamColors.steamBlue, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  /// Torch toggle, hidden entirely on devices without one.
  Widget _buildTorchButton(MobileScannerController controller) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }

        final isOn = state.torchState == TorchState.on;
        return Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: isOn ? 'Turn flash off' : 'Turn flash on',
            icon: Icon(
              isOn ? Icons.flash_on : Icons.flash_off,
              color: isOn ? Colors.amberAccent : Colors.white,
            ),
            onPressed: controller.toggleTorch,
          ),
        );
      },
    );
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: SteamColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  /// Picks a QR image from the gallery (Android) or disk, and decodes it.
  ///
  /// Requests the bytes directly rather than a path: on Android the picker
  /// hands back a SAF content URI that `dart:io` cannot open.
  Future<void> _pickImage() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        dialogTitle: 'Choose a QR code image',
      );
    } catch (e) {
      if (mounted) _showSnack('Could not open the image picker: $e');
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null) {
      if (mounted) _showSnack('Could not read that image.');
      return;
    }

    await _viewModel.submitImage(bytes);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SteamColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildScannerError(MobileScannerException error) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isPermission
                ? 'Camera permission denied. Grant it in system settings, or '
                    'paste the login link below.'
                : 'Camera unavailable. Paste the login link below.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildBusy() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: SteamColors.steamBlue),
        const SizedBox(height: 16),
        Text(
          _viewModel.statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: SteamColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDecisionStep() {
    final info = _viewModel.info;
    final isSubmitting = _viewModel.state == QrApprovalState.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info != null && info.isSuspicious) ...[
          _buildWarningBanner(),
          const SizedBox(height: 16),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Login request',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.devices, 'Device',
                    info?.deviceFriendlyName ?? 'Unknown device'),
                _buildInfoRow(Icons.public, 'Platform',
                    info?.platformName ?? 'Unknown'),
                _buildInfoRow(Icons.place_outlined, 'Location',
                    info?.location ?? 'Unknown'),
                _buildInfoRow(
                    Icons.router_outlined, 'IP', info?.ip ?? 'Unknown'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => _viewModel.respond(approve: false),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: SteamColors.error),
                  child: const Text('Deny'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => _viewModel.respond(approve: true),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: SteamColors.darkerBackground,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SteamColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SteamColors.error.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: SteamColors.error),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Steam flagged this request as unusual — it came from an '
              'unfamiliar location or device. Deny it if it was not you.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: SteamColors.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                  color: SteamColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildOutcome() {
    final approved = _viewModel.state == QrApprovalState.approved;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          approved ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 56,
          color: approved ? SteamColors.success : SteamColors.textSecondary,
        ),
        const SizedBox(height: 16),
        Text(
          _viewModel.statusText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
        TextButton(
          onPressed: _viewModel.reset,
          child: const Text('Scan another code'),
        ),
      ],
    );
  }

  Widget _buildMessageRow(String message, {bool isError = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isError) ...[
          const Icon(Icons.error_outline, size: 16, color: SteamColors.error),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isError ? SteamColors.error : SteamColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
