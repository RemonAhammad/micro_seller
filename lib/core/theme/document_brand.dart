import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_color_theme.dart';

abstract final class DocumentBrand {
  static const Color _defaultColor = Color(0xFF00897B);
  static const Color _defaultOnColor = Color(0xFFFFFFFF);

  static const Color _page = Color(0xFFFFFFFF);

  static Color _color = _defaultColor;
  static Color _onColor = _defaultOnColor;
  static Color _textColor = _defaultColor;

  static Color get color => _color;

  static Color get onColor => _onColor;

  static final double minTextContrast = contrastRatio(_defaultColor, _page);

  static Color get textColor => _textColor;

  static void set(Color color, {Color? onColor}) {
    _color = color;
    _onColor = onColor ?? defaultOnColor(color).color;
    _textColor = _readableOnPage(color);
  }

  @visibleForTesting
  static void reset() {
    _color = _defaultColor;
    _onColor = _defaultOnColor;
    _textColor = _defaultColor;
  }

  static Color _readableOnPage(Color color) {
    final floor = minTextContrast;
    if (contrastRatio(color, _page) >= floor) return color;
    Color at(double t) =>
        Color(Color.lerp(color, const Color(0xFF000000), t)!.toARGB32());

    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (contrastRatio(at(mid), _page) >= floor) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return at(hi);
  }
}
