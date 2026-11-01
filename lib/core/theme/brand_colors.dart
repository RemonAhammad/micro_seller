import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_color_theme.dart';

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

  static const BrandColors teal = BrandColors(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    accent: AppColors.accent,
    onAccent: Colors.black,
    gradient: AppColors.dashboardGradient,
  );

  final Color primary;

  final Color onPrimary;

  final Color primaryDark;

  final Color primaryLight;

  final Color accent;

  final Color onAccent;

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

  BrandColors get brand =>
      Theme.of(this).extension<BrandColors>() ?? BrandColors.teal;
}

Color _mix(Color a, Color b, double t) =>
    Color(Color.lerp(a, b, t)!.toARGB32());

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
