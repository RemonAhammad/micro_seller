/// Color themes: the twelve presets, the seller's saved custom themes and
/// Phone colors (Material You), plus the contrast rules that pick and rate
/// the White or Black text a theme puts on its main color.
///
/// A theme changes only the primary color: the main color, the White or
/// Black text on it, and what Material 3 derives from the main color
/// (containers, tints, surfaces). Sidebar, status, payment, tag, chart and
/// aging colors are fixed and never follow a theme.
///
/// A custom theme's pair (main color + text color) is used exactly, in light
/// and dark mode alike, so the editor's preview is what the seller gets. A
/// preset may carry a curated dark pair: Teal's dark mode uses #4DB6AC with
/// black text, because white on it is 2.44:1.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How colorful the tints Material derives from the main color are.
enum ThemeStyle {
  /// The tints keep the main color's own colorfulness.
  vivid,

  /// Material's default pastel tints (the Teal preset, as before themes).
  soft,

  /// Nearly grey tints.
  muted;

  /// The Material 3 scheme variant `ColorScheme.fromSeed` builds this style
  /// with.
  DynamicSchemeVariant get variant => switch (this) {
    ThemeStyle.vivid => DynamicSchemeVariant.fidelity,
    ThemeStyle.soft => DynamicSchemeVariant.tonalSpot,
    ThemeStyle.muted => DynamicSchemeVariant.neutral,
  };
}

/// The text and icon color on a theme's main color: only white or black.
enum OnColor {
  white,
  black;

  Color get color => this == OnColor.white ? Colors.white : Colors.black;
}

/// How well text reads on a color (WCAG 2 contrast).
enum Readability {
  /// At least 4.5:1, readable at any size.
  easy,

  /// At least 3:1, readable only for large or bold text.
  largeOnly,

  /// Below 3:1.
  hard,
}

/// The contrast ratio [Readability.easy] needs.
const double kReadableContrast = 4.5;

/// The contrast ratio [Readability.largeOnly] needs. A main color below it
/// against the screen background is hard to see ([isHardToSee]).
const double kLargeTextContrast = 3.0;

/// The light theme's screen background.
const Color kLightScaffoldColor = Color(0xFFF8F9FA);

/// The dark theme's screen background (`Colors.blueGrey.shade900`).
const Color kDarkScaffoldColor = Color(0xFF263238);

/// The WCAG 2 contrast ratio of [a] and [b], from 1 (same luminance) to 21
/// (black on white). Alpha is ignored: both are taken as opaque.
double contrastRatio(Color a, Color b) {
  final la = a.withValues(alpha: 1).computeLuminance();
  final lb = b.withValues(alpha: 1).computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// White or black, whichever has the higher contrast on [background] (white
/// on a tie). The better of the two is always at least 4.58:1.
OnColor recommendedOnColor(Color background) =>
    contrastRatio(background, Colors.white) >=
        contrastRatio(background, Colors.black)
    ? OnColor.white
    : OnColor.black;

/// How well [fg] text reads on [background].
Readability readability(Color background, OnColor fg) {
  final ratio = contrastRatio(background, fg.color);
  if (ratio >= kReadableContrast) return Readability.easy;
  if (ratio >= kLargeTextContrast) return Readability.largeOnly;
  return Readability.hard;
}

/// The screen background of [brightness]'s theme.
Color scaffoldColorFor(Brightness brightness) =>
    brightness == Brightness.light ? kLightScaffoldColor : kDarkScaffoldColor;

/// Whether [color] is hard to see against [brightness]'s screen background
/// (below 3:1). The theme editor shows a hint then; the color is never
/// changed.
bool isHardToSee(Color color, Brightness brightness) =>
    contrastRatio(color, scaffoldColorFor(brightness)) < kLargeTextContrast;

/// The text color a theme puts on [color] when no one chose one: a preset's
/// curated choice when [color] is one of the presets' main colors (Teal's
/// #00897B keeps its white text, although black has slightly more
/// contrast), otherwise [recommendedOnColor].
OnColor defaultOnColor(Color color) {
  for (final preset in kPresetColorThemes) {
    if (color == preset.seedColor) return preset.onPrimary;
    final dark = preset.darkPrimary;
    if (dark != null && color == Color(dark)) {
      return preset.onPrimaryFor(Brightness.dark);
    }
  }
  return recommendedOnColor(color);
}

/// The id of the default theme, Teal.
const kDefaultColorThemeId = 'teal';

/// The id of Phone colors (Material You, Android 12+).
const kPhoneColorThemeId = 'phone';

/// Every custom theme's id starts with this.
const kCustomColorThemeIdPrefix = 'custom-';

/// How many custom themes can be saved.
const kMaxCustomColorThemes = 12;

/// A color theme: a preset, Phone colors, or one the seller saved.
///
/// Colors are stored as ARGB ints, so a theme serializes to plain JSON (the
/// settings and the backup carry it).
@immutable
class AppColorTheme {
  const AppColorTheme({
    required this.id,
    this.name,
    required this.seed,
    this.accent,
    this.style = ThemeStyle.vivid,
    required this.onPrimary,
    this.darkPrimary,
    this.darkOnPrimary,
  });

  /// A new custom theme with a fresh id (`custom-<microseconds>`). Without
  /// [onPrimary], the text color is the one that reads better on [seed].
  factory AppColorTheme.custom({
    required String name,
    required int seed,
    int? accent,
    ThemeStyle style = ThemeStyle.vivid,
    OnColor? onPrimary,
  }) => AppColorTheme(
    id: _newCustomId(),
    name: name,
    seed: seed,
    accent: accent,
    style: style,
    onPrimary: onPrimary ?? recommendedOnColor(Color(seed)),
  );

  /// `teal`, `phone`, a preset id, or `custom-…`.
  final String id;

  /// The seller's name for a custom theme. Presets have none: the UI names
  /// them by id (`AppStrings.presetThemeName`).
  final String? name;

  /// The main color (ARGB). Material derives the rest of the palette from it.
  final int seed;

  /// The optional accent (ARGB): the scheme's secondary color, its text
  /// color picked automatically ([recommendedOnColor]).
  final int? accent;

  final ThemeStyle style;

  /// The text and icon color on the main color.
  final OnColor onPrimary;

  /// A preset's curated dark-mode main color (ARGB). Without it, dark mode
  /// uses the main color, as custom themes do.
  final int? darkPrimary;

  /// The text color on [darkPrimary]. Without it: [onPrimary] when there's
  /// no [darkPrimary], else the one that reads better on it.
  final OnColor? darkOnPrimary;

  Color get seedColor => Color(seed);

  Color? get accentColor => accent == null ? null : Color(accent!);

  bool get isPreset => kPresetColorThemes.any((p) => p.id == id);

  bool get isCustom =>
      id.length > kCustomColorThemeIdPrefix.length &&
      id.startsWith(kCustomColorThemeIdPrefix);

  bool get isPhone => id == kPhoneColorThemeId;

  /// The main color in [brightness]'s theme.
  Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark && darkPrimary != null
      ? Color(darkPrimary!)
      : seedColor;

  /// The text color on [primaryFor] in [brightness]'s theme.
  OnColor onPrimaryFor(Brightness brightness) {
    if (brightness == Brightness.light) return onPrimary;
    final dark = darkPrimary;
    return darkOnPrimary ??
        (dark == null ? onPrimary : recommendedOnColor(Color(dark)));
  }

  /// A copy with the given fields replaced. [name], [accent], [darkPrimary]
  /// and [darkOnPrimary] can be cleared by passing `null` (leaving them out
  /// keeps them).
  AppColorTheme copyWith({
    String? id,
    Object? name = _keep,
    int? seed,
    Object? accent = _keep,
    ThemeStyle? style,
    OnColor? onPrimary,
    Object? darkPrimary = _keep,
    Object? darkOnPrimary = _keep,
  }) => AppColorTheme(
    id: id ?? this.id,
    name: identical(name, _keep) ? this.name : name as String?,
    seed: seed ?? this.seed,
    accent: identical(accent, _keep) ? this.accent : accent as int?,
    style: style ?? this.style,
    onPrimary: onPrimary ?? this.onPrimary,
    darkPrimary: identical(darkPrimary, _keep)
        ? this.darkPrimary
        : darkPrimary as int?,
    darkOnPrimary: identical(darkOnPrimary, _keep)
        ? this.darkOnPrimary
        : darkOnPrimary as OnColor?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    'seed': seed,
    if (accent != null) 'accent': accent,
    'style': style.name,
    'onPrimary': onPrimary.name,
    if (darkPrimary != null) 'darkPrimary': darkPrimary,
    if (darkOnPrimary != null) 'darkOnPrimary': darkOnPrimary!.name,
  };

  /// The theme in [json] (a map, or its JSON text), or null when it isn't
  /// one: no id, or no valid main color. Never throws.
  ///
  /// Optional fields degrade instead: a bad accent or dark color is dropped,
  /// an unknown style is [ThemeStyle.vivid], a missing or unknown text color
  /// is the one that reads better on the main color, and a blank name is
  /// none. Colors are made opaque (a theme's colors are never translucent).
  static AppColorTheme? fromJson(Object? json) {
    try {
      var data = json;
      if (data is String) data = jsonDecode(data);
      if (data is! Map) return null;
      final id = data['id'];
      final seed = _argb(data['seed']);
      if (id is! String || id.trim().isEmpty || seed == null) return null;
      final name = data['name'];
      final trimmed = name is String ? name.trim() : '';
      final darkOn = data['darkOnPrimary'];
      final on = data['onPrimary'];
      final style = data['style'];
      return AppColorTheme(
        id: id,
        name: trimmed.isEmpty ? null : trimmed,
        seed: seed,
        accent: _argb(data['accent']),
        style:
            (style is String ? ThemeStyle.values.asNameMap()[style] : null) ??
            ThemeStyle.vivid,
        onPrimary:
            (on is String ? OnColor.values.asNameMap()[on] : null) ??
            recommendedOnColor(Color(seed)),
        darkPrimary: _argb(data['darkPrimary']),
        darkOnPrimary: darkOn is String
            ? OnColor.values.asNameMap()[darkOn]
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppColorTheme &&
          other.id == id &&
          other.name == name &&
          other.seed == seed &&
          other.accent == accent &&
          other.style == style &&
          other.onPrimary == onPrimary &&
          other.darkPrimary == darkPrimary &&
          other.darkOnPrimary == darkOnPrimary;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    seed,
    accent,
    style,
    onPrimary,
    darkPrimary,
    darkOnPrimary,
  );

  @override
  String toString() => 'AppColorTheme(${jsonEncode(toJson())})';
}

const Object _keep = Object();

int _lastCustomStamp = 0;

String _newCustomId() {
  var stamp = DateTime.now().microsecondsSinceEpoch;
  // Two themes made within one clock tick (the web clock ticks once a
  // millisecond) still get different ids.
  if (stamp <= _lastCustomStamp) stamp = _lastCustomStamp + 1;
  _lastCustomStamp = stamp;
  return '$kCustomColorThemeIdPrefix$stamp';
}

/// [value] as an opaque ARGB int, or null when it isn't an integer in
/// 0..0xFFFFFFFF. Arithmetic, not bit operations, which the web truncates to
/// 32 signed bits.
int? _argb(Object? value) {
  int? n;
  if (value is int) {
    n = value;
  } else if (value is double && value.isFinite && value == value.truncate()) {
    n = value.toInt();
  }
  if (n == null || n < 0 || n > 0xFFFFFFFF) return null;
  return 0xFF000000 + n % 0x1000000;
}

/// Teal, the default theme: today's look, except that dark mode puts black
/// text on #4DB6AC (white there was 2.44:1).
const AppColorTheme kDefaultColorTheme = AppColorTheme(
  id: kDefaultColorThemeId,
  seed: 0xFF00897B,
  accent: 0xFF00BFA5,
  style: ThemeStyle.soft,
  onPrimary: OnColor.white,
  darkPrimary: 0xFF4DB6AC,
  darkOnPrimary: OnColor.black,
);

/// The twelve presets, Teal (the default, as before themes) first. Each has
/// a curated dark pair; every pair reads at least 4.5:1 and every main color
/// is at least 3:1 against its mode's background, except Teal's light pair,
/// which keeps today's white on #00897B (4.32:1).
const List<AppColorTheme> kPresetColorThemes = [
  kDefaultColorTheme,
  AppColorTheme(
    id: 'blue',
    seed: 0xFF1976D2,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF64B5F6,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'indigo',
    seed: 0xFF3F51B5,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF7986CB,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'purple',
    seed: 0xFF8E24AA,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFBA68C8,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'pink',
    seed: 0xFFD81B60,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFF06292,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'red',
    seed: 0xFFD32F2F,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFE57373,
    darkOnPrimary: OnColor.black,
  ),
  // White on any orange that still looks orange is below 4.5:1.
  AppColorTheme(
    id: 'orange',
    seed: 0xFFE65100,
    style: ThemeStyle.soft,
    onPrimary: OnColor.black,
    darkPrimary: 0xFFFFB74D,
    darkOnPrimary: OnColor.black,
  ),
  // Amber itself (#FFC107) is 1.6:1 on the light background, so light mode
  // uses a deep amber; dark mode gets the real one.
  AppColorTheme(
    id: 'amber',
    seed: 0xFFB07D00,
    style: ThemeStyle.soft,
    onPrimary: OnColor.black,
    darkPrimary: 0xFFFFC107,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'green',
    seed: 0xFF2E7D32,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF81C784,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'brown',
    seed: 0xFF795548,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFA1887F,
    darkOnPrimary: OnColor.black,
  ),
  AppColorTheme(
    id: 'slate',
    seed: 0xFF546E7A,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF90A4AE,
    darkOnPrimary: OnColor.black,
  ),
  // Vivid keeps a colorless seed's tints grey; Soft would tint them pink
  // (Material gives a hueless seed the hue of red).
  AppColorTheme(
    id: 'mono',
    seed: 0xFF000000,
    style: ThemeStyle.vivid,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFFFFFFF,
    darkOnPrimary: OnColor.black,
  ),
];

/// Phone colors. The system scheme (`AppTheme.build`'s `dynamicScheme`)
/// replaces these colors; until it's known, or where there is none, the app
/// looks exactly like Teal.
const AppColorTheme kPhoneColorTheme = AppColorTheme(
  id: kPhoneColorThemeId,
  seed: 0xFF00897B,
  accent: 0xFF00BFA5,
  style: ThemeStyle.soft,
  onPrimary: OnColor.white,
  darkPrimary: 0xFF4DB6AC,
  darkOnPrimary: OnColor.black,
);

/// The theme [id] names: Phone colors, a preset, or one of [customs]. A
/// missing or unknown id (a deleted custom theme, a newer backup's preset)
/// is Teal.
AppColorTheme resolveColorTheme(String? id, List<AppColorTheme> customs) {
  if (id == null) return kDefaultColorTheme;
  if (id == kPhoneColorThemeId) return kPhoneColorTheme;
  for (final preset in kPresetColorThemes) {
    if (preset.id == id) return preset;
  }
  for (final custom in customs) {
    if (custom.id == id) return custom;
  }
  return kDefaultColorTheme;
}

/// The custom themes in [raw] (their JSON text, or the decoded list). Only
/// valid custom themes are kept, the first of each id, at most
/// [kMaxCustomColorThemes]. Anything else is an empty list; never throws.
List<AppColorTheme> decodeCustomColorThemes(Object? raw) {
  final themes = <AppColorTheme>[];
  try {
    var data = raw;
    if (data is String) {
      if (data.trim().isEmpty) return themes;
      data = jsonDecode(data);
    }
    if (data is! List) return themes;
    final ids = <String>{};
    for (final item in data) {
      final theme = AppColorTheme.fromJson(item);
      if (theme == null || !theme.isCustom || !ids.add(theme.id)) continue;
      themes.add(theme);
      if (themes.length == kMaxCustomColorThemes) break;
    }
  } catch (_) {
    // Garbage in the stored value: keep what was decoded before it.
  }
  return themes;
}

/// [themes] as JSON text, for [decodeCustomColorThemes].
String encodeCustomColorThemes(List<AppColorTheme> themes) =>
    jsonEncode([for (final theme in themes) theme.toJson()]);
