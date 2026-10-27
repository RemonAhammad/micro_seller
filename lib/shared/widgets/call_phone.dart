import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/utils/number_input.dart';
import 'app_button.dart';
import 'bottom_sheet_handle.dart';

/// The `tel:` link that calls [phone]: its digits (any script's, as 0-9),
/// `*`, `#`, and a `+` before the first digit; spaces, dashes and
/// parentheses dropped. Null when [phone] has no digit.
@visibleForTesting
Uri? telUri(String phone) {
  final number = StringBuffer();
  var hasDigit = false;
  for (final unit in NumberInput.toAsciiDigits(phone).codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      hasDigit = true;
      number.writeCharCode(unit);
    } else if (unit == 0x2A || unit == 0x23) {
      number.writeCharCode(unit); // * and #
    } else if (unit == 0x2B && number.isEmpty) {
      number.writeCharCode(unit); // +
    }
  }
  if (!hasDigit) return null;
  return Uri(scheme: 'tel', path: number.toString());
}

/// Calls [phone] in the phone app. A device that can't call (an iPad, an
/// iPod touch, a tablet without a dialer) says so in a sheet that shows the
/// number with Copy number: iOS answers false there, Android throws (no app
/// handles `tel:`).
Future<void> callPhone(BuildContext context, String phone) async {
  final uri = telUri(phone);
  var called = false;
  if (uri != null) {
    try {
      called = await launchUrl(uri);
    } catch (_) {
      called = false;
    }
  }
  if (called || !context.mounted) return;
  await AppBottomSheet.show<void>(
    context,
    title: AppStrings.of(context).callNotAvailable,
    child: _CallNotAvailable(phone: phone),
  );
}

class _CallNotAvailable extends StatelessWidget {
  const _CallNotAvailable({required this.phone});

  final String phone;

  Future<void> _copy(BuildContext context) async {
    final s = AppStrings.of(context);
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    Navigator.pop(context);
    context.showSuccessSnackBar(s.numberCopied);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selectable, left to right in every language (an Arabic layout
        // would put the + after the digits), and on one line that shrinks
        // rather than breaking the number.
        SelectionArea(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              phone,
              maxLines: 1,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: s.copyNumber,
          icon: tabler.Copy.new,
          isFullWidth: true,
          onPressed: () => _copy(context),
        ),
      ],
    );
  }
}
