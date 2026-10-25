import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_color_theme.dart';

/// The picker's ready-made colors: Material's deep shades around the color
/// wheel, then the greys, black and white.
const kColorPickerPalette = <Color>[
  Color(0xFFD32F2F), // red
  Color(0xFFC2185B), // pink
  Color(0xFF7B1FA2), // purple
  Color(0xFF512DA8), // deep purple
  Color(0xFF303F9F), // indigo
  Color(0xFF1976D2), // blue
  Color(0xFF0288D1), // light blue
  Color(0xFF0097A7), // cyan
  Color(0xFF00796B), // teal
  Color(0xFF388E3C), // green
  Color(0xFF689F38), // light green
  Color(0xFFFBC02D), // yellow
  Color(0xFFFFA000), // amber
  Color(0xFFF57C00), // orange
  Color(0xFFE64A19), // deep orange
  Color(0xFF5D4037), // brown
  Color(0xFF455A64), // blue grey
  Color(0xFF9E9E9E), // grey
  Color(0xFF000000), // black
  Color(0xFFFFFFFF), // white
];

/// [color] as `RRGGBB`, upper case, without the `#`.
String colorHex(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();

/// The opaque color a hex code names (`RRGGBB`, with or without `#`), or
/// null when it isn't one.
Color? parseColorHex(String text) {
  final hex = text.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 + int.parse(hex, radix: 16));
}

/// [color] made opaque and rounded to 8 bits a channel, as a theme stores
/// it.
Color _opaque(Color color) => Color(0xFF000000 + (color.toARGB32() & 0xFFFFFF));

/// A color picker: ready-made swatches, Hue / Saturation / Brightness
/// sliders, and a hex code field. The colors it gives are always opaque.
///
/// It keeps the hue and saturation it was set to, so dragging Brightness to
/// black and back (or Saturation to grey and back) returns to the same
/// color, which a color alone can't remember.
class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.palette = kColorPickerPalette,
  });

  /// The color picked.
  final Color color;

  /// A new color was picked.
  final ValueChanged<Color> onChanged;

  /// The ready-made swatches.
  final List<Color> palette;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor _hsv;
  late final TextEditingController _hex;
  final _hexFocus = FocusNode();

  /// The color the sliders are at.
  Color get _color => _opaque(_hsv.toColor());

  @override
  void initState() {
    super.initState();
    final color = _opaque(widget.color);
    _hsv = HSVColor.fromColor(color);
    _hex = TextEditingController(text: colorHex(color));
    _hexFocus.addListener(_handleHexFocus);
  }

  @override
  void didUpdateWidget(ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a color set from outside moves the sliders and rewrites the hex
    // code: one this picker gave is already what they show, and rewriting
    // the field would drop a code being typed.
    final color = _opaque(widget.color);
    if (color != _color) {
      _hsv = HSVColor.fromColor(color);
      _showHex(color);
    }
  }

  @override
  void dispose() {
    _hexFocus.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _showHex(Color color) {
    final text = colorHex(color);
    if (_hex.text == text) return;
    _hex.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Leaving the field shows the code in effect, dropping one half typed.
  void _handleHexFocus() {
    if (!_hexFocus.hasFocus) _showHex(_color);
  }

  void _pick(HSVColor hsv) {
    setState(() => _hsv = hsv);
    final color = _color;
    _showHex(color);
    widget.onChanged(color);
  }

  void _pickHex(String text) {
    final color = parseColorHex(text);
    if (color == null || color == _color) return;
    setState(() => _hsv = HSVColor.fromColor(color));
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _color;
    final hsv = _hsv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final swatch in widget.palette)
              _Swatch(
                color: swatch,
                selected: _opaque(swatch) == color,
                onTap: () => _pick(HSVColor.fromColor(_opaque(swatch))),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _GradientSlider(
          label: s.hue,
          value: hsv.hue,
          max: 360,
          valueText: (v) => '${v.round()}°',
          colors: [
            for (var hue = 0; hue <= 360; hue += 60)
              HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
          ],
          thumbColor: color,
          onChanged: (v) => _pick(hsv.withHue(v)),
        ),
        _GradientSlider(
          label: s.saturation,
          value: hsv.saturation,
          max: 1,
          valueText: _percent,
          colors: [
            hsv.withSaturation(0).toColor(),
            hsv.withSaturation(1).toColor(),
          ],
          thumbColor: color,
          onChanged: (v) => _pick(hsv.withSaturation(v)),
        ),
        _GradientSlider(
          label: s.brightness,
          value: hsv.value,
          max: 1,
          valueText: _percent,
          colors: [const Color(0xFF000000), hsv.withValue(1).toColor()],
          thumbColor: color,
          onChanged: (v) => _pick(hsv.withValue(v)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // The color picked, beside its code.
            ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hex,
                focusNode: _hexFocus,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(6),
                  const _UpperCaseFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: s.hexColor,
                  prefixText: '#',
                  isDense: true,
                ),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                onChanged: _pickHex,
                onSubmitted: (_) => _showHex(_color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _percent(double value) => '${(value * 100).round()}%';

/// Upper-cases what is typed, so a code reads as the picker writes it.
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// One of the palette's colors: a circle, checked when it is the color
/// picked.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 36;

  /// The square a tap lands in, larger than the circle.
  static const double _target = 44;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '#${colorHex(color)}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: _target / 2,
        child: SizedBox.square(
          dimension: _target,
          child: Center(
            child: Container(
              width: _size,
              height: _size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                // A ring around the color picked; a hairline keeps white
                // (and a color like the background) visible.
                border: selected
                    ? Border.all(color: cs.onSurface, width: 2)
                    : Border.all(color: cs.outlineVariant),
              ),
              child: selected
                  ? ThinIcon(
                      tabler.Check.new,
                      size: 18,
                      color: recommendedOnColor(color).color,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A slider over a gradient of what it picks, with its name and value above
/// it.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.valueText,
    required this.colors,
    required this.thumbColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final String Function(double value) valueText;

  /// The track's gradient, from 0 to [max].
  final List<Color> colors;

  /// The color the thumb shows: the color picked.
  final Color thumbColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        // The slider below reads both out, with its own adjust actions.
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  valueText(value),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            trackShape: _GradientTrackShape(colors, theme.colorScheme.outline),
            thumbShape: const _RingThumbShape(),
            thumbColor: thumbColor,
            overlayColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            showValueIndicator: ShowValueIndicator.never,
          ),
          // One node: the setting's name, its value and the adjust actions.
          child: MergeSemantics(
            child: Semantics(
              label: label,
              child: Slider(
                value: value.clamp(0, max).toDouble(),
                max: max,
                semanticFormatterCallback: valueText,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The slider's track: [colors] as a gradient from its start to its end
/// (right to left in a right-to-left layout, as the slider runs), with a
/// hairline [border] so a white or background-colored end stays visible.
class _GradientTrackShape extends RoundedRectSliderTrackShape {
  const _GradientTrackShape(this.colors, this.border);

  final List<Color> colors;
  final Color border;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    final rtl = textDirection == TextDirection.rtl;
    context.canvas
      ..drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: rtl ? colors.reversed.toList() : colors,
          ).createShader(rect),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border.withValues(alpha: 0.4),
      );
  }
}

/// The slider's thumb: a white ring around the color picked, outlined so it
/// shows on any part of the gradient.
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape();

  static const double _radius = 12;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas
      ..drawCircle(
        center.translate(0, 1),
        _radius,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      )
      ..drawCircle(center, _radius, Paint()..color = const Color(0xFFFFFFFF))
      ..drawCircle(
        center,
        _radius - 3.5,
        Paint()..color = sliderTheme.thumbColor ?? const Color(0xFF000000),
      )
      ..drawCircle(
        center,
        _radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x40000000),
      );
  }
}
