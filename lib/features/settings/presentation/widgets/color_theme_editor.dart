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

const kMaxColorThemeNameLength = 30;

class ColorThemeEditor extends ConsumerStatefulWidget {

  const ColorThemeEditor.create({
    super.key,
    required this.start,
    this.name = '',
  }) : editing = false;

  ColorThemeEditor.edit({super.key, required AppColorTheme theme})
    : start = theme,
      name = theme.name ?? '',
      editing = true;

  final AppColorTheme start;

  final String name;

  final bool editing;

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

  late OnColor _on = widget.editing
      ? widget.start.onPrimary
      : recommendedOnColor(widget.start.seedColor);

  late bool _onChosen =
      widget.editing &&
      widget.start.onPrimary != recommendedOnColor(widget.start.seedColor);

  late bool _useAccent = widget.start.accent != null;

  late Color? _accent = widget.start.accentColor;

  Brightness? _previewMode;

  bool _submitted = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _keepsStartDark =>
      _main.toARGB32() == widget.start.seed && _on == widget.start.onPrimary;

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

String themeStyleLabel(BuildContext context, ThemeStyle style) {
  final s = AppStrings.of(context);
  return switch (style) {
    ThemeStyle.vivid => s.themeStyleVivid,
    ThemeStyle.soft => s.themeStyleSoft,
    ThemeStyle.muted => s.themeStyleMuted,
  };
}

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

String _upperCase(BuildContext context, String text) =>
    switch (Localizations.localeOf(context).languageCode) {
      'tr' || 'az' => text.replaceAll('i', 'İ').toUpperCase(),
      _ => text.toUpperCase(),
    };

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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _switchRoom = 60 + _gap;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final text = Text(label, style: style);
    final toggle = Switch(value: value, onChanged: onChanged);

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

ThinIconBuilder readabilityIcon(Readability readability) =>
    switch (readability) {
      Readability.easy => tabler.CircleCheck.new,
      Readability.largeOnly => tabler.AlertCircle.new,
      Readability.hard => tabler.AlertTriangle.new,
    };

String readabilityLabel(BuildContext context, Readability readability) {
  final s = AppStrings.of(context);
  return switch (readability) {
    Readability.easy => s.readabilityEasy,
    Readability.largeOnly => s.readabilityLargeOnly,
    Readability.hard => s.readabilityHard,
  };
}

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
