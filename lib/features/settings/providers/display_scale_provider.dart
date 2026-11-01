import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/app_zoom.dart';

part 'display_scale_provider.g.dart';

typedef DisplayScaleState = ({int displayPercent, int? textPercent});

@Riverpod(keepAlive: true)
class DisplayScale extends _$DisplayScale {
  static const keyDisplayPercent = 'displayScalePercent';
  static const keyTextPercent = 'textScalePercent';

  static const DisplayScaleState _defaults = (
    displayPercent: 100,
    textPercent: null,
  );

  static DisplayScaleState? _primed;

  static void primeFrom(SharedPreferences prefs) {
    try {

      _primed = (
        displayPercent: normaliseDisplayPercent(prefs.get(keyDisplayPercent)),
        textPercent: normaliseTextPercent(prefs.get(keyTextPercent)),
      );
    } catch (_) {
      _primed = null;
    }
  }

  @visibleForTesting
  static void debugResetPrimed() => _primed = null;

  static int normaliseDisplayPercent(Object? raw) =>
      raw is num && raw.isFinite ? snapPercent(raw) : 100;

  static int? normaliseTextPercent(Object? raw) =>
      raw is num && raw.isFinite ? snapPercent(raw) : null;

  @override
  DisplayScaleState build() => _primed ?? _defaults;

  Future<void> setDisplayPercent(int percent) async {
    final displayPercent = snapPercent(percent);
    state = (displayPercent: displayPercent, textPercent: state.textPercent);
    _primed = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyDisplayPercent, displayPercent);
  }

  Future<void> setTextPercent(int? percent) async {
    final textPercent = percent == null ? null : snapPercent(percent);
    state = (displayPercent: state.displayPercent, textPercent: textPercent);
    _primed = state;
    final prefs = await SharedPreferences.getInstance();
    if (textPercent == null) {
      await prefs.remove(keyTextPercent);
    } else {
      await prefs.setInt(keyTextPercent, textPercent);
    }
  }
}
