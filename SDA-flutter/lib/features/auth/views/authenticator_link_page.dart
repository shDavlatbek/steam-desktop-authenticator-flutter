import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/session_data.dart';
import '../../../core/models/steam_guard_account.dart';
import '../../../core/services/steam_time_service.dart';
import '../../../core/services/steam_web_service.dart';
import '../../../shared/theme/colors.dart';
import '../view_models/authenticator_linker_vm.dart';

/// Full-screen page that drives the authenticator linking flow.
/// Returns the linked [SteamGuardAccount] on success via Navigator.pop.
class AuthenticatorLinkPage extends StatefulWidget {
  final SessionData session;

  const AuthenticatorLinkPage({super.key, required this.session});

  @override
  State<AuthenticatorLinkPage> createState() => _AuthenticatorLinkPageState();
}

class _AuthenticatorLinkPageState extends State<AuthenticatorLinkPage> {
  late final AuthenticatorLinkerViewModel _vm;
  final _smsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = AuthenticatorLinkerViewModel(
      web: context.read<SteamWebService>(),
      timeService: SteamTimeService(),
    );
    _vm.addListener(_onStateChanged);
    _vm.startLinking(widget.session);
  }

  @override
  void dispose() {
    _vm.removeListener(_onStateChanged);
    _vm.dispose();
    _smsController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Authenticator'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildContent(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_vm.state) {
      case LinkingState.idle:
      case LinkingState.checkingPhone:
      case LinkingState.addingAuthenticator:
      case LinkingState.finalizing:
        return _buildLoading(_vm.statusText);

      case LinkingState.mustProvidePhone:
      case LinkingState.mustConfirmEmail:
      case LinkingState.enterSmsCode:
        // Phone flow bypassed — these states shouldn't be reached.
        return _buildLoading(_vm.statusText);

      case LinkingState.showRevocationCode:
        return _buildRevocationCode(theme);

      case LinkingState.awaitingFinalization:
        return _buildSmsCodeEntry(theme);

      case LinkingState.success:
        return _buildSuccess(theme);

      case LinkingState.error:
        return _buildError(theme);
    }
  }

  // ── Loading ──────────────────────────────────────────────────────────

  Widget _buildLoading(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
      ],
    );
  }

  // ── SMS code entry (finalization) ─────────────────────────────────────

  Widget _buildSmsCodeEntry(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sms_outlined, size: 48,
            color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Finalize Authenticator',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Enter the activation code sent to your email or phone to '
          'finalize the authenticator.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _smsController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: 'Activation Code',
            hintText: '12345',
          ),
          onSubmitted: (_) => _submitFinalize(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitFinalize,
            child: const Text('Finalize'),
          ),
        ),
      ],
    );
  }

  void _submitFinalize() {
    final code = _smsController.text;
    _smsController.clear();
    _vm.finalizeAuthenticator(code);
  }

  // ── Revocation code ──────────────────────────────────────────────────

  Widget _buildRevocationCode(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.key, size: 48, color: SteamColors.warning),
        const SizedBox(height: 16),
        Text('Save Your Revocation Code',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Write this code down and keep it safe! You will need it to '
          'remove the authenticator from your account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: SteamColors.warning.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SteamColors.warning.withAlpha(80)),
          ),
          child: SelectableText(
            _vm.revocationCode ?? '-----',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: _vm.revocationCode ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revocation code copied')),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to clipboard'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _smsController.clear();
              _vm.proceedToFinalization();
            },
            child: const Text('I\'ve Saved the Code — Continue'),
          ),
        ),
      ],
    );
  }

  // ── Success ──────────────────────────────────────────────────────────

  Widget _buildSuccess(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 64, color: SteamColors.steamGreen),
        const SizedBox(height: 16),
        Text('Authenticator Linked!',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Steam Guard has been successfully added to your account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(_vm.linkedAccount),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  // ── Error ────────────────────────────────────────────────────────────

  Widget _buildError(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48,
            color: SteamColors.error),
        const SizedBox(height: 16),
        Text('Error', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          _vm.errorMessage ?? 'An unknown error occurred.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SteamColors.error),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _vm.reset();
              _vm.startLinking(widget.session);
            },
            child: const Text('Retry'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
