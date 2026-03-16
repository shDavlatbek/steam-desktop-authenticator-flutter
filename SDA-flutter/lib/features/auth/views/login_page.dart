import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sda_flutter/core/models/steam_guard_account.dart';
import 'package:sda_flutter/core/services/steam_auth_service.dart';
import 'package:sda_flutter/core/services/steam_time_service.dart';
import 'package:sda_flutter/features/auth/view_models/login_view_model.dart';
import 'package:sda_flutter/shared/theme/colors.dart';

/// Login screen that drives the Steam credential-based auth flow.
///
/// Supports three modes via [LoginType]:
/// - **initial**: Fresh login for new authenticator setup.
/// - **refresh**: Re-login for expired sessions (username pre-filled).
/// - **import_**: Login for importing an account.
///
/// On success, pops the route and returns the [SessionData] via Navigator.
class LoginPage extends StatefulWidget {
  /// The type of login being performed.
  final LoginType loginType;

  /// An existing account for refresh/import modes.
  final SteamGuardAccount? account;

  const LoginPage({
    super.key,
    this.loginType = LoginType.initial,
    this.account,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final LoginViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _viewModel = LoginViewModel(
      authService: context.read<SteamAuthService>(),
      timeService: SteamTimeService(),
      loginType: widget.loginType,
      account: widget.account,
    );

    _usernameController = TextEditingController(
      text: _viewModel.prefillUsername,
    );
    _passwordController = TextEditingController();

    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});

    switch (_viewModel.state) {
      case LoginState.awaitingEmailCode:
        _showCodeDialog(isEmail: true);
        break;
      case LoginState.awaitingSteamGuardCode:
        _showCodeDialog(isEmail: false);
        break;
      case LoginState.success:
        // Return the session data to the caller.
        Navigator.of(context).pop(_viewModel.session);
        break;
      case LoginState.error:
        _showErrorSnackBar(_viewModel.errorMessage ?? 'An error occurred.');
        break;
      default:
        break;
    }
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _viewModel.login(
      _usernameController.text,
      _passwordController.text,
    );
  }

  void _showCodeDialog({required bool isEmail}) {
    final codeController = TextEditingController();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEmail ? 'Email Code' : 'Steam Guard Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEmail
                    ? 'Enter the code sent to your email address.'
                    : 'Enter your Steam Guard authenticator code.',
                style: const TextStyle(color: SteamColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  hintText: 'XXXXX',
                ),
                onSubmitted: (_) {
                  Navigator.of(dialogContext).pop();
                  _viewModel.submitCode(
                    codeController.text,
                    isEmailCode: isEmail,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _viewModel.reset();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _viewModel.submitCode(
                  codeController.text,
                  isEmailCode: isEmail,
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SteamColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _isLoading =>
      _viewModel.state == LoginState.loggingIn ||
      _viewModel.state == LoginState.polling;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam Login'),
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Steam icon
                  Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: SteamColors.steamBlue,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Steam Login',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),

                  // Explanation text
                  Text(
                    _viewModel.explanationText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SteamColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_viewModel.isUsernameLocked && !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: SteamColors.darkerBackground,
                              ),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status message
                  if (_viewModel.statusText.isNotEmpty)
                    _buildStatusRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    final isError = _viewModel.state == LoginState.error;
    final isPolling = _viewModel.state == LoginState.polling ||
        _viewModel.state == LoginState.loggingIn;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPolling) ...[
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
        if (isError)
          const Icon(Icons.error_outline, size: 16, color: SteamColors.error),
        if (isError) const SizedBox(width: 8),
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
