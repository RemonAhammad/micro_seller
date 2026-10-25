import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_color_theme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_preview_sample.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/color_picker.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../dashboard/presentation/widgets/stat_card.dart';
import '../../providers/settings_provider.dart';

// Settings → Color theme → Create theme, Customize (a preset) or Edit (a
// saved theme). Everything here is a draft until Save: the app keeps its
// theme while the seller tries colors, and the preview shows the draft in
// light or dark mode. The seller's colors are used exactly as picked: a
// main color that is hard to see against a background, or a text color
// that is hard to read on it, gets a hint, never a silent change.

/// The longest name a color theme can have.
const kMaxColorThemeNameLength = 30;

/// The editor for a custom color theme: its name, main color, text color
/// (White or Black), style and optional accent.
class ColorThemeEditor extends ConsumerStatefulWidget {
  /// A new theme, starting from [start]'s colors (a preset being customized,
  /// or the active theme's main color) and [name]. Like every new theme, it
  /// starts on the text color that reads better on the main color. Teal's
  /// copy starts on Black (4.86:1, white is 4.32:1); picking White makes it
  /// Teal again, its dark colors included.
  const ColorThemeEditor.create({
    super.key,
    required this.start,
    this.name = '',
  }) : editing = false;

  /// The saved custom theme [theme].
  ColorThemeEditor.edit({super.key, required AppColorTheme theme})
    : start = theme,
      name = theme.name ?? '',
      editing = true;

  /// The colors the draft starts from: the theme being edited, or the
  /// starting point of a new one.
  final AppColorTheme start;

  /// The name the draft starts with.
  final String name;

  /// Whether this edits the saved theme [start] (Save replaces it, and it
  /// can be deleted) rather than creating a new one.
  final bool editing;

  /// Opens [editor] as a page over the current screen.
  static Future<void> open(BuildContext context, ColorThemeEditor editor) =>
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => editor));

  @override
  ConsumerState<ColorThemeEditor> createState() => _ColorThemeEditorState();
}

class _ColorThemeEditorState extends ConsumerState<ColorThemeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey();
  late final _name = TextEditingController(text: widget.name);

  late Color _main = widget.start.seedColor;
  late ThemeStyle _style = widget.start.style;

  /// The text color: a saved theme's own, or for a new theme the one that
  /// reads better on its main color (the one marked Recommended).
  late OnColor _on = widget.editing
      ? widget.start.onPrimary
      : recommendedOnColor(widget.start.seedColor);

  /// Whether the seller chose the text color, rather than taking the one
  /// that reads better. A chosen one stays when the main color changes; the
  /// other follows it. A saved theme's text color counts as chosen when it
  /// isn't the one that reads better on its main color.
  late bool _onChosen =
      widget.editing &&
      widget.start.onPrimary != recommendedOnColor(widget.start.seedColor);

  late bool _useAccent = widget.start.accent != null;

  /// The accent, kept while it is switched off so switching it back on
  /// returns to it.
  late Color? _accent = widget.start.accentColor;

  /// The mode the preview shows; null follows the app's.
  Brightness? _previewMode;

  /// Save was pressed: the name is checked as it is typed from then on.
  bool _submitted = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Whether the draft keeps [ColorThemeEditor.start]'s dark colors (a
  /// preset's curated dark pair, or a saved copy's): only while its main
  /// color and text color are still the start's. A preset customized and
  /// saved unchanged then looks like the preset in dark mode too (Mono stays
  /// white there, Amber #FFC107). Once the seller picks another main color
  /// or text color, their pair is used exactly in both modes, as in every
  /// custom theme.
  bool get _keepsStartDark =>
      _main.toARGB32() == widget.start.seed && _on == widget.start.onPrimary;

  /// The theme as drafted. Its id is the saved theme's, or a placeholder.
  AppColorTheme get _draft => AppColorTheme(
    id: widget.editing ? widget.start.id : '${kCustomColorThemeIdPrefix}draft',
    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
    seed: _main.toARGB32(),
    accent: _useAccent ? _accent?.toARGB32() : null,
    style: _style,
    onPrimary: _on,
    darkPrimary: _keepsStartDark ? widget.start.darkPrimary : null,
    darkOnPrimary: _keepsStartDark ? widget.start.darkOnPrimary : null,
  );

  void _setMain(Color color) => setState(() {
    _main = color;
    if (!_onChosen) _on = recommendedOnColor(color);
  });

  void _setOn(OnColor on) => setState(() {
    _on = on;
    _onChosen = true;
  });

  void _setUseAccent(bool use) => setState(() {
    // The first time, the accent starts as the one Material derives from
    // the main color: switching it on changes nothing until a color is
    // picked.
    _accent ??= AppTheme.build(
      Brightness.light,
      _draft.copyWith(accent: null),
    ).colorScheme.secondary;
    _useAccent = use;
  });

  Future<void> _save() async {
    final s = AppStrings.of(context);
    setState(() => _submitted = true);
    final name = _name.text.trim();
    // The name field is always built (see build), so the form checks it
    // wherever the list is scrolled. The name is checked here as well: a
    // nameless theme must never be saved.
    if (!(_formKey.currentState?.validate() ?? false) || name.isEmpty) {
      final field = _nameKey.currentContext;
      if (field != null) {
        await Scrollable.ensureVisible(
          field,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
      }
      return;
    }
    final draft = _draft;
    final theme = widget.editing
        ? widget.start.copyWith(
            name: name,
            seed: draft.seed,
            accent: draft.accent,
            style: draft.style,
            onPrimary: draft.onPrimary,
            darkPrimary: draft.darkPrimary,
            darkOnPrimary: draft.darkOnPrimary,
          )
        : AppColorTheme.custom(
            name: name,
            seed: draft.seed,
            accent: draft.accent,
            style: draft.style,
            onPrimary: draft.onPrimary,
          ).copyWith(
            darkPrimary: draft.darkPrimary,
            darkOnPrimary: draft.darkOnPrimary,
          );
    final settings = ref.read(settingsProvider.notifier);
    setState(() => _saving = true);
    try {
      await settings.saveCustomColorTheme(theme);
    } on StateError {
      // Another screen saved the twelfth theme meanwhile.
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar(
          s.themeLimitReached(kMaxCustomColorThemes),
          isError: true,
        );
      }
      return;
    }
    await settings.updateColorTheme(theme.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final s = AppStrings.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: s.delete,
      message: s.deleteThemeConfirm(widget.start.name ?? widget.name),
      confirmText: s.delete,
      isDestructive: true,
      icon: tabler.Trash.new,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    await ref
        .read(settingsProvider.notifier)
        .deleteCustomColorTheme(widget.start.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final mode = _previewMode ?? Theme.of(context).brightness;
    final recommended = recommendedOnColor(_main);
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? s.editTheme : s.createTheme),
        actions: [
          if (widget.editing)
            IconButton(
              tooltip: s.delete,
              icon: const ThinIcon(tabler.Trash.new, size: 22),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        // Slivers, not one ListView: a list builds only the rows near the
        // screen, and the form validates only fields that are built. Scrolled
        // far enough away (the accent's picker open, the list scrolled down
        // to Save), the name field was skipped and a nameless theme saved.
        // The name field is a box sliver, built wherever the list is
        // scrolled; the rows before and after it stay lazy.
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              sliver: SliverList.list(
                children: [
                  ColorThemeSectionHeader(s.preview),
                  _PreviewModeChips(
                    value: mode,
                    onChanged: (b) => setState(() => _previewMode = b),
                  ),
                  const SizedBox(height: 8),
                  // The draft as the app would draw it, in the mode picked.
                  // Built afresh for the other mode: the light and dark themes
                  // style buttons differently (the light one sets their text
                  // style, the dark one leaves Material's), and a button
                  // can't animate from one to the other.
                  Theme(
                    key: ValueKey(mode),
                    data: AppTheme.build(mode, draft),
                    child: const Material(
                      type: MaterialType.transparency,
                      child: AppPreviewFrame(
                        preview: AppPreviewSample(header: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: AppTextField(
                  key: _nameKey,
                  label: s.themeName,
                  controller: _name,
                  maxLength: kMaxColorThemeNameLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? s.themeNameRequired : null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              sliver: SliverList.list(
                children: [
                  ColorThemeSectionHeader(s.mainColor),
                  ColorThemeCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ColorPicker(color: _main, onChanged: _setMain),
                        // Against each mode's background, the main color
                        // that mode is drawn with: a preset's dark color
                        // while the draft keeps it.
                        for (final b in const [
                          Brightness.light,
                          Brightness.dark,
                        ])
                          if (isHardToSee(draft.primaryFor(b), b))
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _Hint(
                                b == Brightness.light
                                    ? s.hardToSeeOnLight
                                    : s.hardToSeeOnDark,
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ColorThemeSectionHeader(s.textColor),
                  for (final on in OnColor.values) ...[
                    if (on != OnColor.values.first) const SizedBox(height: 8),
                    _TextColorOption(
                      key: ValueKey('textColor-${on.name}'),
                      main: _main,
                      on: on,
                      selected: _on == on,
                      recommended: on == recommended,
                      onTap: () => _setOn(on),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ColorThemeSectionHeader(s.themeStyle),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final style in ThemeStyle.values)
                        ChoiceChip(
                          label: Text(themeStyleLabel(context, style)),
                          selected: _style == style,
                          onSelected: (_) => setState(() => _style = style),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ColorThemeSectionHeader(s.accentColor),
                  ColorThemeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SwitchRow(
                          label: s.useAccentColor,
                          value: _useAccent,
                          onChanged: _setUseAccent,
                        ),
                        if (_useAccent && _accent != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: ColorPicker(
                              color: _accent!,
                              onChanged: (c) => setState(() => _accent = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(s.save),
          ),
        ),
      ),
    );
  }
}

/// [style]'s name.
String themeStyleLabel(BuildContext context, ThemeStyle style) {
  final s = AppStrings.of(context);
  return switch (style) {
    ThemeStyle.vivid => s.themeStyleVivid,
    ThemeStyle.soft => s.themeStyleSoft,
    ThemeStyle.muted => s.themeStyleMuted,
  };
}

/// A section's name above it, small and in capitals, as Settings sets them.
class ColorThemeSectionHeader extends StatelessWidget {
  const ColorThemeSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
      child: Text(
        _upperCase(context, text),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// [text] in capitals, as the app's language writes them: Turkish (and
/// Azerbaijani) capitalise i as İ, which Dart's toUpperCase doesn't.
String _upperCase(BuildContext context, String text) =>
    switch (Localizations.localeOf(context).languageCode) {
      'tr' || 'az' => text.replaceAll('i', 'İ').toUpperCase(),
      _ => text.toUpperCase(),
    };

/// A Settings card: the surface color, rounded, with the rows' own
/// transparent Material so a row's ink shows on the card.
class ColorThemeCard extends StatelessWidget {
  const ColorThemeCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// A switch and its label: side by side, or the switch under the label
/// when a word of it wouldn't fit beside the switch (a long translation, a
/// large text size, a narrow layout), where it would break across lines.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// A Material 3 switch's width with its padding, and the gap before it.
  static const double _switchRoom = 60 + _gap;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final text = Text(label, style: style);
    final toggle = Switch(value: value, onChanged: onChanged);
    // One node, as SwitchListTile's: the label, the state and the toggle.
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              var longest = 0.0;
              for (final word in label.split(RegExp(r'\s+'))) {
                longest = math.max(
                  longest,
                  measureTextWidth(context, word, style),
                );
              }
              if (longest + _switchRoom <= constraints.maxWidth) {
                return Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: _gap),
                    toggle,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 4), toggle],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Light / Dark: the mode the preview shows.
class _PreviewModeChips extends StatelessWidget {
  const _PreviewModeChips({required this.value, required this.onChanged});

  final Brightness value;
  final ValueChanged<Brightness> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (mode, icon, label) in [
          (Brightness.light, tabler.Sun.new, s.light),
          (Brightness.dark, tabler.Moon.new, s.dark),
        ])
          ChoiceChip(
            avatar: ThinIcon(icon, size: 18),
            label: Text(label),
            showCheckmark: false,
            selected: value == mode,
            onSelected: (_) => onChanged(mode),
          ),
      ],
    );
  }
}

/// A warning under the main color: an amber triangle and [text].
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = readabilityColor(theme.brightness, Readability.largeOnly);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ThinIcon(tabler.AlertTriangle.new, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

/// The color that tells how well text reads: green, amber or red, deep in
/// light mode and pale in dark mode so it reads on the background.
Color readabilityColor(Brightness brightness, Readability readability) {
  final light = brightness == Brightness.light;
  return switch (readability) {
    Readability.easy =>
      light ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
    Readability.largeOnly =>
      light ? const Color(0xFFB45309) : const Color(0xFFFFB74D),
    Readability.hard =>
      light ? const Color(0xFFC62828) : const Color(0xFFE57373),
  };
}

/// [readability]'s icon.
ThinIconBuilder readabilityIcon(Readability readability) =>
    switch (readability) {
      Readability.easy => tabler.CircleCheck.new,
      Readability.largeOnly => tabler.AlertCircle.new,
      Readability.hard => tabler.AlertTriangle.new,
    };

/// [readability]'s name.
String readabilityLabel(BuildContext context, Readability readability) {
  final s = AppStrings.of(context);
  return switch (readability) {
    Readability.easy => s.readabilityEasy,
    Readability.largeOnly => s.readabilityLargeOnly,
    Readability.hard => s.readabilityHard,
  };
}

/// One of the two text colors: a sample of it on the main color, its name,
/// how well it reads there, and whether it is the one recommended.
class _TextColorOption extends StatelessWidget {
  const _TextColorOption({
    super.key,
    required this.main,
    required this.on,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final Color main;
  final OnColor on;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final level = readability(main, on);
    final levelColor = readabilityColor(theme.brightness, level);
    final radius = BorderRadius.circular(14);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
        color: cs.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // The text color on the main color.
                ExcludeSemantics(
                  child: Container(
                    width: 56,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: main,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ThinIcon(
                      tabler.LetterCase.new,
                      size: 28,
                      strokeWidth: 2,
                      color: on.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The radio mark beside the name, so the line under
                      // them has the option's whole width.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              on == OnColor.white
                                  ? s.textColorWhite
                                  : s.textColorBlack,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ThinIcon(
                            selected
                                ? tabler.CircleCheck.new
                                : tabler.Circle.new,
                            size: 22,
                            color: selected ? cs.primary : cs.outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ThinIcon(
                                readabilityIcon(level),
                                size: 16,
                                color: levelColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  readabilityLabel(context, level),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: levelColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (recommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.recommended,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
