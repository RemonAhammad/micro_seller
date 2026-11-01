import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_preview_sample.dart';
import '../../../../shared/widgets/app_zoom.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../providers/display_scale_provider.dart';

Future<void> showDisplaySizeSheet(BuildContext context) =>
    AppBottomSheet.show<void>(
      context,
      title: AppStrings.of(context).displaySize,
      child: const _DisplaySizeSheet(),
    );

Future<void> showTextSizeSheet(BuildContext context) =>
    AppBottomSheet.show<void>(
      context,
      title: AppStrings.of(context).textSize,
      child: const _TextSizeSheet(),
    );

TextScaler _phoneTextScaler(BuildContext context) =>
    AppZoomScope.maybeOf(context)?.outer.textScaler ??
    MediaQuery.textScalerOf(context);

int phoneTextPercent(BuildContext context) =>
    (_phoneTextScaler(context).scale(14) / 14 * 100).round();

class _DisplaySizeSheet extends ConsumerStatefulWidget {
  const _DisplaySizeSheet();

  @override
  ConsumerState<_DisplaySizeSheet> createState() => _DisplaySizeSheetState();
}

class _DisplaySizeSheetState extends ConsumerState<_DisplaySizeSheet> {

  int? _draft;

  void _apply(int percent) {
    setState(() => _draft = null);
    ref.read(displayScaleProvider.notifier).setDisplayPercent(percent);
  }

  void _drop() => setState(() => _draft = null);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final saved = ref.watch(displayScaleProvider).displayPercent;

    final windowWidth =
        (AppZoomScope.maybeOf(context)?.outer.size ??
                MediaQuery.sizeOf(context))
            .width;
    final max = maxDisplayPercentFor(windowWidth);

    final applied = effectiveDisplayPercent(saved, windowWidth);
    final percent = (_draft ?? applied).clamp(kMinDisplayPercent, max);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Description(s.displaySizeDesc),
        const SizedBox(height: 12),
        _PreviewHeader(percent: percent),
        const SizedBox(height: 8),
        AppPreviewFrame(
          sample: const AppPreviewSample(),

          preview: ZoomBox(
            scale: percent / 100 / AppZoomScope.scaleOf(context),
            child: const AppPreviewSample(),
          ),
        ),
        const SizedBox(height: 8),
        _PercentSlider(
          semanticLabel: s.displaySize,
          value: percent,
          max: max,
          onChanged: (v) => setState(() => _draft = v),
          onChangeEnd: _apply,
          onCancel: _drop,
        ),
        const SizedBox(height: 12),
        _SheetButtons(
          onReset: percent == 100 && saved == 100 ? null : () => _apply(100),
        ),
      ],
    );
  }
}

class _TextSizeSheet extends ConsumerStatefulWidget {
  const _TextSizeSheet();

  @override
  ConsumerState<_TextSizeSheet> createState() => _TextSizeSheetState();
}

class _TextSizeSheetState extends ConsumerState<_TextSizeSheet> {

  int? _draft;

  void _apply(int? percent) {
    setState(() => _draft = null);
    ref.read(displayScaleProvider.notifier).setTextPercent(percent);
  }

  void _drop() => setState(() => _draft = null);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final saved = ref.watch(displayScaleProvider).textPercent;
    final following = saved == null;
    final phone = phoneTextPercent(context);

    final percent = saved == null ? phone : _draft ?? saved;
    final textScaler = saved == null
        ? _phoneTextScaler(context)
        : TextScaler.linear(percent / 100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Description(s.textSizeDesc),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const _IconBox(tabler.DeviceMobile.new),
          title: Text(s.followPhoneTextSize),
          subtitle: Text(
            s.phoneTextSize('$phone%'),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          value: following,

          onChanged: (follow) => _apply(follow ? null : 100),
        ),
        const SizedBox(height: 8),
        _PreviewHeader(percent: percent, following: following),
        const SizedBox(height: 8),
        AppPreviewFrame(
          sample: const _TextSample(),
          preview: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: const _TextSample(),
          ),
        ),
        const SizedBox(height: 8),

        ExcludeSemantics(
          excluding: following,
          child: _PercentSlider(
            semanticLabel: s.textSize,
            value: percent,
            max: kMaxDisplayPercent,
            onChanged: following ? null : (v) => setState(() => _draft = v),
            onChangeEnd: following ? null : _apply,
            onCancel: following ? null : _drop,
          ),
        ),
        const SizedBox(height: 12),
        _SheetButtons(onReset: following ? null : () => _apply(null)),
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.percent, this.following = false});

  final int percent;

  final bool following;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            _upperCase(context, s.preview),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$percent%',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: following ? muted : context.brand.primary,
          ),
        ),
      ],
    );
  }
}

String _upperCase(BuildContext context, String text) =>
    switch (Localizations.localeOf(context).languageCode) {
      'tr' || 'az' => text.replaceAll('i', 'İ').toUpperCase(),
      _ => text.toUpperCase(),
    };

class _PercentSlider extends StatefulWidget {
  const _PercentSlider({
    required this.semanticLabel,
    required this.value,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.onCancel,
  });

  final String semanticLabel;

  final int value;
  final int max;

  final ValueChanged<int>? onChanged;

  final ValueChanged<int>? onChangeEnd;

  final VoidCallback? onCancel;

  @override
  State<_PercentSlider> createState() => _PercentSliderState();
}

class _PercentSliderState extends State<_PercentSlider> {

  final _pointers = <int>{};

  void _handleChangeEnd(double value) {

    if (_pointers.isEmpty) {
      widget.onChangeEnd?.call(value.round());
    } else {
      widget.onCancel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ends = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );
    final max = widget.max;
    final onChanged = widget.onChanged;
    return Row(
      children: [
        Text('$kMinDisplayPercent%', style: ends),
        Expanded(
          child: Listener(
            onPointerDown: (event) => _pointers.add(event.pointer),
            onPointerUp: (event) => _pointers.remove(event.pointer),

            onPointerCancel: (event) =>
                scheduleMicrotask(() => _pointers.remove(event.pointer)),

            child: MergeSemantics(
              child: Semantics(
                label: widget.semanticLabel,
                child: Slider(
                  value: widget.value.clamp(kMinDisplayPercent, max).toDouble(),
                  min: kMinDisplayPercent.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - kMinDisplayPercent) ~/ kDisplayPercentStep,

                  showValueIndicator: ShowValueIndicator.never,

                  semanticFormatterCallback: (v) => '${v.round()}%',
                  onChanged: onChanged == null
                      ? null
                      : (v) => onChanged(v.round()),
                  onChangeEnd: _handleChangeEnd,
                ),
              ),
            ),
          ),
        ),
        Text('$max%', style: ends),
      ],
    );
  }
}

class _SheetButtons extends StatelessWidget {
  const _SheetButtons({required this.onReset});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return ButtonPair(
      first: OutlinedButton(onPressed: onReset, child: Text(s.resetToDefault)),
      second: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(s.done),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final ThinIconBuilder icon;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      width: 40,
      height: 40,

      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ThinIcon(icon, color: brand.primary, size: 20),
    );
  }
}

class _TextSample extends StatelessWidget {
  const _TextSample();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final amount = CurrencyFormatter.format(12400);
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.paymentUnpaid,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: previewCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            LayoutBuilder(
              builder: (context, constraints) {
                final label = Text(s.totalReceivable, style: labelStyle);
                final value = Text(amount, style: amountStyle);
                final beside = _wordsFitBeside(
                  context,
                  constraints.maxWidth,
                  (s.totalReceivable, labelStyle),
                  (amount, amountStyle),
                );
                return beside
                    ? Row(
                        children: [
                          Expanded(child: label),
                          const SizedBox(width: 8),
                          value,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [label, value],
                      );
              },
            ),
            const SizedBox(height: 4),
            Text(s.customersOwing(3), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              s.overdue30Days,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _wordsFitBeside(
  BuildContext context,
  double width,
  (String, TextStyle?) label,
  (String, TextStyle?) value,
) {
  final base = DefaultTextStyle.of(context).style;
  final bold = MediaQuery.boldTextOf(context);
  double measure((String, TextStyle?) text, {required bool longestWord}) {
    var effective = base.merge(text.$2);
    if (bold) {
      effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final painter = TextPainter(
      text: TextSpan(text: text.$1, style: effective),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final result = longestWord
        ? painter.minIntrinsicWidth
        : painter.maxIntrinsicWidth;
    painter.dispose();
    return result;
  }

  return measure(label, longestWord: true) +
          8 +
          measure(value, longestWord: false) <=
      width;
}
