import 'package:flutter/material.dart';

import 'package:sda_flutter/shared/theme/colors.dart';

/// Email confirmation waiting screen shown during the phone verification flow.
///
/// Displays a message telling the user to confirm the email Steam sent, then
/// provides a button to signal that they have done so.
///
/// Returns `true` via Navigator.pop when the user taps "I've confirmed it",
/// or `null` if cancelled.
class EmailConfirmationPage extends StatefulWidget {
  /// The email address Steam sent the confirmation to.
  final String? emailAddress;

  const EmailConfirmationPage({
    super.key,
    this.emailAddress,
  });

  @override
  State<EmailConfirmationPage> createState() => _EmailConfirmationPageState();
}

class _EmailConfirmationPageState extends State<EmailConfirmationPage> {
  bool _isChecking = false;

  void _handleConfirmed() {
    setState(() {
      _isChecking = true;
    });
    // Return true to indicate the user says they confirmed.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.emailAddress ?? 'your email address';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Confirmation'),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                const Icon(
                  Icons.email_outlined,
                  size: 64,
                  color: SteamColors.steamBlue,
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Confirm Your Email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),

                // Message
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SteamColors.textSecondary,
                          height: 1.5,
                        ),
                    children: [
                      const TextSpan(
                        text: 'Steam has sent a confirmation email to ',
                      ),
                      TextSpan(
                        text: email,
                        style: const TextStyle(
                          color: SteamColors.steamBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text: '.\n\nPlease open the email and click the '
                            'confirmation link, then tap the button below.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Confirm button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _handleConfirmed,
                    child: _isChecking
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: SteamColors.darkerBackground,
                            ),
                          )
                        : const Text("I've Confirmed It"),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel button
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        _isChecking ? null : () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 24),

                // Help text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SteamColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: SteamColors.divider),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: SteamColors.steamBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Check your spam folder if you don\'t see the email. '
                          'The email is from Steam and may take a moment to '
                          'arrive.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: SteamColors.textSecondary,
                                    height: 1.4,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
