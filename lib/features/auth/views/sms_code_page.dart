import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sda_flutter/shared/theme/colors.dart';

/// SMS verification code entry screen.
///
/// Used during both the phone verification step (adding a phone number) and
/// the authenticator finalization step (activating the new authenticator).
///
/// Returns the entered code as a [String] via Navigator.pop, or null if
/// cancelled.
class SmsCodePage extends StatefulWidget {
  /// A message displayed to the user explaining which SMS code to enter.
  final String message;

  /// Optional title override. Defaults to "SMS Verification".
  final String title;

  const SmsCodePage({
    super.key,
    this.message = 'Enter the SMS code sent to your phone.',
    this.title = 'SMS Verification',
  });

  @override
  State<SmsCodePage> createState() => _SmsCodePageState();
}

class _SmsCodePageState extends State<SmsCodePage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_codeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                  // Icon
                  const Icon(
                    Icons.sms_outlined,
                    size: 64,
                    color: SteamColors.steamBlue,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),

                  // Message
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SteamColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Code input
                  TextFormField(
                    controller: _codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'Enter code',
                      prefixIcon: Icon(Icons.dialpad),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      child: const Text('Submit'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel button
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
