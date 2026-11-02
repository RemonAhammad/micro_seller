import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';

void confirmShared(BuildContext context, ShareResult result) {
  if (result.status == ShareResultStatus.success && context.mounted) {
    context.showSuccessSnackBar(AppStrings.of(context).sharedDone);
  }
}

void confirmPrinted(BuildContext context, bool printed) {
  if (printed && context.mounted) {
    context.showSuccessSnackBar(AppStrings.of(context).sentToPrinter);
  }
}

void showOutcome(ScaffoldMessengerState messenger, String message, {bool failed = false}) {
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: failed ? Colors.red : Colors.green,
  ));
}
