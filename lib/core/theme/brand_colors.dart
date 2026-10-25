import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_color_theme.dart';

/// The active color theme's brand colors, for widgets that used the fixed
/// `AppColors` brand constants (headers and their gradient, icon tints,
/// highlights). Read them with `context.brand`.
///
/// They are the theme's main color and its text color for the current mode
/// (the color scheme's primary and onPrimary), with a few shades derived
/// from them. One exception keeps Teal as it was before themes: its brand
/// colors stay [BrandColors.teal] in dark mode too (headers and tints were
/// #00897B there), while its dark color scheme uses #4DB6AC for buttons.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.onAccent,
    required this.gradient,
  });

  /// The brand colors of a main color and the text on it.
  ///
  /// The shades are derived so that text in [onPrimary] stays readable on
  /// them: [primaryDark] never reads worse than [primary] does (or than
  /// 4.5:1), and [gradient] runs from [primary] away from the text color,
  /// so the text only gains contrast along it. Teal's pair (#00897B, white)
  /// gets [teal]'s shades exactly. Without [accent], the accent is
  /// [primaryLight].
  factory BrandColors.fromPair({
    required Color primary,
    required Color onPrimary,
    Color? accent,
    Color? onAccent,
  }) {
    final BrandColors base;
    if (primary == teal.primary && onPrimary == teal.onPrimary) {
      base = teal;
    } else {
      final light = _mix(primary, Colors.white, 0.3);
      final lightText =
          onPrimary.computeLuminance() > primary.computeLuminance();
      base = BrandColors(
        primary: primary,
        onPrimary: onPrimary,
        primaryDark: _darker(primary, onPrimary, 0.25),
        primaryLight: light,
        accent: light,
        onAccent: recommendedOnColor(light).color,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            lightText
                ? _mix(primary, Colors.black, 0.44)
                : _mix(primary, Colors.white, 0.35),
          ],
        ),
      );
    }
    if (accent == null) return base;
    return base.copyWith(
      accent: accent,
      onAccent: onAccent ?? recommendedOnColor(accent).color,
    );
  }

  /// Teal, exactly the `AppColors` brand constants the app used before
  /// themes.
  static const BrandColors teal = BrandColors(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    accent: AppColors.accent,
    onAccent: Colors.black,
    gradient: AppColors.dashboardGradient,
  );

  /// The main color.
  final Color primary;

  /// The text and icon color on [primary] (and on [gradient]).
  final Color onPrimary;

  /// A darker shade of [primary] (a gradient's second stop).
  final Color primaryDark;

  /// A lighter shade of [primary].
  final Color primaryLight;

  /// The accent: the theme's own, or one derived from the main color.
  final Color accent;

  /// The text color on [accent].
  final Color onAccent;

  /// The dashboard and reports header gradient, from [primary].
  final LinearGradient gradient;

  @override
  BrandColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accent,
    Color? onAccent,
    LinearGradient? gradient,
  }) => BrandColors(
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryDark: primaryDark ?? this.primaryDark,
    primaryLight: primaryLight ?? this.primaryLight,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    gradient: gradient ?? this.gradient,
  );

  @override
  BrandColors lerp(covariant ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors || identical(other, this) || t == 0) return this;
    if (t == 1) return other;
    return BrandColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      gradient: LinearGradient.lerp(gradient, other.gradient, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrandColors &&
          other.primary == primary &&
          other.onPrimary == onPrimary &&
          other.primaryDark == primaryDark &&
          other.primaryLight == primaryLight &&
          other.accent == accent &&
          other.onAccent == onAccent &&
          other.gradient == gradient;

  @override
  int get hashCode => Object.hash(
    primary,
    onPrimary,
    primaryDark,
    primaryLight,
    accent,
    onAccent,
    gradient,
  );
}

extension BrandColorsContext on BuildContext {
  /// The active theme's [BrandColors] ([BrandColors.teal] under a theme
  /// that carries none).
  BrandColors get brand =>
      Theme.of(this).extension<BrandColors>() ?? BrandColors.teal;
}

/// [a] mixed toward [b] by [t], rounded to 8 bits per channel.
Color _mix(Color a, Color b, double t) =>
    Color(Color.lerp(a, b, t)!.toARGB32());

/// [primary] darkened toward black by up to [amount], but never so far that
/// [on] reads worse on it than on [primary] itself (or than 4.5:1). Only
/// dark text loses contrast as its background darkens.
Color _darker(Color primary, Color on, double amount) {
  final floor = math.min(kReadableContrast, contrastRatio(primary, on));
  Color at(double t) => _mix(primary, Colors.black, t);
  final full = at(amount);
  if (contrastRatio(full, on) >= floor) return full;
  var lo = 0.0;
  var hi = amount;
  for (var i = 0; i < 16; i++) {
    final mid = (lo + hi) / 2;
    if (contrastRatio(at(mid), on) >= floor) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return at(lo);
}
