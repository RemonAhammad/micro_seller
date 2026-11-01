

library;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_color_theme.dart';
import 'document_brand.dart';

part 'dynamic_color_support.g.dart';

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

abstract final class DynamicColorSupport {

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static ({ColorScheme light, ColorScheme dark})? _primed;

  static Future<void> prime({
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    if (!isSupportedPlatform) return;
    try {
      final palette =
          await DynamicColorPlugin.getCorePalette().timeout(timeout);

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

  static ColorScheme? primedScheme(Brightness brightness) =>
      brightness == Brightness.light ? _primed?.light : _primed?.dark;

  @visibleForTesting
  static void debugReset() => _primed = null;

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

    if (light == null || dark == null) return (light: null, dark: null);
    return (light: light, dark: dark);
  }
}

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
