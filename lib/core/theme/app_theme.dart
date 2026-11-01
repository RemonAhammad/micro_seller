import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../constants/app_icons.dart';
import 'app_color_theme.dart';
import 'app_fonts.dart';
import 'brand_colors.dart';

final _thinActionIcons = ActionIconThemeData(
  backButtonIconBuilder: (context) => Directionality.of(context) == TextDirection.rtl
      ? const ThinIcon(tabler.ArrowRight.new)
      : const ThinIcon(tabler.ArrowLeft.new),
  drawerButtonIconBuilder: (_) => const ThinIcon(tabler.Menu2.new),
  endDrawerButtonIconBuilder: (_) => const ThinIcon(tabler.Menu2.new),
  closeButtonIconBuilder: (_) => const ThinIcon(tabler.X.new),
);

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => build(Brightness.light, kDefaultColorTheme);

  static ThemeData get darkTheme => build(Brightness.dark, kDefaultColorTheme);

  static const _cacheSize = 32;

  static final _cache = <Object, ThemeData>{};

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

  static bool _isTealPalette(AppColorTheme theme) =>
      theme.seed == kDefaultColorTheme.seed &&
      theme.accent == kDefaultColorTheme.accent &&
      theme.style == kDefaultColorTheme.style &&
      theme.onPrimary == kDefaultColorTheme.onPrimary;

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
