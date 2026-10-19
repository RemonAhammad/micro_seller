import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_zoom.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../dashboard/presentation/widgets/stat_card.dart';
import '../../providers/display_scale_provider.dart';

// Settings → Display size and Text size (displayScaleProvider, applied by
// AppZoom in app.dart).
//
// Dragging a slider only moves the preview. The size is applied when the
// finger lifts (and on a tap, an arrow key or a screen reader's adjust):
// applying it during the drag would rescale the sheet, and the slider with
// it, under the finger. For the same reason the preview box keeps one height
// while the slider is held. A gesture the slider loses (a press, then a
// vertical move that drags the sheet or scrolls it) or that the system
// cancels applies nothing: see _PercentSlider.

/// Opens Settings → Display size: everything on screen, smaller or larger.
Future<void> showDisplaySizeSheet(BuildContext context) =>
    AppBottomSheet.show<void>(
      context,
      title: AppStrings.of(context).displaySize,
      child: const _DisplaySizeSheet(),
    );

/// Opens Settings → Text size: the phone's font size, or the app's own.
Future<void> showTextSizeSheet(BuildContext context) =>
    AppBottomSheet.show<void>(
      context,
      title: AppStrings.of(context).textSize,
      child: const _TextSizeSheet(),
    );

/// The phone's font size. Below [AppZoom] the MediaQuery carries the Text
/// size setting instead, so this reads the window's.
TextScaler _phoneTextScaler(BuildContext context) =>
    AppZoomScope.maybeOf(context)?.outer.textScaler ??
    MediaQuery.textScalerOf(context);

/// The phone's font size in percent: 125 for 1.25×.
int phoneTextPercent(BuildContext context) =>
    (_phoneTextScaler(context).scale(14) / 14 * 100).round();

class _DisplaySizeSheet extends ConsumerStatefulWidget {
  const _DisplaySizeSheet();

  @override
  ConsumerState<_DisplaySizeSheet> createState() => _DisplaySizeSheetState();
}

class _DisplaySizeSheetState extends ConsumerState<_DisplaySizeSheet> {
  /// The size under the finger while the slider is held; null otherwise.
  int? _draft;

  void _apply(int percent) {
    setState(() => _draft = null);
    ref.read(displayScaleProvider.notifier).setDisplayPercent(percent);
  }

  /// The slider's gesture ended without a release: back to the saved size.
  void _drop() => setState(() => _draft = null);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final saved = ref.watch(displayScaleProvider).displayPercent;
    // The window's width, not the zoomed one: it sets the largest size.
    final windowWidth =
        (AppZoomScope.maybeOf(context)?.outer.size ??
                MediaQuery.sizeOf(context))
            .width;
    final max = maxDisplayPercentFor(windowWidth);
    // The size in effect, worked out as AppZoom does but from the provider,
    // so that it is already the new size in the frame the finger lifts.
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
        _PreviewFrame(
          sample: const _AppSample(),
          // Relative to the zoom the sheet is drawn at, so the sample shows
          // at [percent] of its coded size, and stays put when the app takes
          // that size on release.
          preview: ZoomBox(
            scale: percent / 100 / AppZoomScope.scaleOf(context),
            child: const _AppSample(),
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
  /// The size under the finger while the slider is held; null otherwise.
  int? _draft;

  /// null follows the phone's font size.
  void _apply(int? percent) {
    setState(() => _draft = null);
    ref.read(displayScaleProvider.notifier).setTextPercent(percent);
  }

  /// The slider's gesture ended without a release: back to the saved size.
  void _drop() => setState(() => _draft = null);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final saved = ref.watch(displayScaleProvider).textPercent;
    final following = saved == null;
    final phone = phoneTextPercent(context);
    // What the preview shows: the phone's size while following it.
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
          // A custom size starts at the coded size.
          onChanged: (follow) => _apply(follow ? null : 100),
        ),
        const SizedBox(height: 8),
        _PreviewHeader(percent: percent, following: following),
        const SizedBox(height: 8),
        _PreviewFrame(
          sample: const _TextSample(),
          preview: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: const _TextSample(),
          ),
        ),
        const SizedBox(height: 8),
        // Shows the phone's size, disabled, while following it. Screen
        // readers skip it then: its steps can't hold the phone's size (117%
        // reads as 115%, 150% as 130%), which the switch and the header
        // already give.
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

/// The muted line under a sheet's title.
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

/// "PREVIEW" and, large, the size the preview shows. One line at any value
/// (the label never wraps, and the digits don't change the line's height),
/// so a new value while dragging can't move what is below.
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.percent, this.following = false});

  final int percent;

  /// The phone's size, which the app follows: drawn muted.
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
            color: following ? muted : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// [text] in capitals, as the app's language writes them. Dart's toUpperCase
/// maps every language alike, but Turkish (and Azerbaijani) capitalise i as
/// İ: ÖNİZLEME, not ÖNIZLEME. Their dotless ı already becomes I.
String _upperCase(BuildContext context, String text) =>
    switch (Localizations.localeOf(context).languageCode) {
      'tr' || 'az' => text.replaceAll('i', 'İ').toUpperCase(),
      _ => text.toUpperCase(),
    };

/// The preview box.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.sample, required this.preview});

  /// The sample as the app draws it now. Laid out but never shown, it sets
  /// the box's height, which therefore can't change while the slider is
  /// held: the slider below stays under the finger.
  final Widget sample;

  /// The sample at the size being picked, drawn from the top and clipped to
  /// the box: a larger size runs off the bottom, a smaller one leaves room.
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);
    // A picture of the app, not controls: no taps, no keyboard focus (the
    // sample's button would take a Tab), nothing for a screen reader.
    return ExcludeFocus(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: radius,
            ),
            // In front, so a sample running off the bottom doesn't cover it.
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Stack(
              // The sample gets the box's own width, as the preview does.
              fit: StackFit.passthrough,
              children: [
                Visibility(
                  visible: false,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: sample,
                ),
                Positioned.fill(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: preview,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A percent slider from [kMinDisplayPercent] to [max] in
/// [kDisplayPercentStep] steps, with the range at its ends.
///
/// [onChangeEnd] gets only a size the user commits: where the finger lifts,
/// a tap, an arrow key or a screen reader's adjust. A press held on the track
/// and then moved up or down hands the touch to the sheet's drag or its
/// scroll view, and the system can cancel a touch. Both end the slider's
/// gesture without a release, and call [onCancel] instead.
class _PercentSlider extends StatefulWidget {
  const _PercentSlider({
    required this.semanticLabel,
    required this.value,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.onCancel,
  });

  /// What the slider sets, for screen readers.
  final String semanticLabel;

  final int value;
  final int max;

  /// The value under the finger. null disables the slider.
  final ValueChanged<int>? onChanged;

  /// The value committed.
  final ValueChanged<int>? onChangeEnd;

  /// The gesture ended without a commit.
  final VoidCallback? onCancel;

  @override
  State<_PercentSlider> createState() => _PercentSliderState();
}

class _PercentSliderState extends State<_PercentSlider> {
  /// The pointers down on the slider.
  final _pointers = <int>{};

  void _handleChangeEnd(double value) {
    // The Listener below sees a pointer event before the gesture recognizers
    // do, so the release that ends a gesture has already removed its
    // pointer, and a key or a screen reader's adjust has none. A pointer
    // still here means the slider lost the gesture or it was cancelled.
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
            // A cancel ends the gesture too, but commits nothing: the pointer
            // leaves only once the recognizers have handled it.
            onPointerCancel: (event) =>
                scheduleMicrotask(() => _pointers.remove(event.pointer)),
            // One node: the setting's name, its value and the adjust actions.
            child: MergeSemantics(
              child: Semantics(
                label: widget.semanticLabel,
                child: Slider(
                  value: widget.value.clamp(kMinDisplayPercent, max).toDouble(),
                  min: kMinDisplayPercent.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - kMinDisplayPercent) ~/ kDisplayPercentStep,
                  // No value bubble: the header above shows the value, large.
                  // Under a Display size above 100% the bubble is also pushed
                  // off its thumb: it compares the thumb's place in window dp
                  // with the screen's size in zoomed dp.
                  showValueIndicator: ShowValueIndicator.never,
                  // The default reads the position along the track (40% for
                  // 100% on 80–130%).
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

  /// null disables Reset: the size is already the default.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // Side by side, or stacked when a label's word wouldn't fit its half.
    return ButtonPair(
      first: OutlinedButton(onPressed: onReset, child: Text(s.resetToDefault)),
      second: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(s.done),
      ),
    );
  }
}

/// The tinted icon box Settings puts in front of its rows.
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final ThinIconBuilder icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      // Centered: the box's tight size would stretch the icon to fill it.
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ThinIcon(icon, color: AppColors.primary, size: 20),
    );
  }
}

/// The soft shadow the app's cards cast (OrderCard, the Dashboard's
/// sections).
final _cardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

/// A slice of the app as it is drawn, with sample figures: two Dashboard
/// cards, an order as the Orders list shows it, and a button.
class _AppSample extends StatelessWidget {
  const _AppSample();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final orderTitle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: statCardHeight(MediaQuery.textScalerOf(context)),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: s.monthRevenue,
                    value: CurrencyFormatter.formatCompact(48250),
                    iconBuilder: AppIcons.revenue,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: s.pendingOrders,
                    value: '12',
                    iconBuilder: AppIcons.pending,
                    color: AppColors.statusPending,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      // An order number is data: the app never translates it.
                      child: Text(
                        'ORD-042',
                        style: orderTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      s.today,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // All the room the amount leaves, so the badges only
                    // shorten when it is really tight.
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: _Badge(s.pending, AppColors.statusPending),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _Badge(s.paid, AppColors.paymentPaid),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(1250),
                      style: orderTitle?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: () {},
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: const ThinIcon(tabler.Plus.new, size: 18),
              label: Text(s.addOrder),
            ),
          ),
        ],
      ),
    );
  }
}

/// An order's status pill, as the Orders list draws it.
class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Title, body and caption text as the app sets them (the Due Book's
/// summary), with sample figures.
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
          boxShadow: _cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The amount beside the label, or under it once a word of the
            // label wouldn't fit beside it (a large text size in a narrow
            // layout), where the word would be broken across lines.
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

/// Whether [label]'s longest word and all of [value], 8 dp apart, fit in
/// [width], as a Text in [context] draws them (at the current text size and
/// bold-text setting).
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
