import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Asks for one line (or a short note) of text. Resolves to the trimmed text,
/// or null when the user cancels or dismisses the dialog.
///
/// The text controller lives inside the dialog's own State, so it is disposed
/// only after the dialog has fully left the screen. Disposing it from the
/// caller (when the route future completes) crashes the closing animation.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String actionLabel,
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  int? maxLength,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
  String? Function(String text)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      label: label,
      actionLabel: actionLabel,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String actionLabel;
  final String? hint;
  final String initialValue;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String text)? validator;

  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.actionLabel,
    required this.hint,
    required this.initialValue,
    required this.maxLines,
    required this.maxLength,
    required this.textCapitalization,
    required this.validator,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialValue,
  );

  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = controller.text.trim();
    final problem = widget.validator?.call(text);

    if (problem != null) {
      setState(() => error = problem);
      return;
    }

    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          errorText: error,
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: VendrgoColors.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
