import 'package:flutter/material.dart';

class GlassAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<Widget>? actions;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;

  const GlassAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.onConfirm,
    this.onCancel,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (actions != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: actions!,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        child: Text(cancelText),
                      ),
                    if (onConfirm != null)
                      ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(confirmText),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper method to show glass dialog
Future<bool?> showGlassAlertDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => GlassAlertDialog(
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
    ),
  );
}
