

library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ThemeStyle {

  vivid,

  soft,

  muted;

  DynamicSchemeVariant get variant => switch (this) {
    ThemeStyle.vivid => DynamicSchemeVariant.fidelity,
    ThemeStyle.soft => DynamicSchemeVariant.tonalSpot,
    ThemeStyle.muted => DynamicSchemeVariant.neutral,
  };
}

enum OnColor {
  white,
  black;

  Color get color => this == OnColor.white ? Colors.white : Colors.black;
}

enum Readability {

  easy,

  largeOnly,

  hard,
}

const double kReadableContrast = 4.5;

const double kLargeTextContrast = 3.0;

const Color kLightScaffoldColor = Color(0xFFF8F9FA);

const Color kDarkScaffoldColor = Color(0xFF263238);

double contrastRatio(Color a, Color b) {
  final la = a.withValues(alpha: 1).computeLuminance();
  final lb = b.withValues(alpha: 1).computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

OnColor recommendedOnColor(Color background) =>
    contrastRatio(background, Colors.white) >=
        contrastRatio(background, Colors.black)
    ? OnColor.white
    : OnColor.black;

Readability readability(Color background, OnColor fg) {
  final ratio = contrastRatio(background, fg.color);
  if (ratio >= kReadableContrast) return Readability.easy;
  if (ratio >= kLargeTextContrast) return Readability.largeOnly;
  return Readability.hard;
}

Color scaffoldColorFor(Brightness brightness) =>
    brightness == Brightness.light ? kLightScaffoldColor : kDarkScaffoldColor;

bool isHardToSee(Color color, Brightness brightness) =>
    contrastRatio(color, scaffoldColorFor(brightness)) < kLargeTextContrast;

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

const kDefaultColorThemeId = 'teal';

const kPhoneColorThemeId = 'phone';

const kCustomColorThemeIdPrefix = 'custom-';

const kMaxCustomColorThemes = 12;

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

  final String id;

  final String? name;

  final int seed;

  final int? accent;

  final ThemeStyle style;

  final OnColor onPrimary;

  final int? darkPrimary;

  final OnColor? darkOnPrimary;

  Color get seedColor => Color(seed);

  Color? get accentColor => accent == null ? null : Color(accent!);

  bool get isPreset => kPresetColorThemes.any((p) => p.id == id);

  bool get isCustom =>
      id.length > kCustomColorThemeIdPrefix.length &&
      id.startsWith(kCustomColorThemeIdPrefix);

  bool get isPhone => id == kPhoneColorThemeId;

  Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark && darkPrimary != null
      ? Color(darkPrimary!)
      : seedColor;

  OnColor onPrimaryFor(Brightness brightness) {
    if (brightness == Brightness.light) return onPrimary;
    final dark = darkPrimary;
    return darkOnPrimary ??
        (dark == null ? onPrimary : recommendedOnColor(Color(dark)));
  }

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

  if (stamp <= _lastCustomStamp) stamp = _lastCustomStamp + 1;
  _lastCustomStamp = stamp;
  return '$kCustomColorThemeIdPrefix$stamp';
}

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

const AppColorTheme kDefaultColorTheme = AppColorTheme(
  id: kDefaultColorThemeId,
  seed: 0xFF00897B,
  accent: 0xFF00BFA5,
  style: ThemeStyle.soft,
  onPrimary: OnColor.white,
  darkPrimary: 0xFF4DB6AC,
  darkOnPrimary: OnColor.white,
);

const List<AppColorTheme> kPresetColorThemes = [
  kDefaultColorTheme,
  AppColorTheme(
    id: 'blue',
    seed: 0xFF1976D2,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF64B5F6,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'indigo',
    seed: 0xFF3F51B5,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF7986CB,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'purple',
    seed: 0xFF8E24AA,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFBA68C8,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'pink',
    seed: 0xFFD81B60,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFF06292,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'red',
    seed: 0xFFD32F2F,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFE57373,
    darkOnPrimary: OnColor.white,
  ),

  AppColorTheme(
    id: 'orange',
    seed: 0xFFE65100,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFFFB74D,
    darkOnPrimary: OnColor.white,
  ),

  AppColorTheme(
    id: 'amber',
    seed: 0xFFB07D00,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFFFC107,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'green',
    seed: 0xFF2E7D32,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF81C784,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'brown',
    seed: 0xFF795548,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFA1887F,
    darkOnPrimary: OnColor.white,
  ),
  AppColorTheme(
    id: 'slate',
    seed: 0xFF546E7A,
    style: ThemeStyle.soft,
    onPrimary: OnColor.white,
    darkPrimary: 0xFF90A4AE,
    darkOnPrimary: OnColor.white,
  ),

  AppColorTheme(
    id: 'mono',
    seed: 0xFF000000,
    style: ThemeStyle.vivid,
    onPrimary: OnColor.white,
    darkPrimary: 0xFFFFFFFF,
    darkOnPrimary: OnColor.white,
  ),
];

const AppColorTheme kPhoneColorTheme = AppColorTheme(
  id: kPhoneColorThemeId,
  seed: 0xFF00897B,
  accent: 0xFF00BFA5,
  style: ThemeStyle.soft,
  onPrimary: OnColor.white,
  darkPrimary: 0xFF4DB6AC,
  darkOnPrimary: OnColor.white,
);

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

  }
  return themes;
}

String encodeCustomColorThemes(List<AppColorTheme> themes) =>
    jsonEncode([for (final theme in themes) theme.toJson()]);
