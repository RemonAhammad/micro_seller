import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';

/// What the user chose in [RateAppDialog].
enum RateAppChoice {
  /// Open Google Play's review sheet.
  rate,

  /// Ask again after a cooldown.
  later,

  /// Never ask again.
  decline,
}

/// Gate shown before the store review sheet, so only sellers who say they're
/// enjoying the app land on the rating form.
class RateAppDialog extends StatelessWidget {
  const RateAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final amber = Colors.amber.shade700;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          ThinIcon(tabler.Star.new, color: amber, size: 28, strokeWidth: 1.75),
          const SizedBox(width: 12),
          Expanded(child: Text(s.rateTitle(AppStrings.appName))),
        ],
      ),
      content: Text(s.rateMessage(AppStrings.appName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, RateAppChoice.decline),
          child: Text(s.noThanks),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, RateAppChoice.later),
          child: Text(s.rateLater),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: amber,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, RateAppChoice.rate),
          child: Text(s.rateNow),
        ),
      ],
    );
  }
}
