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
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
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
    _phoneController.dispose();
    _countryController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});

    if (_vm.state == LinkingState.mustProvidePhone &&
        _vm.detectedCountryCode != null &&
        _countryController.text.isEmpty) {
      _countryController.text = _vm.detectedCountryCode!;
    }
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
        return _buildPhoneInput(theme);

      case LinkingState.mustConfirmEmail:
        return _buildEmailConfirmation(theme);

      case LinkingState.enterSmsCode:
        return _buildSmsCodeEntry(theme, isFinalization: false);

      case LinkingState.showRevocationCode:
        return _buildRevocationCode(theme);

      case LinkingState.awaitingFinalization:
        return _buildSmsCodeEntry(theme, isFinalization: true);

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

  // ── Phone input ──────────────────────────────────────────────────────

  Widget _buildPhoneInput(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.phone_android, size: 48,
            color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Phone Number Required',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'A verified phone number is required to add Steam Guard. '
          'Enter your phone number below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _countryController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Country Code',
            hintText: 'US',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
            LengthLimitingTextInputFormatter(2),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+1234567890',
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _vm.setPhoneNumber(
              _phoneController.text,
              _countryController.text,
            ),
            child: const Text('Submit Phone Number'),
          ),
        ),
        const SizedBox(height: 12),
        // Option to skip phone if the account might already have one
        TextButton(
          onPressed: () => _vm.startLinking(widget.session),
          child: const Text('Retry without phone'),
        ),
      ],
    );
  }

  // ── Email confirmation ───────────────────────────────────────────────

  Widget _buildEmailConfirmation(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.email_outlined, size: 48,
            color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Confirm Your Email',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          _vm.confirmationEmailAddress != null
              ? 'Steam sent a confirmation link to ${_vm.confirmationEmailAddress}. '
                'Click the link in the email, then press the button below.'
              : 'Check your email and click the confirmation link from Steam, '
                'then press the button below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _vm.confirmEmailDone,
            child: const Text('I\'ve Confirmed the Email'),
          ),
        ),
      ],
    );
  }

  // ── SMS code entry (for phone verification OR finalization) ──────────

  Widget _buildSmsCodeEntry(ThemeData theme,
      {required bool isFinalization}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sms_outlined, size: 48,
            color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(isFinalization ? 'Finalize Authenticator' : 'Verify Phone',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          isFinalization
              ? 'Enter the SMS code sent to your phone to finalize the authenticator.'
              : 'Enter the SMS verification code sent to your phone.',
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
            labelText: 'SMS Code',
            hintText: '12345',
          ),
          onSubmitted: (_) => _submitSms(isFinalization),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _submitSms(isFinalization),
            child: Text(isFinalization ? 'Finalize' : 'Verify'),
          ),
        ),
      ],
    );
  }

  void _submitSms(bool isFinalization) {
    final code = _smsController.text;
    _smsController.clear();
    if (isFinalization) {
      _vm.finalizeAuthenticator(code);
    } else {
      _vm.submitPhoneSmsCode(code);
    }
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
