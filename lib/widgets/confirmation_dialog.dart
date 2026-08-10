import 'package:flutter/material.dart';

class ConfirmationDialog extends StatefulWidget {
  const ConfirmationDialog({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final bool isDestructive;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmationDialog(
            title: title,
            message: message,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            isDestructive: isDestructive,
          ),
        ) ??
        false;
  }

  @override
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  bool _isClosing = false;

  void _close(bool result) {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.message),
      actions: [
        TextButton(
          key: const ValueKey<String>('confirmation-cancel'),
          onPressed: _isClosing ? null : () => _close(false),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: const ValueKey<String>('confirmation-confirm'),
          onPressed: _isClosing ? null : () => _close(true),
          style: widget.isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
