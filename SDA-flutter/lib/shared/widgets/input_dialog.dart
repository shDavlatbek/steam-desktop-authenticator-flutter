import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Shows a generic input dialog that prompts the user for a single text value.
///
/// This replaces the C# `InputForm` with a Material dialog. Returns the
/// entered text, or `null` if the user cancelled.
///
/// [message] - Descriptive label shown above the text field.
/// [isPassword] - When `true`, the text field obscures input and shows a
///   visibility toggle.
/// [confirmButtonText] - Custom label for the submit button (defaults to "OK").
/// [initialValue] - Pre-filled value for the text field.
Future<String?> showInputDialog(
  BuildContext context, {
  required String message,
  bool isPassword = false,
  String? confirmButtonText,
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InputDialog(
      message: message,
      isPassword: isPassword,
      confirmButtonText: confirmButtonText ?? 'OK',
      initialValue: initialValue,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  final String message;
  final bool isPassword;
  final String confirmButtonText;
  final String? initialValue;

  const _InputDialog({
    required this.message,
    required this.isPassword,
    required this.confirmButtonText,
    this.initialValue,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.isNotEmpty) {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(
              color: SteamColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.isPassword && _obscure,
            decoration: InputDecoration(
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: SteamColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmButtonText),
        ),
      ],
    );
  }
}
