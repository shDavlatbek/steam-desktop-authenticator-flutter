import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sda_flutter/shared/theme/colors.dart';

/// Phone number input screen used during authenticator setup.
///
/// Collects the user's country code (ISO 3166-1 alpha-2, e.g. "US") and
/// phone number (international format, e.g. "+1 555 123 4567").
///
/// Returns a [PhoneInputResult] via Navigator.pop when submitted, or null
/// if cancelled.
class PhoneInputPage extends StatefulWidget {
  /// An auto-detected country code to pre-fill, if available.
  final String? initialCountryCode;

  const PhoneInputPage({
    super.key,
    this.initialCountryCode,
  });

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

/// Result returned when the user submits a phone number.
class PhoneInputResult {
  final String phoneNumber;
  final String countryCode;

  const PhoneInputResult({
    required this.phoneNumber,
    required this.countryCode,
  });
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  late final TextEditingController _countryCodeController;
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _countryCodeController = TextEditingController(
      text: widget.initialCountryCode ?? '',
    );
    _phoneController = TextEditingController(text: '+');
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      PhoneInputResult(
        phoneNumber: _phoneController.text.trim(),
        countryCode: _countryCodeController.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Number'),
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
                    Icons.phone_android,
                    size: 64,
                    color: SteamColors.steamBlue,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Add Phone Number',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'A verified phone number is required to add a Steam Guard '
                    'authenticator. Enter your phone number below.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SteamColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Country code field
                  TextFormField(
                    controller: _countryCodeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      LengthLimitingTextInputFormatter(2),
                      _UpperCaseTextFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Country Code',
                      hintText: 'US',
                      prefixIcon: Icon(Icons.flag_outlined),
                      helperText: '2-letter country code (e.g. US, GB, DE)',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().length != 2) {
                        return 'Enter a 2-letter country code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone number field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+1 555 123 4567',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText:
                          'International format starting with + (digits and spaces only)',
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      final trimmed = value.trim();
                      if (!trimmed.startsWith('+')) {
                        return 'Phone number must start with +';
                      }
                      // Remove spaces and the leading + for digit counting.
                      final digitsOnly =
                          trimmed.substring(1).replaceAll(' ', '');
                      if (digitsOnly.length < 7) {
                        return 'Phone number is too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

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

/// Text input formatter that converts lowercase letters to uppercase.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
