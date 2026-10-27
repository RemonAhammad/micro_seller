import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/app_zoom.dart';

part 'display_scale_provider.g.dart';

/// Display size (whole-app zoom, in percent) and Text size (in percent, or
/// null to follow the phone's font size).
typedef DisplayScaleState = ({int displayPercent, int? textPercent});

/// Settings → Display size / Text size, applied by `AppZoom` around the
/// router (app_frame.dart).
///
/// Per-device on purpose, so it lives outside `Settings` and its
/// `exportSettings()`: the right size depends on this screen and on the
/// phone's own font setting, and a phone backup restored on a tablet must
/// not resize it. Same precedent as ReviewService's per-device prompt state.
///
/// [DisplayScale.primeFrom] runs in main() before runApp, so the first frame
/// is already at the saved size.
@Riverpod(keepAlive: true)
class DisplayScale extends _$DisplayScale {
  static const keyDisplayPercent = 'displayScalePercent';
  static const keyTextPercent = 'textScalePercent';

  static const DisplayScaleState _defaults = (
    displayPercent: 100,
    textPercent: null,
  );

  // The saved sizes: read at startup by primeFrom, kept current by the
  // setters, so a rebuilt provider never returns to a stale snapshot.
  static DisplayScaleState? _primed;

  /// Reads the saved sizes synchronously (main(), before runApp). Never
  /// throws: an unusable value falls back to its default.
  static void primeFrom(SharedPreferences prefs) {
    try {
      // prefs.get + `is num` rather than getInt: the typed getters throw on
      // a value of another type.
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

  /// A stored Display size, snapped to the offered range; 100 if it isn't a
  /// finite number.
  static int normaliseDisplayPercent(Object? raw) =>
      raw is num && raw.isFinite ? snapPercent(raw) : 100;

  /// A stored Text size, snapped to the offered range; null (follow the
  /// phone) if it is missing or isn't a finite number.
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

  /// null follows the phone's font size again.
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
