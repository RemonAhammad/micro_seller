import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : const Color(0xFF323232),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const ThinIcon(tabler.CircleCheck.new, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const ThinIcon(tabler.AlertCircle.new, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(this).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Snackbar with an UNDO action, for deletes that went to the trash.
  ///
  /// The 10s window is a convenience, not the safety net — the item stays
  /// recoverable in Settings → Recycle Bin for 30 days either way. That
  /// matters on MIUI/Xiaomi, where SnackBar timers are known to stall (the
  /// same quirk that made `pdf_saved_sheet.dart` own its own Timer). Here a
  /// stalled timer is harmless: the bar lingers, and the record is safe
  /// regardless of whether the action is ever tapped.
  void showUndoSnackBar(
    String message, {
    required VoidCallback onUndo,
    String actionLabel = 'UNDO',
  }) {
    final messenger = ScaffoldMessenger.of(this);
    // Drop any in-flight bar so rapid deletes don't queue up behind each
    // other — the last one is the one the user is reacting to.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF323232),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: actionLabel,
          textColor: const Color(0xFF4DB6AC),
          onPressed: onUndo,
        ),
      ),
    );
  }

  Future<bool?> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: this,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
