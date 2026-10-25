import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_color_theme.dart';

/// The color the generated documents (invoice, statement, report and
/// catalog PDFs) are branded with, the text color on it, and the shade of
/// it that brand-colored text on the white page uses.
///
/// PDF pages are captured from widget trees that have no `Theme`, so the
/// active color theme is published here when it resolves (at startup and on
/// every theme change). The "Powered by Micro Seller" watermark doesn't read
/// it: it stays teal.
abstract final class DocumentBrand {
  static const Color _defaultColor = Color(0xFF00897B);
  static const Color _defaultOnColor = Color(0xFFFFFFFF);

  /// The documents' page color.
  static const Color _page = Color(0xFFFFFFFF);

  static Color _color = _defaultColor;
  static Color _onColor = _defaultOnColor;
  static Color _textColor = _defaultColor;

  /// The brand color: header bands and tints. Teal by default.
  static Color get color => _color;

  /// The text color on [color]. White by default.
  static Color get onColor => _onColor;

  /// The contrast [textColor] has at least on the white page: the default
  /// teal's own (4.32:1). No color theme makes a document's text harder to
  /// read than it was before themes, and Teal's stays as it was.
  static final double minTextContrast = contrastRatio(_defaultColor, _page);

  /// The brand color for text on the white page (shop names, table titles,
  /// prices, credits): [color] itself when it reads there at least as well
  /// as the default teal ([minTextContrast]), otherwise [color] darkened
  /// toward black until it does. A light theme color (yellow, white) would
  /// be all but invisible as text on white. Header bands keep [color], with
  /// [onColor] text on them.
  static Color get textColor => _textColor;

  /// Brands documents with [color], with [onColor] text on it.
  ///
  /// Pass the theme's own text color (a custom theme's White or Black
  /// choice). Left out, it is [defaultOnColor]: a preset's curated text
  /// color when [color] is a preset's main color (Teal keeps white, as its
  /// documents had before themes), otherwise the higher-contrast of white
  /// and black (Phone colors).
  static void set(Color color, {Color? onColor}) {
    _color = color;
    _onColor = onColor ?? defaultOnColor(color).color;
    _textColor = _readableOnPage(color);
  }

  /// Back to teal with white text.
  @visibleForTesting
  static void reset() {
    _color = _defaultColor;
    _onColor = _defaultOnColor;
    _textColor = _defaultColor;
  }

  /// [color], or the least darkened shade of it (mixed toward black) that
  /// reads on the page at [minTextContrast].
  static Color _readableOnPage(Color color) {
    final floor = minTextContrast;
    if (contrastRatio(color, _page) >= floor) return color;
    Color at(double t) =>
        Color(Color.lerp(color, const Color(0xFF000000), t)!.toARGB32());
    // Black reads at 21:1; darker only ever reads better.
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
