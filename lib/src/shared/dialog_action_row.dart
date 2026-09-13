import 'package:flutter/material.dart';

class DialogActionRow extends StatelessWidget {
  const DialogActionRow({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
    super.key,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onCancel,
            child: Text(cancelLabel, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: onConfirm,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel, textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
  );
}
