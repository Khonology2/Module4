import 'package:flutter/material.dart';

/// SnackBar for long-running exports with an explicit dismiss control.
void showDismissibleExportSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 12),
}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Dismiss',
        onPressed: () => messenger.hideCurrentSnackBar(),
      ),
    ),
  );
}
