import 'package:flutter/material.dart';

import '../../../shared/theme/colors.dart';

/// Shows a dialog that prompts the user for a passkey.
///
/// When [requireConfirmation] is `true` a second "Confirm passkey" field is
/// shown and the dialog will only return a value when both fields match.
///
/// Returns the entered passkey, or `null` if the user cancelled.
Future<String?> showPasskeyDialog(
  BuildContext context, {
  String title = 'Enter Passkey',
  bool requireConfirmation = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PasskeyDialog(
      title: title,
      requireConfirmation: requireConfirmation,
    ),
  );
}

class _PasskeyDialog extends StatefulWidget {
  final String title;
  final bool requireConfirmation;

  const _PasskeyDialog({
    required this.title,
    required this.requireConfirmation,
  });

  @override
  State<_PasskeyDialog> createState() => _PasskeyDialogState();
}

class _PasskeyDialogState extends State<_PasskeyDialog> {
  final _passkeyController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePasskey = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void dispose() {
    _passkeyController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final passkey = _passkeyController.text;

    if (passkey.isEmpty) {
      setState(() => _errorText = 'Passkey cannot be empty.');
      return;
    }

    if (widget.requireConfirmation) {
      if (_confirmController.text != passkey) {
        setState(() => _errorText = 'Passkeys do not match.');
        return;
      }
    }

    Navigator.of(context).pop(passkey);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passkeyController,
            obscureText: _obscurePasskey,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Passkey',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasskey ? Icons.visibility_off : Icons.visibility,
                  color: SteamColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePasskey = !_obscurePasskey),
              ),
            ),
            onSubmitted: widget.requireConfirmation ? null : (_) => _submit(),
          ),
          if (widget.requireConfirmation) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Passkey',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: SteamColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: const TextStyle(color: SteamColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
