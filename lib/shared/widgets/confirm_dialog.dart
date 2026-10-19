import 'package:flutter/material.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import 'app_button.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  /// Defaults to the localized "Confirm".
  final String? confirmText;

  /// Defaults to the localized "Cancel".
  final String? cancelText;
  final bool isDestructive;
  final ThinIconBuilder? icon;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.isDestructive = false,
    this.icon,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
    ThinIconBuilder? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return AlertDialog(
      // A long title or message scrolls above the buttons when the dialog
      // can't fit it (a large text size on a short or zoomed-in screen),
      // instead of being cut off.
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      icon: icon != null
          ? ThinIcon(
              icon!,
              size: 40,
              color: isDestructive ? Colors.red : theme.colorScheme.primary,
            )
          : null,
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        // Side by side, or stacked when a label wouldn't fit its half.
        ButtonPair(
          first: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText ?? s.cancel),
          ),
          second: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText ?? s.confirm),
          ),
        ),
      ],
    );
  }
}
