import 'package:flutter/material.dart';

/// Short, user-facing messages and consistent snackbars.
class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(BuildContext context, String message, {required bool isError}) {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? cs.error : cs.inverseSurface,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: isError ? cs.onError : cs.onInverseSurface,
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }
}
