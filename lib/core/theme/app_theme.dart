import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../constants/app_icons.dart';
import 'app_color_theme.dart';
import 'app_fonts.dart';
import 'brand_colors.dart';

/// Flutter's own app-bar buttons (back arrow, drawer, close) drawn with the
/// same thin Tabler icons as the rest of the app. The back arrow points
/// right in RTL layouts (Arabic, Urdu), as Material's own does.
final _thinActionIcons = ActionIconThemeData(
  backButtonIconBuilder: (context) => Directionality.of(context) == TextDirection.rtl
      ? const ThinIcon(tabler.ArrowRight.new)
      : const ThinIcon(tabler.ArrowLeft.new),
  drawerButtonIconBuilder: (_) => const ThinIcon(tabler.Menu2.new),
  endDrawerButtonIconBuilder: (_) => const ThinIcon(tabler.Menu2.new),
  closeButtonIconBuilder: (_) => const ThinIcon(tabler.X.new),
);

/// The app's light and dark themes for a color theme.
///
/// A color theme sets only the color scheme's primary pair (and its accent);
/// every component theme reads the scheme, so buttons, the FAB, focused
/// fields and text selection follow it, with the theme's own text color on
/// the main color. Surfaces keep their fixed neutrals (white / #F8F9FA in
/// light mode; #1C1C2E, #252535 and blue-grey in dark mode).
///
/// The light and dark component themes differ on purpose, as before themes,
/// and the layout tests depend on it: only light mode sets the filled and
/// outlined buttons, chips, dividers, list tiles and the bottom navigation
/// bar; only dark mode sets text selection and the input icon colors.
///
/// Every text style the theme names a font in uses [appFontFamily]: the
/// bundled Roboto on iOS, Android's system Roboto elsewhere. That includes
/// the app bar title and the button text styles, which replace the text
/// theme's rather than merge with it (with no family, iOS drew them in San
/// Francisco).
///
/// It sets no status bar style: no AppBar reaches the status bar under the
/// shell's SafeArea. The app frame sets it (`system_ui_style.dart`).
class AppTheme {
  AppTheme._();

  /// Teal's light theme, the default.
  static ThemeData get lightTheme => build(Brightness.light, kDefaultColorTheme);

  /// Teal's dark theme, the default.
  static ThemeData get darkTheme => build(Brightness.dark, kDefaultColorTheme);

  static const _cacheSize = 32;

  /// Recently built themes, least recently used first.
  static final _cache = <Object, ThemeData>{};

  /// [brightness]'s theme for [theme]. With [dynamicScheme] (Phone colors),
  /// that system scheme is the color scheme, with its own onPrimary, and
  /// [theme]'s colors are not used.
  ///
  /// Memoized by brightness and the colors that mode uses (not the theme's
  /// id or name), or by the system scheme, so a rebuild for another reason
  /// (language, shop name) gets the identical [ThemeData] back. The most
  /// recent 32 are kept: the theme editor builds one per color it previews.
  /// The platform is in the key too: it decides the font (the bundled Roboto
  /// on iOS) and what ThemeData takes from it (`platform`, the tap target
  /// size and the visual density), so a test that switches platform never
  /// gets a theme built for another.
  static ThemeData build(Brightness brightness, AppColorTheme theme,
      {ColorScheme? dynamicScheme}) {
    assert(dynamicScheme == null || dynamicScheme.brightness == brightness,
        'dynamicScheme is a ${dynamicScheme.brightness.name} scheme');
    final font = appFontFamily;
    final platform = defaultTargetPlatform;
    final Object key = dynamicScheme != null
        ? (brightness, platform, dynamicScheme)
        : (
            brightness,
            platform,
            theme.seed,
            theme.accent,
            theme.style,
            theme.onPrimary,
            theme.primaryFor(brightness),
            theme.onPrimaryFor(brightness),
          );
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final built = _create(brightness, theme, dynamicScheme, font);
    _cache[key] = built;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return built;
  }

  static ThemeData _create(Brightness brightness, AppColorTheme theme,
      ColorScheme? dynamicScheme, String font) {
    final scheme = dynamicScheme ?? _scheme(brightness, theme);
    final brand = dynamicScheme == null &&
            brightness == Brightness.dark &&
            _isTealPalette(theme)
        ? BrandColors.teal
        : BrandColors.fromPair(
            primary: scheme.primary,
            onPrimary: scheme.onPrimary,
            accent: scheme.secondary,
            onAccent: scheme.onSecondary,
          );
    return brightness == Brightness.light
        ? _light(scheme, brand, font)
        : _dark(scheme, brand, font);
  }

  /// Teal's colors (the preset, Phone colors' fallback, or a saved copy):
  /// they keep two details of the scheme Teal had before themes.
  static bool _isTealPalette(AppColorTheme theme) =>
      theme.seed == kDefaultColorTheme.seed &&
      theme.accent == kDefaultColorTheme.accent &&
      theme.style == kDefaultColorTheme.style &&
      theme.onPrimary == kDefaultColorTheme.onPrimary;

  /// Material 3's scheme for the theme's main color and style, with the
  /// theme's exact pair as primary / onPrimary and its accent as secondary
  /// (text color picked by contrast).
  static ColorScheme _scheme(Brightness brightness, AppColorTheme theme) {
    var scheme = ColorScheme.fromSeed(
      seedColor: theme.seedColor,
      brightness: brightness,
      dynamicSchemeVariant: theme.style.variant,
    ).copyWith(
      primary: theme.primaryFor(brightness),
      onPrimary: theme.onPrimaryFor(brightness).color,
    );
    final accent = theme.accentColor;
    if (accent != null) {
      final onAccent = recommendedOnColor(accent).color;
      scheme = scheme.copyWith(secondary: accent, onSecondary: onAccent);
      // Teal's light scheme also had the accent as its tertiary color.
      if (brightness == Brightness.light && _isTealPalette(theme)) {
        scheme = scheme.copyWith(tertiary: accent, onTertiary: onAccent);
      }
    }
    return scheme;
  }

  static ThemeData _light(
    ColorScheme scheme,
    BrandColors brand,
    String font,
  ) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: font,
    actionIconTheme: _thinActionIcons,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      titleTextStyle: TextStyle(
        fontFamily: font,
        color: const Color(0xFF1A1A2E),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      // 6% black, exactly as `withOpacity(0.06)` rounded it.
      shadowColor: Colors.black.withAlpha(15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: kLightScaffoldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
      hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFF3F4F6),
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: scheme.primary,
      unselectedItemColor: const Color(0xFF9CA3AF),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    scaffoldBackgroundColor: kLightScaffoldColor,
    extensions: [brand],
  );

  static ThemeData _dark(
    ColorScheme scheme,
    BrandColors brand,
    String font,
  ) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: font,
    actionIconTheme: _thinActionIcons,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: const Color(0xFF1C1C2E),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: font,
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFF252535),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Colors.blueGrey.shade800,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blueGrey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: Colors.blueGrey.shade200),
      hintStyle: TextStyle(color: Colors.blueGrey.shade400),
      prefixIconColor: Colors.blueGrey.shade300,
      suffixIconColor: Colors.blueGrey.shade300,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.3),
      selectionHandleColor: scheme.primary,
    ),
    scaffoldBackgroundColor: kDarkScaffoldColor,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    extensions: [brand],
  );
}
