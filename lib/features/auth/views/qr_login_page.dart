import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sda_flutter/core/services/steam_auth_service.dart';
import 'package:sda_flutter/features/auth/view_models/qr_login_view_model.dart';
import 'package:sda_flutter/shared/theme/colors.dart';

/// Password-free login: shows a Steam challenge as a QR code, waits for the
/// user to approve it in the official Steam mobile app, and pops the resulting
/// [SessionData] — the same return contract as [LoginPage], so callers can use
/// either interchangeably.
class QrLoginPage extends StatefulWidget {
  const QrLoginPage({super.key});

  @override
  State<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends State<QrLoginPage> {
  late final QrLoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = QrLoginViewModel(authService: context.read<SteamAuthService>())
      ..addListener(_onViewModelChanged);
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});

    if (_viewModel.state == QrLoginState.success) {
      Navigator.of(context).pop(_viewModel.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with QR code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Open the Steam mobile app, tap the QR icon, and scan '
                  'this code. No password needed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SteamColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                Center(child: _buildQrArea()),
                const SizedBox(height: 24),
                _buildStatusRow(),
                if (_viewModel.state == QrLoginState.expired ||
                    _viewModel.state == QrLoginState.error) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _viewModel.start,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Get a new code'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrArea() {
    const size = 240.0;
    final url = _viewModel.challengeUrl;

    // The QR is always rendered dark-on-white regardless of app theme —
    // inverted codes are unreliable with some phone cameras.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: url == null
          ? const Center(
              child: CircularProgressIndicator(color: SteamColors.steamBlue),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: size - 24,
                  backgroundColor: Colors.white,
                  // A stale code is still a valid code — dim it rather than
                  // removing it, so the layout doesn't jump.
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: _isStale ? Colors.black26 : Colors.black,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: _isStale ? Colors.black26 : Colors.black,
                  ),
                ),
                if (_isStale)
                  const Icon(Icons.refresh, size: 48, color: Colors.black45),
              ],
            ),
    );
  }

  bool get _isStale =>
      _viewModel.state == QrLoginState.expired ||
      _viewModel.state == QrLoginState.error;

  Widget _buildStatusRow() {
    final state = _viewModel.state;
    final isError = state == QrLoginState.error;
    final isWaiting = state == QrLoginState.starting ||
        state == QrLoginState.waitingForScan ||
        state == QrLoginState.scanned ||
        state == QrLoginState.success;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isWaiting) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SteamColors.steamBlue,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (isError) ...[
          const Icon(Icons.error_outline, size: 16, color: SteamColors.error),
          const SizedBox(width: 8),
        ],
        if (state == QrLoginState.expired) ...[
          const Icon(Icons.timer_off_outlined,
              size: 16, color: SteamColors.textSecondary),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            _viewModel.statusText,
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
