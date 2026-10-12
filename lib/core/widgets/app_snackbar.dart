import 'package:flutter/material.dart';

/// Exibe uma SnackBar imediatamente, descartando mensagens antigas pendentes.
void showAppSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  messenger.clearSnackBars();
  messenger.showSnackBar(snackBar);
}
