/// The selected color theme where the widget `Theme` doesn't reach: Phone
/// colors (Material You, the color scheme Android 12+ derives from the
/// wallpaper, read through `dynamic_color`) and the documents' brand color.
///
/// Only Android's palette is used. `DynamicColorBuilder` also reads the
/// desktop accent color on macOS, Windows and Linux; Phone colors isn't
/// offered there, so a theme restored onto one stays Teal.
library;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_color_theme.dart';
import 'document_brand.dart';

part 'dynamic_color_support.g.dart';

/// Brands the generated documents ([DocumentBrand]) with [colorTheme]'s
/// light-mode main color and the text color on it: PDF pages are captured
/// without a Theme, so they read it there. With [lightDynamic] (Phone
/// colors), the system's main color, with white or black text picked by
/// contrast. Writes only when the brand changes, so app.dart can call it on
/// every build.
void publishDocumentBrand(
  AppColorTheme colorTheme, {
  ColorScheme? lightDynamic,
}) {
  final system = colorTheme.isPhone ? lightDynamic : null;
  final color = system?.primary ?? colorTheme.primaryFor(Brightness.light);
  final onColor = system != null
      ? defaultOnColor(color).color
      : colorTheme.onPrimaryFor(Brightness.light).color;
  if (color == DocumentBrand.color && onColor == DocumentBrand.onColor) return;
  DocumentBrand.set(color, onColor: onColor);
}

/// The system color schemes, and reading them before the first frame.
abstract final class DynamicColorSupport {
  /// Whether this platform can have Phone colors: Android (12+ hands out its
  /// palette; older versions answer with none).
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static ({ColorScheme light, ColorScheme dark})? _primed;

  /// Reads the system palette before runApp (main(), when Phone colors is the
  /// saved theme). `DynamicColorBuilder` asks only once the app is built, so
  /// without this the first frame would be Teal and then fade over. Gives up
  /// after [timeout]; never throws.
  static Future<void> prime({
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    if (!isSupportedPlatform) return;
    try {
      final palette =
          await DynamicColorPlugin.getCorePalette().timeout(timeout);
      // The conversion DynamicColorBuilder makes, so its answer equals these
      // schemes and the app theme it builds is the cached one.
      _primed = palette == null
          ? null
          : (
              light: palette.toColorScheme(),
              dark: palette.toColorScheme(brightness: Brightness.dark),
            );
    } catch (_) {
      _primed = null;
    }
  }

  /// The system scheme [prime] read for [brightness], if any.
  static ColorScheme? primedScheme(Brightness brightness) =>
      brightness == Brightness.light ? _primed?.light : _primed?.dark;

  @visibleForTesting
  static void debugReset() => _primed = null;

  /// The system schemes [colorTheme] is drawn with: for Phone colors on
  /// Android, [lightDynamic] / [darkDynamic] from `DynamicColorBuilder`, or
  /// the primed ones until it answers. Null for every other theme, and where
  /// there are none — `AppTheme.build` then uses the theme's own colors
  /// (Teal's, for Phone colors).
  static ({ColorScheme? light, ColorScheme? dark}) schemesFor(
    AppColorTheme colorTheme, {
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  }) {
    if (!colorTheme.isPhone || !isSupportedPlatform) {
      return (light: null, dark: null);
    }
    final light = lightDynamic ?? primedScheme(Brightness.light);
    final dark = darkDynamic ?? primedScheme(Brightness.dark);
    // Always a pair: both from the builder, or both primed.
    if (light == null || dark == null) return (light: null, dark: null);
    return (light: light, dark: dark);
  }
}

/// Whether Phone colors can be offered: Android 12+, where the system hands
/// out its color palette.
@Riverpod(keepAlive: true)
Future<bool> dynamicColorAvailable(Ref ref) async {
  if (!DynamicColorSupport.isSupportedPlatform) return false;
  if (DynamicColorSupport.primedScheme(Brightness.light) != null) return true;
  try {
    return await DynamicColorPlugin.getCorePalette() != null;
  } catch (_) {
    return false;
  }
}
