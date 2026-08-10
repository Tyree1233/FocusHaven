import 'package:flutter/material.dart';

/// A lifecycle-safe dialog for collecting a single text value.
///
/// The dialog owns its controller, so submitting with Enter cannot dispose the
/// controller while Flutter is still animating the route closed.
class TextEntryDialog extends StatefulWidget {
  const TextEntryDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue = '',
    this.hintText,
    this.helperText,
    this.cancelLabel = 'Cancel',
    this.clearLabel,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.hideCounter = false,
    super.key,
  });

  final String title;
  final String confirmLabel;
  final String initialValue;
  final String? hintText;
  final String? helperText;
  final String? cancelLabel;
  final String? clearLabel;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool hideCounter;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialValue = '',
    String? hintText,
    String? helperText,
    String? cancelLabel = 'Cancel',
    String? clearLabel,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    bool hideCounter = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => TextEntryDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
        hintText: hintText,
        helperText: helperText,
        cancelLabel: cancelLabel,
        clearLabel: clearLabel,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        hideCounter: hideCounter,
      ),
    );
  }

  @override
  State<TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<TextEntryDialog> {
  late final TextEditingController _controller;
  bool _isClosing = false;

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

  void _close([String? value]) {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    Navigator.pop(context, value);
  }

  void _submit() => _close(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_isClosing,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        decoration: InputDecoration(
          hintText: widget.hintText,
          helperText: widget.helperText,
          counterText: widget.hideCounter ? '' : null,
        ),
        onSubmitted: widget.maxLines == 1 && !_isClosing
            ? (_) => _submit()
            : null,
      ),
      actions: [
        if (widget.cancelLabel case final label?)
          TextButton(
            key: const ValueKey<String>('text-entry-cancel'),
            onPressed: _isClosing ? null : () => _close(),
            child: Text(label),
          ),
        if (widget.clearLabel case final label?)
          TextButton(
            key: const ValueKey<String>('text-entry-clear'),
            onPressed: _isClosing ? null : () => _close(''),
            child: Text(label),
          ),
        FilledButton(
          key: const ValueKey<String>('text-entry-submit'),
          onPressed: _isClosing ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
