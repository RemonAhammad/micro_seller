import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_color_theme.dart';
import '../../../core/theme/dynamic_color_support.dart';
import '../../../shared/widgets/app_preview_sample.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../dashboard/presentation/widgets/stat_card.dart';
import '../providers/settings_provider.dart';
import 'widgets/color_theme_editor.dart';

// Settings → Color theme (/settings/color-theme): a preview of the app in
// the active theme, Phone colors (Android 12+), the twelve presets and the
// seller's own themes. Tapping a theme applies it at once. A preset can be
// customized into a new theme of the seller's (the button under the
// preview, or a long press on it); a saved theme can be edited or deleted.

/// Settings → Color theme.
class ColorThemeScreen extends ConsumerWidget {
  const ColorThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    // Plain values: only a change of theme or of the saved ones rebuilds.
    ref.watch(settingsProvider.select((m) => m['colorThemeId']));
    ref.watch(settingsProvider.select((m) => m['customColorThemes']));
    final settings = ref.read(settingsProvider.notifier);
    final active = settings.activeColorTheme;
    final customs = settings.customColorThemes;
    final phoneState = ref.watch(dynamicColorAvailableProvider);
    final phone = phoneState.value ?? false;
    // Saved (a backup from another phone), but this phone has none: the app
    // is drawn in Teal. Only once the phone has answered, so a phone that
    // does have them never flashes the note.
    final phoneMissing = active.isPhone && phoneState.hasValue && !phone;
    final full = customs.length >= kMaxCustomColorThemes;

    void apply(AppColorTheme theme) => settings.updateColorTheme(theme.id);

    void customize(AppColorTheme preset) {
      if (full) {
        context.showSnackBar(s.themeLimitReached(kMaxCustomColorThemes));
        return;
      }
      ColorThemeEditor.open(
        context,
        ColorThemeEditor.create(
          start: preset,
          name: s.presetThemeName(preset.id),
        ),
      );
    }

    void edit(AppColorTheme theme) =>
        ColorThemeEditor.open(context, ColorThemeEditor.edit(theme: theme));

    Future<void> delete(AppColorTheme theme) async {
      final ok = await ConfirmDialog.show(
        context,
        title: s.delete,
        message: s.deleteThemeConfirm(theme.name ?? ''),
        confirmText: s.delete,
        isDestructive: true,
        icon: tabler.Trash.new,
      );
      if (ok != true || !context.mounted) return;
      await settings.deleteCustomColorTheme(theme.id);
    }

    // A new theme starts from the active theme's main color, with the text
    // color that reads better on it.
    void create() => ColorThemeEditor.open(
      context,
      ColorThemeEditor.create(
        start: AppColorTheme(
          id: '${kCustomColorThemeIdPrefix}draft',
          seed: active.seed,
          onPrimary: recommendedOnColor(active.seedColor),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.colorTheme)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Description(s.colorThemeDesc),
          const SizedBox(height: 16),
          ColorThemeSectionHeader(s.preview),
          // The app in the active theme: the screen's own theme is it.
          const AppPreviewFrame(preview: AppPreviewSample(header: true)),
          const SizedBox(height: 12),
          _ActiveTheme(
            theme: active,
            onCustomize: active.isPreset && !full
                ? () => customize(active)
                : null,
            onEdit: active.isCustom ? () => edit(active) : null,
          ),
          const SizedBox(height: 20),
          // Shown while active too, should the phone not offer it (a backup
          // restored on an iPhone or an older Android): the app then looks
          // like Teal, and the tile says why.
          if (phone || active.isPhone) ...[
            ColorThemeSectionHeader(s.phoneColors),
            ColorThemeCard(
              child: _PhoneColorsTile(
                selected: active.isPhone,
                description: phoneMissing
                    ? s.phoneColorsUnavailable(
                        s.presetThemeName(kDefaultColorThemeId),
                      )
                    : s.phoneColorsDesc,
                onTap: () => settings.updateColorTheme(kPhoneColorThemeId),
              ),
            ),
            const SizedBox(height: 20),
          ],
          ColorThemeSectionHeader(s.presetThemes),
          _PresetGrid(
            activeId: active.id,
            onApply: apply,
            onCustomize: customize,
          ),
          const SizedBox(height: 20),
          ColorThemeSectionHeader(s.myThemes),
          if (customs.isNotEmpty) ...[
            ColorThemeCard(
              child: Column(
                children: [
                  for (final (i, theme) in customs.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 64),
                    _CustomThemeTile(
                      key: ValueKey(theme.id),
                      theme: theme,
                      selected: theme.id == active.id,
                      onApply: apply,
                      onEdit: edit,
                      onDelete: delete,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: full ? null : create,
              icon: const ThinIcon(tabler.Plus.new, size: 18),
              label: Text(s.createTheme),
            ),
          ),
          if (full) ...[
            const SizedBox(height: 8),
            _Description(
              s.themeLimitReached(kMaxCustomColorThemes),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// [theme]'s name: a preset's or Phone colors' in the app's language, a
/// saved theme's own.
String colorThemeName(BuildContext context, AppColorTheme theme) =>
    theme.isCustom
    ? theme.name ?? ''
    : AppStrings.of(context).presetThemeName(theme.id);

/// A muted line of text.
class _Description extends StatelessWidget {
  const _Description(this.text, {this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

/// The active theme's name, and what can be done with it: a preset can be
/// customized, a saved theme edited.
class _ActiveTheme extends StatelessWidget {
  const _ActiveTheme({required this.theme, this.onCustomize, this.onEdit});

  final AppColorTheme theme;
  final VoidCallback? onCustomize;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final Widget? action = switch (theme) {
      AppColorTheme(isPreset: true) => OutlinedButton.icon(
        onPressed: onCustomize,
        icon: const ThinIcon(tabler.Adjustments.new, size: 18),
        label: Text(s.customizeTheme),
      ),
      AppColorTheme(isCustom: true) => OutlinedButton.icon(
        onPressed: onEdit,
        icon: const ThinIcon(tabler.Pencil.new, size: 18),
        label: Text(s.editTheme),
      ),
      _ => null,
    };
    // The button beside the name, or under it when both don't fit.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          colorThemeName(context, theme),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        ?action,
      ],
    );
  }
}

/// A theme's color: a circle in its main color with its text color on it,
/// ringed and checked when it is the active theme.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.onColor,
    required this.selected,
    this.size = 48,
    this.gradient,
    this.icon = tabler.LetterCase.new,
  });

  final Color color;
  final Color onColor;
  final bool selected;
  final double size;

  /// Painted instead of [color].
  final Gradient? gradient;

  /// What an inactive swatch shows in [onColor]; the active one shows a
  /// check.
  final ThinIconBuilder icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size + 8,
      height: size + 8,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? cs.onSurface : Colors.transparent,
          width: 2,
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gradient == null ? color : null,
          gradient: gradient,
          // Keeps a swatch like the background (white, near black) visible.
          border: Border.all(color: cs.outlineVariant),
        ),
        child: ThinIcon(
          selected ? tabler.Check.new : icon,
          size: size / 2,
          strokeWidth: selected ? 2.5 : 1.75,
          color: onColor,
        ),
      ),
    );
  }
}

/// Phone colors: the wallpaper's colors (Material You), a row of its own.
class _PhoneColorsTile extends StatelessWidget {
  const _PhoneColorsTile({
    required this.selected,
    required this.description,
    required this.onTap,
  });

  final bool selected;

  /// The line under the name: what Phone colors is, or that this phone
  /// can't give them.
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Active, the app's colors are the phone's: show them. Until
              // then they aren't known here, so a color wheel stands in.
              _Swatch(
                color: cs.primary,
                onColor: selected ? cs.onPrimary : const Color(0xFF1A1A2E),
                selected: selected,
                size: 40,
                icon: tabler.DeviceMobile.new,
                gradient: selected
                    ? null
                    : const SweepGradient(
                        colors: [
                          Color(0xFFFFB4AB),
                          Color(0xFFFFE082),
                          Color(0xFFA5D6A7),
                          Color(0xFF80DEEA),
                          Color(0xFF9FA8DA),
                          Color(0xFFF48FB1),
                          Color(0xFFFFB4AB),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.phoneColors,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The presets, in as many columns as fit with every name's longest word
/// whole on its line (two at least).
class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    required this.activeId,
    required this.onApply,
    required this.onCustomize,
  });

  final String activeId;
  final ValueChanged<AppColorTheme> onApply;
  final ValueChanged<AppColorTheme> onCustomize;

  static const double _gap = 8;
  static const double _minTile = 72;

  /// The tile's padding on each side of its name.
  static const double _inset = 4;

  /// A tile's name: bold, bolder for the active theme.
  static TextStyle? labelStyle(BuildContext context, {required bool active}) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      );

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // A line may break between words and after a hyphen.
    final words = RegExp(r'\s+|(?<=-)');
    var widest = 0.0;
    final style = labelStyle(context, active: true);
    for (final preset in kPresetColorThemes) {
      for (final word in s.presetThemeName(preset.id).split(words)) {
        widest = math.max(widest, measureTextWidth(context, word, style));
      }
    }
    final tile = math.max(_minTile, widest.ceilToDouble() + 2 * _inset);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = ((width + _gap) / (tile + _gap)).floor().clamp(2, 6);
        final tileWidth = (width - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final preset in kPresetColorThemes)
              SizedBox(
                width: tileWidth,
                child: _PresetTile(
                  preset: preset,
                  selected: preset.id == activeId,
                  onTap: () => onApply(preset),
                  onLongPress: () => onCustomize(preset),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A preset: its swatch, in the current mode's colors, and its name. A tap
/// applies it, a long press customizes it.
class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final AppColorTheme preset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final brightness = Theme.of(context).brightness;
    return Semantics(
      selected: selected,
      onLongPressHint: s.customizeTheme,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _PresetGrid._inset,
            vertical: 8,
          ),
          child: Column(
            children: [
              _Swatch(
                color: preset.primaryFor(brightness),
                onColor: preset.onPrimaryFor(brightness).color,
                selected: selected,
              ),
              const SizedBox(height: 6),
              Text(
                s.presetThemeName(preset.id),
                textAlign: TextAlign.center,
                style: _PresetGrid.labelStyle(context, active: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CustomAction { edit, delete }

/// A saved theme: its swatch and name. A tap applies it; its menu edits or
/// deletes it.
class _CustomThemeTile extends StatelessWidget {
  const _CustomThemeTile({
    super.key,
    required this.theme,
    required this.selected,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  final AppColorTheme theme;
  final bool selected;
  final ValueChanged<AppColorTheme> onApply;
  final ValueChanged<AppColorTheme> onEdit;
  final ValueChanged<AppColorTheme> onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final danger = Theme.of(context).colorScheme.error;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: () => onApply(theme),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
          child: Row(
            children: [
              _Swatch(
                color: theme.primaryFor(brightness),
                onColor: theme.onPrimaryFor(brightness).color,
                selected: selected,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  theme.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<_CustomAction>(
                icon: const ThinIcon(tabler.DotsVertical.new, size: 20),
                onSelected: (action) => switch (action) {
                  _CustomAction.edit => onEdit(theme),
                  _CustomAction.delete => onDelete(theme),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _CustomAction.edit,
                    child: Row(
                      children: [
                        const ThinIcon(tabler.Pencil.new, size: 18),
                        const SizedBox(width: 12),
                        Flexible(child: Text(s.edit)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _CustomAction.delete,
                    child: Row(
                      children: [
                        ThinIcon(tabler.Trash.new, size: 18, color: danger),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            s.delete,
                            style: TextStyle(color: danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
