import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/scale_barcode.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';

/// Settings → Scale labels: whether scans of a shop scale's label (an EAN-13
/// starting with 2) fill in the weight, what its number means and how long
/// its item code is. Each change is saved at once.
Future<void> showScaleLabelSheet(BuildContext context) {
  return AppBottomSheet.show<void>(
    context,
    title: AppStrings.of(context).scaleLabels,
    child: const _ScaleLabelSettingsView(),
  );
}

class _ScaleLabelSettingsView extends StatefulWidget {
  const _ScaleLabelSettingsView();

  @override
  State<_ScaleLabelSettingsView> createState() => _ScaleLabelSettingsViewState();
}

class _ScaleLabelSettingsViewState extends State<_ScaleLabelSettingsView> {
  ScaleLabelSettings? _settings;

  @override
  void initState() {
    super.initState();
    ScaleLabelSettings.load().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  void _update(ScaleLabelSettings next) {
    setState(() => _settings = next);
    next.save().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final settings = _settings;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.scaleLabelsHelp, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.scaleLabelsEnable),
          value: settings.enabled,
          onChanged: (v) => _update(settings.copyWith(enabled: v)),
        ),
        if (settings.enabled) ...[
          label(s.scaleLabelCarries),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (value, text) in [
                (ScaleLabelValue.weight, s.scaleWeight),
                (ScaleLabelValue.price, s.scalePrice),
                (ScaleLabelValue.priceWhole, s.scalePriceWhole),
              ])
                ChoiceChip(
                  label: Text(text),
                  selected: settings.value == value,
                  onSelected: (_) => _update(settings.copyWith(value: value)),
                ),
            ],
          ),
          label(s.scaleItemCodeDigits),
          Wrap(
            spacing: 8,
            children: [
              for (final digits in ScaleLabelSettings.itemCodeDigitChoices)
                ChoiceChip(
                  label: Text('$digits'),
                  selected: settings.itemCodeDigits == digits,
                  onSelected: (_) => _update(settings.copyWith(itemCodeDigits: digits)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Example(settings: settings),
        ],
      ],
    );
  }
}

/// The label layout for the chosen settings, with a worked example, so the
/// seller can hold it against a printed label: "2 1 | 12345 | 01250 | 7".
class _Example extends StatelessWidget {
  const _Example({required this.settings});

  final ScaleLabelSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final valueDigits = 10 - settings.itemCodeDigits;
    final code = '12345678'.substring(0, settings.itemCodeDigits);
    final value = '1250'.padLeft(valueDigits, '0');
    final meaning = switch (settings.value) {
      ScaleLabelValue.weight => '1.250 kg',
      ScaleLabelValue.price => '12.50',
      ScaleLabelValue.priceWhole => '1250',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '2X  $code  $value  C',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.scaleExample(code, meaning),
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
