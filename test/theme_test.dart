// Color themes: Teal looks exactly as before themes (one deliberate fix),
// the White / Black text rules, the presets' contrast in both modes, a
// custom theme's pair used exactly, JSON that never throws, memoization,
// BrandColors, DocumentBrand, and a loading AppButton's spinner.
//
// `_legacyLight` / `_legacyDark` (bottom of the file) are the fixed teal
// `AppTheme.lightTheme` / `darkTheme` as they were before themes, captured
// role by role from that code, with two later changes marked there: the app
// bar title and button text name the app's font, and no status bar style.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_colors.dart';
import 'package:micro_seller/core/theme/app_color_theme.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/theme/brand_colors.dart';
import 'package:micro_seller/core/theme/document_brand.dart';
import 'package:micro_seller/shared/widgets/app_button.dart';

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

const _light = Brightness.light;
const _dark = Brightness.dark;

ThemeData _build(Brightness b, AppColorTheme t) => AppTheme.build(b, t);

BrandColors _brandOf(ThemeData t) => t.extension<BrandColors>()!;

AppColorTheme _custom(
  int seed,
  OnColor on, {
  int? accent,
  ThemeStyle style = ThemeStyle.vivid,
}) => AppColorTheme(
  id: 'custom-1',
  name: 'Mine',
  seed: seed,
  accent: accent,
  style: style,
  onPrimary: on,
);

AppColorTheme _preset(String id) =>
    kPresetColorThemes.singleWhere((p) => p.id == id);

/// Colors across the wheel and the grey ramp, light to dark.
List<Color> _sweep() => [
  for (var hue = 0.0; hue < 360; hue += 20)
    for (final lightness in [0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9])
      for (final saturation in [0.35, 1.0])
        HSLColor.fromAHSL(1, hue, saturation, lightness).toColor(),
  for (var v = 0; v <= 255; v += 15) Color.fromARGB(255, v, v, v),
];

void main() {
  group('Teal looks as before themes', () {
    test('light: every color scheme role and component theme, except the '
        "accent's text color", () {
      // The accent's text color is picked by contrast now: black on #00BFA5
      // is 9.0:1, white was 2.33:1. No widget reads either role (Material 3
      // components don't; the app never did).
      expect(_legacyLight['scheme.onSecondary'], '0xFFFFFFFF');
      expect(_legacyLight['scheme.onTertiary'], '0xFFFFFFFF');
      expect(_fingerprint(_build(_light, kDefaultColorTheme)), {
        ..._legacyLight,
        'scheme.onSecondary': '0xFF000000',
        'scheme.onTertiary': '0xFF000000',
      });
    });

    test(
      'dark: the same, except black text on the #4DB6AC buttons and FAB',
      () {
        const tealDark = Color(0xFF4DB6AC);
        // The deliberate fix: white on #4DB6AC is 2.44:1, black is 8.6:1.
        expect(contrastRatio(_white, tealDark), closeTo(2.44, 0.01));
        expect(contrastRatio(_black, tealDark), greaterThan(kReadableContrast));
        expect(_legacyDark['elevated.fg'], '0xFFFFFFFF');
        expect(_legacyDark['fab.fg'], '0xFFFFFFFF');
        // The scheme's onPrimary was Material's #003731 (5.4:1 on #4DB6AC),
        // and only the elevated buttons and the FAB set white over it. It is
        // the theme's black now, so everything Material draws in onPrimary
        // moves from #003731 to black too (a deliberate change): filled
        // buttons' text (dark mode leaves them to Material), switch thumbs,
        // checkbox checks, the date pickers' selected day (the dashboard's
        // too, which puts it on #00897B) and the slider's value label.
        expect(_legacyDark['scheme.onPrimary'], '0xFF003731');
        expect(
          contrastRatio(const Color(0xFF003731), tealDark),
          closeTo(5.4, 0.05),
        );

        final theme = _build(_dark, kDefaultColorTheme);
        expect(theme.colorScheme.primary, tealDark);
        expect(theme.colorScheme.onPrimary, _black);
        expect(_fingerprint(theme), {
          ..._legacyDark,
          'scheme.onPrimary': '0xFF000000',
          'elevated.fg': '0xFF000000',
          // Material derives the press / hover / focus overlay from the
          // text color.
          'elevated.overlay.pressed': '0x1A000000',
          'elevated.overlay.hovered': '0x14000000',
          'elevated.overlay.focused': '0x1A000000',
          'fab.fg': '0xFF000000',
          // The accent's text color, as in light mode.
          'scheme.onSecondary': '0xFF000000',
        });
      },
    );

    test('lightTheme / darkTheme are the Teal builds', () {
      expect(
        identical(AppTheme.lightTheme, _build(_light, kDefaultColorTheme)),
        isTrue,
      );
      expect(
        identical(AppTheme.darkTheme, _build(_dark, kDefaultColorTheme)),
        isTrue,
      );
      expect(AppTheme.lightTheme.brightness, _light);
      expect(AppTheme.darkTheme.brightness, _dark);
    });

    test('Teal is the default and the first preset', () {
      expect(kDefaultColorTheme.id, kDefaultColorThemeId);
      expect(identical(kPresetColorThemes.first, kDefaultColorTheme), isTrue);
      expect(kDefaultColorTheme.seedColor, AppColors.primary);
      expect(kDefaultColorTheme.accentColor, AppColors.accent);
      expect(kDefaultColorTheme.style, ThemeStyle.soft);
      expect(kDefaultColorTheme.onPrimary, OnColor.white);
      expect(Color(kDefaultColorTheme.darkPrimary!), AppColors.primaryLight);
      expect(kDefaultColorTheme.darkOnPrimary, OnColor.black);
    });

    test('brand colors are the old AppColors constants in both modes', () {
      for (final b in Brightness.values) {
        expect(
          _brandOf(_build(b, kDefaultColorTheme)),
          BrandColors.teal,
          reason: b.name,
        );
      }
    });

    test('Phone colors without a system scheme look exactly like Teal', () {
      for (final b in Brightness.values) {
        expect(
          identical(_build(b, kPhoneColorTheme), _build(b, kDefaultColorTheme)),
          isTrue,
        );
      }
    });

    test('a saved copy of Teal looks like Teal in light mode', () {
      final copy = AppColorTheme.custom(
        name: 'My teal',
        seed: kDefaultColorTheme.seed,
        accent: kDefaultColorTheme.accent,
        style: ThemeStyle.soft,
        onPrimary: OnColor.white,
      );
      expect(
        identical(_build(_light, copy), _build(_light, kDefaultColorTheme)),
        isTrue,
      );
      // Its own pair in dark mode too, as for every custom theme.
      final dark = _build(_dark, copy);
      expect(dark.colorScheme.primary, AppColors.primary);
      expect(dark.colorScheme.onPrimary, _white);
      expect(_brandOf(dark), BrandColors.teal);
    });
  });

  group('presets', () {
    test('the twelve, Teal first, unique ids', () {
      expect(kPresetColorThemes.map((p) => p.id), [
        'teal', 'blue', 'indigo', 'purple', 'pink', 'red', //
        'orange', 'amber', 'green', 'brown', 'slate', 'mono',
      ]);
      for (final p in kPresetColorThemes) {
        expect(p.isPreset, isTrue, reason: p.id);
        expect(p.isCustom, isFalse, reason: p.id);
        expect(p.isPhone, isFalse, reason: p.id);
        expect(p.name, isNull, reason: 'presets are named by id (l10n)');
      }
    });

    test('every pair reads at least 4.5:1 and every main color is at least '
        "3:1 on its mode's background, in both modes", () {
      for (final p in kPresetColorThemes) {
        for (final b in Brightness.values) {
          final reason = '${p.id} ${b.name}';
          final main = p.primaryFor(b);
          final on = p.onPrimaryFor(b).color;
          if (p.id == 'teal' && b == _light) {
            // Teal keeps white on #00897B, as before themes (4.32:1).
            expect(
              contrastRatio(main, on),
              closeTo(4.32, 0.01),
              reason: reason,
            );
          } else {
            expect(
              contrastRatio(main, on),
              greaterThanOrEqualTo(kReadableContrast),
              reason: reason,
            );
          }
          expect(
            contrastRatio(main, scaffoldColorFor(b)),
            greaterThanOrEqualTo(kLargeTextContrast),
            reason: reason,
          );
          expect(isHardToSee(main, b), isFalse, reason: reason);
        }
      }
    });

    test('the built theme uses the curated pair everywhere', () {
      for (final p in kPresetColorThemes) {
        for (final b in Brightness.values) {
          final reason = '${p.id} ${b.name}';
          final theme = _build(b, p);
          final main = p.primaryFor(b);
          final on = p.onPrimaryFor(b).color;
          final f = _fingerprint(theme);
          expect(theme.colorScheme.primary, main, reason: reason);
          expect(theme.colorScheme.onPrimary, on, reason: reason);
          expect(f['elevated.bg'], _hex(main), reason: reason);
          expect(f['elevated.fg'], _hex(on), reason: reason);
          expect(f['fab.bg'], _hex(main), reason: reason);
          expect(f['fab.fg'], _hex(on), reason: reason);
          expect(
            theme.scaffoldBackgroundColor,
            scaffoldColorFor(b),
            reason: reason,
          );
          if (p.id != 'teal') {
            final brand = _brandOf(theme);
            expect(brand.primary, main, reason: reason);
            expect(brand.onPrimary, on, reason: reason);
          }
        }
      }
    });

    test('Amber and Orange use black text; the others white in light mode', () {
      for (final p in kPresetColorThemes) {
        expect(
          p.onPrimary,
          p.id == 'amber' || p.id == 'orange' ? OnColor.black : OnColor.white,
          reason: p.id,
        );
        expect(p.onPrimaryFor(_dark), OnColor.black, reason: p.id);
      }
    });

    test('Mono: black with white text in light, white with black text in '
        'dark, and grey tints', () {
      final mono = _preset('mono');
      final light = _build(_light, mono).colorScheme;
      final dark = _build(_dark, mono).colorScheme;
      expect((light.primary, light.onPrimary), (_black, _white));
      expect((dark.primary, dark.onPrimary), (_white, _black));
      for (final scheme in [light, dark]) {
        for (final c in [
          scheme.primaryContainer,
          scheme.secondary,
          scheme.secondaryContainer,
          scheme.tertiaryContainer,
          scheme.surface,
          scheme.inversePrimary,
        ]) {
          final argb = c.toARGB32();
          final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF;
          expect([r, g], [argb & 0xFF, argb & 0xFF], reason: _hex(c));
        }
      }
    });
  });

  group('text color: White or Black', () {
    test('contrastRatio is WCAG 2', () {
      expect(contrastRatio(_white, _black), closeTo(21, 1e-9));
      expect(contrastRatio(_black, _white), closeTo(21, 1e-9));
      expect(contrastRatio(AppColors.primary, AppColors.primary), 1);
      expect(
        contrastRatio(const Color(0xFF767676), _white),
        closeTo(4.54, 0.01),
      );
      // Alpha is ignored.
      expect(contrastRatio(const Color(0x80000000), _white), closeTo(21, 1e-9));
    });

    test('recommended is the higher-contrast of the two', () {
      const expected = {
        0xFFFFFFFF: OnColor.black,
        0xFF000000: OnColor.white,
        0xFF808080: OnColor.black,
        0xFFFFFF00: OnColor.black,
        0xFF00FFFF: OnColor.black,
        0xFF000080: OnColor.white,
        0xFFFFC107: OnColor.black,
      };
      expected.forEach((argb, on) {
        expect(recommendedOnColor(Color(argb)), on, reason: _hex(Color(argb)));
      });
      final colors = [
        for (final argb in expected.keys) Color(argb),
        for (final p in kPresetColorThemes) ...[
          p.seedColor,
          if (p.darkPrimary != null) Color(p.darkPrimary!),
          if (p.accentColor != null) p.accentColor!,
        ],
        ..._sweep(),
      ];
      for (final c in colors) {
        final chosen = recommendedOnColor(c);
        final other = chosen == OnColor.white ? OnColor.black : OnColor.white;
        expect(
          contrastRatio(c, chosen.color),
          greaterThanOrEqualTo(contrastRatio(c, other.color)),
          reason: _hex(c),
        );
        // The better of the two always reads.
        expect(
          contrastRatio(c, chosen.color),
          greaterThanOrEqualTo(kReadableContrast),
          reason: _hex(c),
        );
      }
    });

    test('readability labels: easy ≥ 4.5, large text only ≥ 3, else hard', () {
      expect(readability(_black, OnColor.white), Readability.easy);
      expect(readability(_white, OnColor.black), Readability.easy);
      // #767676 on white is 4.54:1, #777777 4.48:1.
      expect(
        readability(const Color(0xFF767676), OnColor.white),
        Readability.easy,
      );
      expect(
        readability(const Color(0xFF777777), OnColor.white),
        Readability.largeOnly,
      );
      // #949494 on white is 3.03:1, #959595 2.99:1.
      expect(
        readability(const Color(0xFF949494), OnColor.white),
        Readability.largeOnly,
      );
      expect(
        readability(const Color(0xFF959595), OnColor.white),
        Readability.hard,
      );
      expect(readability(_white, OnColor.white), Readability.hard);
      expect(
        readability(const Color(0xFFFFFF00), OnColor.white),
        Readability.hard,
      );
      expect(
        readability(AppColors.primaryLight, OnColor.white),
        Readability.hard,
      );
      expect(
        readability(AppColors.primary, OnColor.white),
        Readability.largeOnly,
      );
    });

    test('the background hint: white in light mode, navy in dark mode', () {
      expect(isHardToSee(_white, _light), isTrue);
      expect(isHardToSee(_white, _dark), isFalse);
      expect(isHardToSee(const Color(0xFF000080), _dark), isTrue);
      expect(isHardToSee(const Color(0xFF000080), _light), isFalse);
      expect(isHardToSee(const Color(0xFFFFC107), _light), isTrue);
      expect(
        scaffoldColorFor(_light),
        _build(_light, kDefaultColorTheme).scaffoldBackgroundColor,
      );
      expect(scaffoldColorFor(_dark), Colors.blueGrey.shade900);
    });

    test("defaultOnColor keeps a preset's curated text color", () {
      expect(defaultOnColor(AppColors.primary), OnColor.white);
      expect(recommendedOnColor(AppColors.primary), OnColor.black);
      expect(defaultOnColor(AppColors.primaryLight), OnColor.black);
      expect(defaultOnColor(_black), OnColor.white);
      expect(defaultOnColor(_white), OnColor.black);
      expect(defaultOnColor(const Color(0xFFFFFF00)), OnColor.black);
      expect(defaultOnColor(const Color(0xFF000080)), OnColor.white);
    });
  });

  group("a custom theme's pair is used exactly", () {
    const pairs = [
      (0xFFFFFF00, OnColor.black),
      (0xFFFFFF00, OnColor.white), // hard to read: allowed, warned about
      (0xFF000080, OnColor.white),
      (0xFF000080, OnColor.black),
      (0xFFFFFFFF, OnColor.black),
      (0xFF000000, OnColor.white),
      (0xFF808080, OnColor.white),
      (0xFFE91E63, OnColor.black),
    ];

    test('in light and dark mode, in every style', () {
      for (final (seed, on) in pairs) {
        for (final style in ThemeStyle.values) {
          final theme = _custom(seed, on, style: style);
          for (final b in Brightness.values) {
            final reason =
                '${_hex(Color(seed))} ${on.name} ${style.name} ${b.name}';
            final built = _build(b, theme);
            final f = _fingerprint(built);
            final main = Color(seed);
            expect(built.colorScheme.primary, main, reason: reason);
            expect(built.colorScheme.onPrimary, on.color, reason: reason);
            expect(f['elevated.bg'], _hex(main), reason: reason);
            expect(f['elevated.fg'], _hex(on.color), reason: reason);
            expect(f['fab.bg'], _hex(main), reason: reason);
            expect(f['fab.fg'], _hex(on.color), reason: reason);
            expect(
              f['input.focusedBorder'],
              contains(_hex(main)),
              reason: reason,
            );
            if (b == _light) {
              expect(f['filled.bg'], _hex(main), reason: reason);
              expect(f['filled.fg'], _hex(on.color), reason: reason);
              expect(f['outlined.fg'], _hex(main), reason: reason);
              expect(
                f['outlined.side'],
                startsWith(_hex(main)),
                reason: reason,
              );
              expect(f['bottomNav'], startsWith(_hex(main)), reason: reason);
            } else {
              expect(
                f['textSelection'],
                startsWith(_hex(main)),
                reason: reason,
              );
            }
            final brand = _brandOf(built);
            expect(brand.primary, main, reason: reason);
            expect(brand.onPrimary, on.color, reason: reason);
          }
        }
      }
    });

    test('the deliberate light / dark differences hold for every theme', () {
      final theme = _custom(0xFF6A1B9A, OnColor.white);
      final light = _fingerprint(_build(_light, theme));
      final dark = _fingerprint(_build(_dark, theme));
      for (final key in _legacyLight.keys.where(
        (k) => !k.startsWith('scheme.'),
      )) {
        final colorOnly =
            key.endsWith('.bg') ||
            key.endsWith('.fg') ||
            key.contains('overlay') ||
            key.endsWith('.side') ||
            key.endsWith('focusedBorder') ||
            key == 'bottomNav' ||
            key == 'textSelection' ||
            key == 'primaryColor' ||
            key == 'canvas';
        if (colorOnly) continue;
        expect(light[key], _legacyLight[key], reason: 'light $key');
        expect(dark[key], _legacyDark[key], reason: 'dark $key');
      }
      // Only light mode sets these, as before themes.
      expect(light['filled'], 'set');
      expect(dark['filled'], 'unset');
      expect(dark['outlined'], 'unset');
      expect(dark['bottomNav'], 'null null null null null');
      expect(light['textSelection'], 'null null null');
    });

    test('custom() defaults the text color to the recommended one', () {
      for (final c in _sweep()) {
        final theme = AppColorTheme.custom(name: 'x', seed: c.toARGB32());
        expect(theme.onPrimary, recommendedOnColor(c), reason: _hex(c));
      }
      expect(
        AppColorTheme.custom(
          name: 'x',
          seed: 0xFFFFFF00,
          onPrimary: OnColor.white,
        ).onPrimary,
        OnColor.white,
      );
    });
  });

  group('accent', () {
    test('is the secondary color, its text picked by contrast (≥ 4.5:1)', () {
      for (final accent in _sweep()) {
        final theme = _custom(
          0xFF3949AB,
          OnColor.white,
          accent: accent.toARGB32(),
        );
        for (final b in Brightness.values) {
          final built = _build(b, theme);
          final scheme = built.colorScheme;
          final reason = '${_hex(accent)} ${b.name}';
          expect(scheme.secondary, accent, reason: reason);
          expect(
            scheme.onSecondary,
            recommendedOnColor(accent).color,
            reason: reason,
          );
          expect(
            contrastRatio(scheme.secondary, scheme.onSecondary),
            greaterThanOrEqualTo(kReadableContrast),
            reason: reason,
          );
          final brand = _brandOf(built);
          expect(brand.accent, accent, reason: reason);
          expect(brand.onAccent, scheme.onSecondary, reason: reason);
          // The main pair is untouched.
          expect(scheme.primary, const Color(0xFF3949AB), reason: reason);
        }
      }
    });

    test('without one, Material derives it from the main color', () {
      for (final style in ThemeStyle.values) {
        for (final b in Brightness.values) {
          final theme = _custom(0xFF3949AB, OnColor.white, style: style);
          final scheme = _build(b, theme).colorScheme;
          final derived = ColorScheme.fromSeed(
            seedColor: const Color(0xFF3949AB),
            brightness: b,
            dynamicSchemeVariant: style.variant,
          );
          expect(scheme.secondary, derived.secondary);
          expect(scheme.onSecondary, derived.onSecondary);
          expect(scheme.tertiary, derived.tertiary);
          expect(scheme.primaryContainer, derived.primaryContainer);
          expect(
            contrastRatio(scheme.secondary, scheme.onSecondary),
            greaterThanOrEqualTo(kReadableContrast),
          );
        }
      }
    });

    test('styles map to Material scheme variants', () {
      expect(ThemeStyle.vivid.variant, DynamicSchemeVariant.fidelity);
      expect(ThemeStyle.soft.variant, DynamicSchemeVariant.tonalSpot);
      expect(ThemeStyle.muted.variant, DynamicSchemeVariant.neutral);
    });
  });

  group('AppColorTheme', () {
    test('custom() makes a fresh custom id each time', () {
      final a = AppColorTheme.custom(name: 'A', seed: 0xFF123456);
      final b = AppColorTheme.custom(name: 'B', seed: 0xFF123456);
      for (final t in [a, b]) {
        expect(t.id, startsWith(kCustomColorThemeIdPrefix));
        expect(
          int.tryParse(t.id.substring(kCustomColorThemeIdPrefix.length)),
          isNotNull,
        );
        expect((t.isCustom, t.isPreset, t.isPhone), (true, false, false));
        expect(t.style, ThemeStyle.vivid);
        expect(t.darkPrimary, isNull);
        expect(t.darkOnPrimary, isNull);
      }
      expect(a.id, isNot(b.id));
      expect(a.name, 'A');
      expect(a.seedColor, const Color(0xFF123456));
      expect(a.accentColor, isNull);
    });

    test('Phone colors', () {
      expect(kPhoneColorTheme.id, kPhoneColorThemeId);
      expect(
        (
          kPhoneColorTheme.isPhone,
          kPhoneColorTheme.isPreset,
          kPhoneColorTheme.isCustom,
        ),
        (true, false, false),
      );
    });

    test('without a dark pair, dark mode uses the light pair', () {
      final theme = _custom(0xFF000080, OnColor.black);
      expect(theme.primaryFor(_dark), const Color(0xFF000080));
      expect(theme.onPrimaryFor(_dark), OnColor.black);
      final onlyDarkMain = theme.copyWith(darkPrimary: 0xFFFFFF00);
      expect(
        onlyDarkMain.onPrimaryFor(_dark),
        OnColor.black,
        reason: 'recommended on the dark main color',
      );
      expect(
        onlyDarkMain.copyWith(darkPrimary: 0xFF000040).onPrimaryFor(_dark),
        OnColor.white,
      );
    });

    test('copyWith replaces, keeps, and clears', () {
      final base = _custom(
        0xFF123456,
        OnColor.white,
        accent: 0xFF654321,
      ).copyWith(darkPrimary: 0xFFABCDEF, darkOnPrimary: OnColor.black);
      expect(base.copyWith(), base);
      expect(base.copyWith(seed: 0xFF111111).seed, 0xFF111111);
      expect(base.copyWith(seed: 0xFF111111).accent, 0xFF654321);
      expect(base.copyWith(accent: null).accent, isNull);
      expect(base.copyWith(accent: 0xFF222222).accent, 0xFF222222);
      expect(base.copyWith(name: null).name, isNull);
      expect(base.copyWith(name: 'New').name, 'New');
      expect(base.copyWith(darkPrimary: null).darkPrimary, isNull);
      expect(base.copyWith(darkOnPrimary: null).darkOnPrimary, isNull);
      expect(base.copyWith(style: ThemeStyle.muted).style, ThemeStyle.muted);
      expect(base.copyWith(onPrimary: OnColor.black).onPrimary, OnColor.black);
      expect(base.copyWith(id: 'custom-9').id, 'custom-9');
    });

    test('== and hashCode cover every field', () {
      final a = _custom(0xFF123456, OnColor.white, accent: 0xFF654321);
      final b = _custom(0xFF123456, OnColor.white, accent: 0xFF654321);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      for (final changed in [
        a.copyWith(id: 'custom-2'),
        a.copyWith(name: 'Other'),
        a.copyWith(seed: 0xFF123457),
        a.copyWith(accent: null),
        a.copyWith(style: ThemeStyle.soft),
        a.copyWith(onPrimary: OnColor.black),
        a.copyWith(darkPrimary: 0xFF000000),
        a.copyWith(darkOnPrimary: OnColor.white),
      ]) {
        expect(changed, isNot(a));
      }
    });
  });

  group('JSON', () {
    test('round-trips every preset, Phone colors and custom themes', () {
      final themes = [
        ...kPresetColorThemes,
        kPhoneColorTheme,
        _custom(0xFF123456, OnColor.black),
        _custom(
          0xFF123456,
          OnColor.white,
          accent: 0xFFABCDEF,
          style: ThemeStyle.muted,
        ),
        AppColorTheme.custom(name: 'Ünïcode ✓ বাংলা', seed: 0xFF000080),
      ];
      for (final t in themes) {
        final json = t.toJson();
        expect(AppColorTheme.fromJson(json), t, reason: '$t');
        // Through text, as the settings and the backup store it.
        expect(AppColorTheme.fromJson(jsonDecode(jsonEncode(json))), t);
        expect(AppColorTheme.fromJson(jsonEncode(json)), t);
      }
    });

    test('toJson is plain values and leaves out what is unset', () {
      expect(_custom(0xFF123456, OnColor.black).toJson(), {
        'id': 'custom-1',
        'name': 'Mine',
        'seed': 0xFF123456,
        'style': 'vivid',
        'onPrimary': 'black',
      });
      expect(kDefaultColorTheme.toJson(), {
        'id': 'teal',
        'seed': 0xFF00897B,
        'accent': 0xFF00BFA5,
        'style': 'soft',
        'onPrimary': 'white',
        'darkPrimary': 0xFF4DB6AC,
        'darkOnPrimary': 'black',
      });
    });

    test('not a theme: null, never a throw', () {
      const seed = 0xFF00897B;
      final bad = <Object?>[
        null,
        42,
        true,
        'garbage',
        '{',
        '[]',
        '"teal"',
        <Object?>[],
        <String, Object?>{},
        {'id': 'custom-1'},
        {'seed': seed},
        {'id': '', 'seed': seed},
        {'id': '   ', 'seed': seed},
        {'id': 5, 'seed': seed},
        {'id': null, 'seed': seed},
        {'id': 'custom-1', 'seed': '0xFF00897B'},
        {'id': 'custom-1', 'seed': '#00897B'},
        {'id': 'custom-1', 'seed': 1.5},
        {'id': 'custom-1', 'seed': -1},
        {'id': 'custom-1', 'seed': 0x100000000},
        {'id': 'custom-1', 'seed': double.nan},
        {'id': 'custom-1', 'seed': double.infinity},
        {'id': 'custom-1', 'seed': null},
        {
          'id': 'custom-1',
          'seed': <int>[1],
        },
        _ThrowingMap(),
      ];
      for (final json in bad) {
        expect(AppColorTheme.fromJson(json), isNull, reason: '$json');
      }
    });

    test(
      'a missing or unknown text color falls back to the recommended one',
      () {
        for (final seed in [0xFFFFFF00, 0xFF000080, 0xFF00897B, 0xFF808080]) {
          final recommended = recommendedOnColor(Color(seed));
          for (final on in <Object?>[null, 'blue', '', 'WHITE', 1, true]) {
            final json = {'id': 'custom-1', 'seed': seed, 'onPrimary': on};
            expect(
              AppColorTheme.fromJson(json)!.onPrimary,
              recommended,
              reason: '${_hex(Color(seed))} $on',
            );
          }
          expect(
            AppColorTheme.fromJson({'id': 'custom-1', 'seed': seed})!.onPrimary,
            recommended,
          );
        }
        // A valid choice is kept even when it's hard to read.
        expect(
          AppColorTheme.fromJson({
            'id': 'custom-1',
            'seed': 0xFFFFFF00,
            'onPrimary': 'white',
          })!.onPrimary,
          OnColor.white,
        );
      },
    );

    test('optional fields degrade instead of failing', () {
      AppColorTheme parse(Map<String, Object?> extra) => AppColorTheme.fromJson(
        {'id': 'custom-1', 'seed': 0xFF123456, 'onPrimary': 'white', ...extra},
      )!;

      for (final style in <Object?>[null, 'bold', 3, 'Vivid']) {
        expect(
          parse({'style': style}).style,
          ThemeStyle.vivid,
          reason: '$style',
        );
      }
      expect(parse({'style': 'muted'}).style, ThemeStyle.muted);
      for (final accent in <Object?>['red', -5, 1.5, 0x100000000, true]) {
        expect(parse({'accent': accent}).accent, isNull, reason: '$accent');
      }
      expect(parse({'accent': 0xFF00BFA5}).accent, 0xFF00BFA5);
      for (final name in <Object?>[
        null,
        '',
        '   ',
        7,
        <String>['x'],
      ]) {
        expect(parse({'name': name}).name, isNull, reason: '$name');
      }
      expect(parse({'name': '  Shop blue  '}).name, 'Shop blue');
      expect(parse({'darkPrimary': 'x'}).darkPrimary, isNull);
      expect(parse({'darkOnPrimary': 'grey'}).darkOnPrimary, isNull);
      expect(parse({'darkOnPrimary': 'black'}).darkOnPrimary, OnColor.black);
      // Colors are made opaque; integral doubles are integers.
      expect(parse({'accent': 0x0000BFA5}).accent, 0xFF00BFA5);
      expect(
        AppColorTheme.fromJson({'id': 'custom-1', 'seed': 0x8000897B})!.seed,
        0xFF00897B,
      );
      expect(
        AppColorTheme.fromJson({'id': 'custom-1', 'seed': 4278225275.0})!.seed,
        0xFF00897B,
      );
      // Unknown keys are ignored; any map works.
      expect(parse({'future': 1}), parse({}));
      expect(
        AppColorTheme.fromJson(<dynamic, dynamic>{
          'id': 'custom-1',
          'seed': 0xFF123456,
          'onPrimary': 'white',
          7: 'x',
        }),
        parse({}),
      );
    });
  });

  group('custom theme list', () {
    Map<String, Object?> json(String id, {String name = 'T'}) => {
      'id': id,
      'name': name,
      'seed': 0xFF123456,
      'onPrimary': 'white',
    };

    test('garbage is an empty list', () {
      for (final raw in <Object?>[
        null,
        '',
        '   ',
        'not json',
        '{',
        '{}',
        '"x"',
        '42',
        42,
        true,
        <String, Object?>{},
        <Object?>[],
        '[]',
      ]) {
        expect(decodeCustomColorThemes(raw), isEmpty, reason: '$raw');
      }
    });

    test(
      'keeps only valid custom themes, the first of each id, at most 12',
      () {
        final raw = [
          1,
          'x',
          null,
          <String, Object?>{},
          json('teal'),
          json('phone'),
          json('blue'),
          json('custom-'),
          json('custom-1', name: 'first'),
          json('custom-1', name: 'duplicate'),
          {'id': 'custom-2', 'seed': 'bad'},
          for (var i = 3; i < 20; i++) json('custom-$i'),
        ];
        final themes = decodeCustomColorThemes(raw);
        expect(themes, hasLength(kMaxCustomColorThemes));
        expect(themes.first.name, 'first');
        expect(themes.map((t) => t.id), [
          'custom-1',
          for (var i = 3; i < 14; i++) 'custom-$i',
        ]);
        expect(themes.every((t) => t.isCustom), isTrue);
        // The same from the JSON text.
        expect(decodeCustomColorThemes(jsonEncode(raw)), themes);
      },
    );

    test('round-trips, and the result can be added to', () {
      final themes = [
        _custom(0xFF123456, OnColor.black),
        AppColorTheme.custom(name: 'Two', seed: 0xFFABCDEF, accent: 0xFF00FF00),
      ];
      final text = encodeCustomColorThemes(themes);
      expect(jsonDecode(text), isA<List<Object?>>());
      final decoded = decodeCustomColorThemes(text);
      expect(decoded, themes);
      decoded.add(_custom(0xFF000000, OnColor.white));
      expect(decoded, hasLength(3));
      expect(encodeCustomColorThemes(const []), '[]');
    });
  });

  group('resolveColorTheme', () {
    test('Phone, presets, customs; anything else is Teal', () {
      final mine = _custom(0xFF123456, OnColor.white);
      expect(resolveColorTheme('phone', [mine]), kPhoneColorTheme);
      for (final p in kPresetColorThemes) {
        expect(identical(resolveColorTheme(p.id, [mine]), p), isTrue);
      }
      expect(resolveColorTheme(mine.id, [mine]), mine);
      for (final id in [null, '', 'nonsense', 'custom-404', 'Teal']) {
        expect(resolveColorTheme(id, [mine]), kDefaultColorTheme, reason: id);
      }
      expect(resolveColorTheme(mine.id, const []), kDefaultColorTheme);
    });
  });

  group('memoization', () {
    test('the same colors give the identical ThemeData', () {
      final a = _custom(0xFF123456, OnColor.white);
      expect(identical(_build(_light, a), _build(_light, a)), isTrue);
      // Id and name don't matter, only the colors.
      final renamed = a.copyWith(id: 'custom-99', name: 'Other name');
      expect(identical(_build(_dark, a), _build(_dark, renamed)), isTrue);
      expect(identical(_build(_light, a), _build(_dark, a)), isFalse);
      expect(
        identical(
          _build(_light, a),
          _build(_light, a.copyWith(onPrimary: OnColor.black)),
        ),
        isFalse,
      );
      expect(
        identical(
          _build(_light, a),
          _build(_light, a.copyWith(seed: 0xFF123457)),
        ),
        isFalse,
      );
    });

    test('a long run of other themes is fine (the cache is bounded)', () {
      final teal = _build(_light, kDefaultColorTheme);
      for (var i = 0; i < 80; i++) {
        _build(_light, _custom(0xFF000000 + i * 0x020304, OnColor.white));
      }
      final again = _build(_light, kDefaultColorTheme);
      expect(_fingerprint(again), _fingerprint(teal));
      expect(identical(_build(_light, kDefaultColorTheme), again), isTrue);
    });

    test('Phone colors: the system scheme is the color scheme', () {
      final light = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final dark = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: _dark,
      );
      for (final scheme in [light, dark]) {
        final b = scheme.brightness;
        final theme = AppTheme.build(
          b,
          kPhoneColorTheme,
          dynamicScheme: scheme,
        );
        expect(theme.colorScheme, scheme);
        expect(theme.brightness, b);
        final f = _fingerprint(theme);
        expect(f['elevated.bg'], _hex(scheme.primary));
        expect(f['elevated.fg'], _hex(scheme.onPrimary));
        expect(f['fab.fg'], _hex(scheme.onPrimary));
        final brand = _brandOf(theme);
        expect(brand.primary, scheme.primary);
        expect(brand.onPrimary, scheme.onPrimary);
        expect(brand.accent, scheme.secondary);
        expect(brand.onAccent, scheme.onSecondary);
        // An equal scheme (a new instance) gets the identical theme.
        final equal = ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: b,
        );
        expect(identical(equal, scheme), isFalse);
        expect(
          identical(
            AppTheme.build(b, kPhoneColorTheme, dynamicScheme: equal),
            theme,
          ),
          isTrue,
        );
        // The theme's own colors don't matter then.
        expect(
          identical(
            AppTheme.build(b, _preset('red'), dynamicScheme: scheme),
            theme,
          ),
          isTrue,
        );
        expect(identical(_build(b, kPhoneColorTheme), theme), isFalse);
      }
    });
  });

  group('BrandColors', () {
    test('teal is the old AppColors constants', () {
      const teal = BrandColors.teal;
      expect(teal.primary, AppColors.primary);
      expect(teal.primary, const Color(0xFF00897B));
      expect(teal.primaryDark, AppColors.primaryDark);
      expect(teal.primaryLight, AppColors.primaryLight);
      expect(teal.accent, AppColors.accent);
      expect(teal.onPrimary, _white);
      expect(teal.onAccent, recommendedOnColor(AppColors.accent).color);
      expect(teal.gradient, AppColors.dashboardGradient);
      expect(
        BrandColors.fromPair(primary: AppColors.primary, onPrimary: _white),
        teal,
      );
    });

    test('derived shades keep the text readable', () {
      for (final c in _sweep()) {
        for (final on in OnColor.values) {
          final brand = BrandColors.fromPair(primary: c, onPrimary: on.color);
          final reason = '${_hex(c)} ${on.name}';
          final base = contrastRatio(c, on.color);
          expect(brand.primary, c, reason: reason);
          expect(brand.onPrimary, on.color, reason: reason);
          expect(brand.gradient.colors.first, c, reason: reason);
          // Along the gradient the text only gains contrast.
          expect(
            contrastRatio(brand.gradient.colors.last, on.color),
            greaterThanOrEqualTo(base - 1e-9),
            reason: reason,
          );
          expect(
            contrastRatio(brand.primaryDark, on.color),
            greaterThanOrEqualTo(
              (base < kReadableContrast ? base : kReadableContrast) - 1e-9,
            ),
            reason: reason,
          );
          expect(
            brand.primaryDark.computeLuminance(),
            lessThanOrEqualTo(c.computeLuminance() + 1e-9),
            reason: reason,
          );
          expect(
            brand.primaryLight.computeLuminance(),
            greaterThanOrEqualTo(c.computeLuminance() - 1e-9),
            reason: reason,
          );
          expect(
            contrastRatio(brand.accent, brand.onAccent),
            greaterThanOrEqualTo(kReadableContrast),
            reason: reason,
          );
        }
      }
    });

    test('lerp, copyWith, ==', () {
      const a = BrandColors.teal;
      final b = BrandColors.fromPair(
        primary: const Color(0xFFFFFF00),
        onPrimary: _black,
      );
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      expect(a.lerp(null, 0.5), a);
      final mid = a.lerp(b, 0.5);
      expect(mid.primary, Color.lerp(a.primary, b.primary, 0.5));
      expect(mid.gradient, LinearGradient.lerp(a.gradient, b.gradient, 0.5));
      expect(a.copyWith(), a);
      expect(a.copyWith(primary: _black).primary, _black);
      expect(a.copyWith(primary: _black), isNot(a));
      expect(a.copyWith(primary: _black).hashCode, isNot(a.hashCode));
    });

    testWidgets('context.brand reads the theme, teal without one', (
      tester,
    ) async {
      BrandColors? seen;
      Widget probe(ThemeData theme) => Theme(
        data: theme,
        child: Builder(
          builder: (context) {
            seen = context.brand;
            return const SizedBox();
          },
        ),
      );
      final yellow = _custom(0xFFFFFF00, OnColor.black);
      await tester.pumpWidget(probe(_build(_light, yellow)));
      expect(seen!.primary, const Color(0xFFFFFF00));
      expect(seen!.onPrimary, _black);
      await tester.pumpWidget(probe(ThemeData()));
      expect(seen, BrandColors.teal);
    });
  });

  group('DocumentBrand', () {
    tearDown(DocumentBrand.reset);

    test('teal with white text by default', () {
      expect(DocumentBrand.color, AppColors.primary);
      expect(DocumentBrand.onColor, _white);
      expect(DocumentBrand.textColor, AppColors.primary);
    });

    test('set, then reset', () {
      DocumentBrand.set(const Color(0xFFFFFF00));
      expect(DocumentBrand.color, const Color(0xFFFFFF00));
      expect(DocumentBrand.onColor, _black, reason: 'by contrast');
      // Yellow text on the white page would be 1.07:1: a darker shade.
      expect(
        contrastRatio(DocumentBrand.textColor, _white),
        greaterThanOrEqualTo(DocumentBrand.minTextContrast),
      );

      DocumentBrand.set(const Color(0xFFFFFF00), onColor: _white);
      expect(DocumentBrand.onColor, _white, reason: "the theme's own choice");

      DocumentBrand.set(const Color(0xFF000080));
      expect(DocumentBrand.onColor, _white);

      // Teal's documents keep their white text, and their teal text.
      DocumentBrand.set(AppColors.primary);
      expect(DocumentBrand.onColor, _white);
      expect(DocumentBrand.textColor, AppColors.primary);

      DocumentBrand.set(const Color(0xFFFFFF00));
      DocumentBrand.reset();
      expect(DocumentBrand.color, AppColors.primary);
      expect(DocumentBrand.onColor, _white);
      expect(DocumentBrand.textColor, AppColors.primary);
    });
  });

  group('a loading AppButton', () {
    testWidgets("draws its spinner in the disabled button's text color", (
      tester,
    ) async {
      // A loading button is disabled. Its spinner was white, all but
      // invisible on the pale grey fill of a disabled filled button
      // (1.3:1) and on an unfilled one: now Material 3's disabled text
      // color, as the label would be, in every variant and theme (a
      // deliberate change from Teal's white).
      for (final theme in [
        AppTheme.lightTheme,
        AppTheme.darkTheme,
        _build(_light, _custom(0xFFFFEB3B, OnColor.black)),
      ]) {
        for (final variant in AppButtonVariant.values) {
          final where = '${theme.brightness.name}, ${variant.name}';
          await tester.pumpWidget(
            MaterialApp(
              // A new app each time: an updated one would cross-fade from
              // the last theme.
              key: UniqueKey(),
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: AppButton(
                    label: 'Save',
                    variant: variant,
                    isLoading: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          );
          final spinner = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          // Material stores the alpha in 8 bits (97 / 255).
          expect(
            spinner.color?.toARGB32(),
            theme.colorScheme.onSurface.withValues(alpha: 0.38).toARGB32(),
            reason: where,
          );
        }
      }
    });
  });
}

/// A map whose every read throws: `fromJson` must still return null.
class _ThrowingMap extends MapBase<String, Object?> {
  @override
  Object? operator [](Object? key) => throw StateError('read');

  @override
  void operator []=(String key, Object? value) {}

  @override
  void clear() {}

  @override
  Iterable<String> get keys => const [];

  @override
  Object? remove(Object? key) => null;
}

String _hex(Color? c) => c == null
    ? 'null'
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _n(double? v) => v == null ? 'null' : v.toStringAsFixed(2);

String _text(TextStyle? s) => s == null
    ? 'null'
    : '${_hex(s.color)} ${_n(s.fontSize)} w${s.fontWeight?.value} '
          '${_n(s.letterSpacing)} ${s.fontFamily}';

String _side(BorderSide? b) =>
    b == null ? 'null' : '${_hex(b.color)} ${_n(b.width)} ${b.style.name}';

String _shape(ShapeBorder? s) => switch (s) {
  null => 'null',
  RoundedRectangleBorder(:final borderRadius, :final side) =>
    'rrect ${_n(borderRadius.resolve(TextDirection.ltr).topLeft.x)} ${_side(side)}',
  OutlineInputBorder(:final borderRadius, :final borderSide) =>
    'outline ${_n(borderRadius.topLeft.x)} ${_side(borderSide)}',
  _ => '${s.runtimeType}',
};

String _pad(EdgeInsetsGeometry? p) {
  if (p == null) return 'null';
  final e = p.resolve(TextDirection.ltr);
  return '${_n(e.left)} ${_n(e.top)} ${_n(e.right)} ${_n(e.bottom)}';
}

void _button(Map<String, String> m, String name, ButtonStyle? s) {
  m[name] = s == null ? 'unset' : 'set';
  if (s == null) return;
  const enabled = <WidgetState>{};
  const disabled = {WidgetState.disabled};
  m['$name.bg'] = _hex(s.backgroundColor?.resolve(enabled));
  m['$name.fg'] = _hex(s.foregroundColor?.resolve(enabled));
  m['$name.bg.disabled'] = _hex(s.backgroundColor?.resolve(disabled));
  m['$name.fg.disabled'] = _hex(s.foregroundColor?.resolve(disabled));
  for (final state in [
    WidgetState.pressed,
    WidgetState.hovered,
    WidgetState.focused,
  ]) {
    m['$name.overlay.${state.name}'] = _hex(s.overlayColor?.resolve({state}));
  }
  m['$name.side'] = _side(s.side?.resolve(enabled));
  m['$name.geometry'] =
      '${_shape(s.shape?.resolve(enabled))} | '
      '${_pad(s.padding?.resolve(enabled))} | '
      'elevation ${_n(s.elevation?.resolve(enabled))}/'
      '${_n(s.elevation?.resolve({WidgetState.pressed}))}';
  m['$name.text'] = _text(s.textStyle?.resolve(enabled));
}

/// What a [ThemeData] gives the app, as strings: every color scheme role and
/// every component theme the app sets (colors, shapes, sizes).
Map<String, String> _fingerprint(ThemeData t) {
  final cs = t.colorScheme;
  final m = <String, String>{
    'useMaterial3': '${t.useMaterial3}',
    'brightness': t.brightness.name,
    'fontFamily': '${t.textTheme.bodyMedium?.fontFamily}',
  };
  final roles = <String, Color>{
    'primary': cs.primary,
    'onPrimary': cs.onPrimary,
    'primaryContainer': cs.primaryContainer,
    'onPrimaryContainer': cs.onPrimaryContainer,
    'primaryFixed': cs.primaryFixed,
    'primaryFixedDim': cs.primaryFixedDim,
    'onPrimaryFixed': cs.onPrimaryFixed,
    'onPrimaryFixedVariant': cs.onPrimaryFixedVariant,
    'secondary': cs.secondary,
    'onSecondary': cs.onSecondary,
    'secondaryContainer': cs.secondaryContainer,
    'onSecondaryContainer': cs.onSecondaryContainer,
    'secondaryFixed': cs.secondaryFixed,
    'secondaryFixedDim': cs.secondaryFixedDim,
    'onSecondaryFixed': cs.onSecondaryFixed,
    'onSecondaryFixedVariant': cs.onSecondaryFixedVariant,
    'tertiary': cs.tertiary,
    'onTertiary': cs.onTertiary,
    'tertiaryContainer': cs.tertiaryContainer,
    'onTertiaryContainer': cs.onTertiaryContainer,
    'tertiaryFixed': cs.tertiaryFixed,
    'tertiaryFixedDim': cs.tertiaryFixedDim,
    'onTertiaryFixed': cs.onTertiaryFixed,
    'onTertiaryFixedVariant': cs.onTertiaryFixedVariant,
    'error': cs.error,
    'onError': cs.onError,
    'errorContainer': cs.errorContainer,
    'onErrorContainer': cs.onErrorContainer,
    'surface': cs.surface,
    'onSurface': cs.onSurface,
    'surfaceDim': cs.surfaceDim,
    'surfaceBright': cs.surfaceBright,
    'surfaceContainerLowest': cs.surfaceContainerLowest,
    'surfaceContainerLow': cs.surfaceContainerLow,
    'surfaceContainer': cs.surfaceContainer,
    'surfaceContainerHigh': cs.surfaceContainerHigh,
    'surfaceContainerHighest': cs.surfaceContainerHighest,
    'onSurfaceVariant': cs.onSurfaceVariant,
    'outline': cs.outline,
    'outlineVariant': cs.outlineVariant,
    'shadow': cs.shadow,
    'scrim': cs.scrim,
    'inverseSurface': cs.inverseSurface,
    'onInverseSurface': cs.onInverseSurface,
    'inversePrimary': cs.inversePrimary,
    'surfaceTint': cs.surfaceTint,
  };
  roles.forEach((role, color) => m['scheme.$role'] = _hex(color));
  m['scaffold'] = _hex(t.scaffoldBackgroundColor);
  m['canvas'] = _hex(t.canvasColor);
  m['primaryColor'] = _hex(t.primaryColor);

  final ab = t.appBarTheme;
  final so = ab.systemOverlayStyle;
  m['appBar.colors'] =
      '${_hex(ab.backgroundColor)} ${_hex(ab.foregroundColor)}';
  m['appBar.title'] = _text(ab.titleTextStyle);
  m['appBar.statusBar'] = so == null
      ? 'null'
      : '${_hex(so.statusBarColor)} ${so.statusBarIconBrightness?.name}';
  m['appBar.geometry'] =
      'elevation ${_n(ab.elevation)}/${_n(ab.scrolledUnderElevation)} '
      'centerTitle ${ab.centerTitle}';

  final card = t.cardTheme;
  m['card.colors'] =
      '${_hex(card.color)} tint ${_hex(card.surfaceTintColor)} '
      'shadow ${_hex(card.shadowColor)}';
  m['card.geometry'] = '${_shape(card.shape)} elevation ${_n(card.elevation)}';

  _button(m, 'elevated', t.elevatedButtonTheme.style);
  _button(m, 'filled', t.filledButtonTheme.style);
  _button(m, 'outlined', t.outlinedButtonTheme.style);
  _button(m, 'textButton', t.textButtonTheme.style);

  final input = t.inputDecorationTheme;
  m['input.fill'] = '${input.filled} ${_hex(input.fillColor)}';
  m['input.border'] = _shape(input.border);
  m['input.enabledBorder'] = _shape(input.enabledBorder);
  m['input.focusedBorder'] = _shape(input.focusedBorder);
  m['input.errorBorder'] = _shape(input.errorBorder);
  m['input.padding'] = _pad(input.contentPadding);
  m['input.label'] = _text(input.labelStyle);
  m['input.hint'] = _text(input.hintStyle);
  m['input.icons'] =
      '${_hex(input.prefixIconColor)} ${_hex(input.suffixIconColor)}';

  m['chip.shape'] = _shape(t.chipTheme.shape);
  m['divider'] =
      '${_hex(t.dividerTheme.color)} ${_n(t.dividerTheme.thickness)}';
  m['listTile.padding'] = _pad(t.listTileTheme.contentPadding);

  final fab = t.floatingActionButtonTheme;
  m['fab.bg'] = _hex(fab.backgroundColor);
  m['fab.fg'] = _hex(fab.foregroundColor);
  m['fab.geometry'] = '${_shape(fab.shape)} elevation ${_n(fab.elevation)}';

  m['snackBar'] =
      '${t.snackBarTheme.behavior?.name} ${_shape(t.snackBarTheme.shape)}';

  final nav = t.bottomNavigationBarTheme;
  m['bottomNav'] =
      '${_hex(nav.selectedItemColor)} ${_hex(nav.unselectedItemColor)} '
      '${nav.showUnselectedLabels} ${nav.type?.name} ${_n(nav.elevation)}';

  final sel = t.textSelectionTheme;
  m['textSelection'] =
      '${_hex(sel.cursorColor)} ${_hex(sel.selectionColor)} '
      '${_hex(sel.selectionHandleColor)}';
  m['actionIcons'] = t.actionIconTheme == null ? 'unset' : 'set';
  return m;
}

/// The fixed teal light theme before color themes (`AppTheme.lightTheme`,
/// captured with [_fingerprint] from that code), but for two later changes,
/// in both modes. The app bar title and the button text name the app's font
/// (Roboto here, on Android; they named none, and iOS drew them in San
/// Francisco). There is no status bar style: no AppBar reaches the status
/// bar under the shell's SafeArea, and the app frame sets it
/// (`system_ui_style.dart`).
const _legacyLight = <String, String>{
  'useMaterial3': 'true',
  'brightness': 'light',
  'fontFamily': 'Roboto',
  'scheme.primary': '0xFF00897B',
  'scheme.onPrimary': '0xFFFFFFFF',
  'scheme.primaryContainer': '0xFF9EF2E3',
  'scheme.onPrimaryContainer': '0xFF005048',
  'scheme.primaryFixed': '0xFF9EF2E3',
  'scheme.primaryFixedDim': '0xFF82D5C7',
  'scheme.onPrimaryFixed': '0xFF00201C',
  'scheme.onPrimaryFixedVariant': '0xFF005048',
  'scheme.secondary': '0xFF00BFA5',
  'scheme.onSecondary': '0xFFFFFFFF',
  'scheme.secondaryContainer': '0xFFCCE8E2',
  'scheme.onSecondaryContainer': '0xFF334B47',
  'scheme.secondaryFixed': '0xFFCCE8E2',
  'scheme.secondaryFixedDim': '0xFFB1CCC6',
  'scheme.onSecondaryFixed': '0xFF06201C',
  'scheme.onSecondaryFixedVariant': '0xFF334B47',
  'scheme.tertiary': '0xFF00BFA5',
  'scheme.onTertiary': '0xFFFFFFFF',
  'scheme.tertiaryContainer': '0xFFCBE6FF',
  'scheme.onTertiaryContainer': '0xFF2D4A60',
  'scheme.tertiaryFixed': '0xFFCBE6FF',
  'scheme.tertiaryFixedDim': '0xFFADCAE5',
  'scheme.onTertiaryFixed': '0xFF001E31',
  'scheme.onTertiaryFixedVariant': '0xFF2D4A60',
  'scheme.error': '0xFFBA1A1A',
  'scheme.onError': '0xFFFFFFFF',
  'scheme.errorContainer': '0xFFFFDAD6',
  'scheme.onErrorContainer': '0xFF93000A',
  'scheme.surface': '0xFFF4FBF8',
  'scheme.onSurface': '0xFF161D1B',
  'scheme.surfaceDim': '0xFFD5DBD9',
  'scheme.surfaceBright': '0xFFF4FBF8',
  'scheme.surfaceContainerLowest': '0xFFFFFFFF',
  'scheme.surfaceContainerLow': '0xFFEFF5F2',
  'scheme.surfaceContainer': '0xFFE9EFEC',
  'scheme.surfaceContainerHigh': '0xFFE3EAE7',
  'scheme.surfaceContainerHighest': '0xFFDDE4E1',
  'scheme.onSurfaceVariant': '0xFF3F4946',
  'scheme.outline': '0xFF6F7976',
  'scheme.outlineVariant': '0xFFBEC9C5',
  'scheme.shadow': '0xFF000000',
  'scheme.scrim': '0xFF000000',
  'scheme.inverseSurface': '0xFF2B3230',
  'scheme.onInverseSurface': '0xFFECF2EF',
  'scheme.inversePrimary': '0xFF82D5C7',
  'scheme.surfaceTint': '0xFF006B5F',
  'scaffold': '0xFFF8F9FA',
  'canvas': '0xFFF4FBF8',
  'primaryColor': '0xFF00897B',
  'appBar.colors': '0xFFFFFFFF 0xFF1A1A2E',
  'appBar.title': '0xFF1A1A2E 20.00 w700 -0.30 Roboto',
  'appBar.statusBar': 'null',
  'appBar.geometry': 'elevation 0.00/1.00 centerTitle false',
  'card.colors': '0xFFFFFFFF tint 0x00000000 shadow 0x0F000000',
  'card.geometry': 'rrect 12.00 0xFF000000 0.00 none elevation 0.00',
  'elevated': 'set',
  'elevated.bg': '0xFF00897B',
  'elevated.fg': '0xFFFFFFFF',
  'elevated.bg.disabled': 'null',
  'elevated.fg.disabled': 'null',
  'elevated.overlay.pressed': '0x1AFFFFFF',
  'elevated.overlay.hovered': '0x14FFFFFF',
  'elevated.overlay.focused': '0x1AFFFFFF',
  'elevated.side': 'null',
  'elevated.geometry':
      'rrect 12.00 0xFF000000 0.00 none | 24.00 14.00 24.00 14.00 | elevation 0.00/6.00',
  'elevated.text': 'null 15.00 w600 0.20 Roboto',
  'filled': 'set',
  'filled.bg': '0xFF00897B',
  'filled.fg': '0xFFFFFFFF',
  'filled.bg.disabled': 'null',
  'filled.fg.disabled': 'null',
  'filled.overlay.pressed': '0x1AFFFFFF',
  'filled.overlay.hovered': '0x14FFFFFF',
  'filled.overlay.focused': '0x1AFFFFFF',
  'filled.side': 'null',
  'filled.geometry':
      'rrect 12.00 0xFF000000 0.00 none | 24.00 14.00 24.00 14.00 | elevation null/null',
  'filled.text': 'null 15.00 w600 null Roboto',
  'outlined': 'set',
  'outlined.bg': 'null',
  'outlined.fg': '0xFF00897B',
  'outlined.bg.disabled': 'null',
  'outlined.fg.disabled': 'null',
  'outlined.overlay.pressed': '0x1A00897B',
  'outlined.overlay.hovered': '0x1400897B',
  'outlined.overlay.focused': '0x1A00897B',
  'outlined.side': '0xFF00897B 1.00 solid',
  'outlined.geometry':
      'rrect 12.00 0xFF000000 0.00 none | 24.00 14.00 24.00 14.00 | elevation null/null',
  'outlined.text': 'null 15.00 w600 null Roboto',
  'textButton': 'unset',
  'input.fill': 'true 0xFFF8F9FA',
  'input.border': 'outline 12.00 0xFF000000 0.00 none',
  'input.enabledBorder': 'outline 12.00 0xFFE5E7EB 1.00 solid',
  'input.focusedBorder': 'outline 12.00 0xFF00897B 2.00 solid',
  'input.errorBorder': 'outline 12.00 0xFFF44336 1.00 solid',
  'input.padding': '16.00 14.00 16.00 14.00',
  'input.label': '0xFF6B7280 null wnull null null',
  'input.hint': '0xFFD1D5DB null wnull null null',
  'input.icons': 'null null',
  'chip.shape': 'rrect 8.00 0xFF000000 0.00 none',
  'divider': '0xFFF3F4F6 1.00',
  'listTile.padding': '16.00 4.00 16.00 4.00',
  'fab.bg': '0xFF00897B',
  'fab.fg': '0xFFFFFFFF',
  'fab.geometry': 'rrect 16.00 0xFF000000 0.00 none elevation 2.00',
  'snackBar': 'floating rrect 10.00 0xFF000000 0.00 none',
  'bottomNav': '0xFF00897B 0xFF9CA3AF true fixed 8.00',
  'textSelection': 'null null null',
  'actionIcons': 'set',
};

/// The fixed teal dark theme before color themes (`AppTheme.darkTheme`), but
/// for the same two later changes as [_legacyLight].
const _legacyDark = <String, String>{
  'useMaterial3': 'true',
  'brightness': 'dark',
  'fontFamily': 'Roboto',
  'scheme.primary': '0xFF4DB6AC',
  'scheme.onPrimary': '0xFF003731',
  'scheme.primaryContainer': '0xFF005048',
  'scheme.onPrimaryContainer': '0xFF9EF2E3',
  'scheme.primaryFixed': '0xFF9EF2E3',
  'scheme.primaryFixedDim': '0xFF82D5C7',
  'scheme.onPrimaryFixed': '0xFF00201C',
  'scheme.onPrimaryFixedVariant': '0xFF005048',
  'scheme.secondary': '0xFF00BFA5',
  'scheme.onSecondary': '0xFF1C3531',
  'scheme.secondaryContainer': '0xFF334B47',
  'scheme.onSecondaryContainer': '0xFFCCE8E2',
  'scheme.secondaryFixed': '0xFFCCE8E2',
  'scheme.secondaryFixedDim': '0xFFB1CCC6',
  'scheme.onSecondaryFixed': '0xFF06201C',
  'scheme.onSecondaryFixedVariant': '0xFF334B47',
  'scheme.tertiary': '0xFFADCAE5',
  'scheme.onTertiary': '0xFF143349',
  'scheme.tertiaryContainer': '0xFF2D4A60',
  'scheme.onTertiaryContainer': '0xFFCBE6FF',
  'scheme.tertiaryFixed': '0xFFCBE6FF',
  'scheme.tertiaryFixedDim': '0xFFADCAE5',
  'scheme.onTertiaryFixed': '0xFF001E31',
  'scheme.onTertiaryFixedVariant': '0xFF2D4A60',
  'scheme.error': '0xFFFFB4AB',
  'scheme.onError': '0xFF690005',
  'scheme.errorContainer': '0xFF93000A',
  'scheme.onErrorContainer': '0xFFFFDAD6',
  'scheme.surface': '0xFF0E1513',
  'scheme.onSurface': '0xFFDDE4E1',
  'scheme.surfaceDim': '0xFF0E1513',
  'scheme.surfaceBright': '0xFF343B39',
  'scheme.surfaceContainerLowest': '0xFF090F0E',
  'scheme.surfaceContainerLow': '0xFF161D1B',
  'scheme.surfaceContainer': '0xFF1A211F',
  'scheme.surfaceContainerHigh': '0xFF252B2A',
  'scheme.surfaceContainerHighest': '0xFF303634',
  'scheme.onSurfaceVariant': '0xFFBEC9C5',
  'scheme.outline': '0xFF899390',
  'scheme.outlineVariant': '0xFF3F4946',
  'scheme.shadow': '0xFF000000',
  'scheme.scrim': '0xFF000000',
  'scheme.inverseSurface': '0xFFDDE4E1',
  'scheme.onInverseSurface': '0xFF2B3230',
  'scheme.inversePrimary': '0xFF006B5F',
  'scheme.surfaceTint': '0xFF82D5C7',
  'scaffold': '0xFF263238',
  'canvas': '0xFF0E1513',
  'primaryColor': '0xFF0E1513',
  'appBar.colors': '0xFF1C1C2E 0xFFFFFFFF',
  'appBar.title': '0xFFFFFFFF 20.00 w700 -0.30 Roboto',
  'appBar.statusBar': 'null',
  'appBar.geometry': 'elevation 0.00/1.00 centerTitle false',
  'card.colors': '0xFF252535 tint 0x00000000 shadow null',
  'card.geometry': 'rrect 12.00 0xFF000000 0.00 none elevation 0.00',
  'elevated': 'set',
  'elevated.bg': '0xFF4DB6AC',
  'elevated.fg': '0xFFFFFFFF',
  'elevated.bg.disabled': 'null',
  'elevated.fg.disabled': 'null',
  'elevated.overlay.pressed': '0x1AFFFFFF',
  'elevated.overlay.hovered': '0x14FFFFFF',
  'elevated.overlay.focused': '0x1AFFFFFF',
  'elevated.side': 'null',
  'elevated.geometry':
      'rrect 12.00 0xFF000000 0.00 none | 24.00 14.00 24.00 14.00 | elevation 0.00/6.00',
  'elevated.text': 'null 15.00 w600 null Roboto',
  'filled': 'unset',
  'outlined': 'unset',
  'textButton': 'unset',
  'input.fill': 'true 0xFF37474F',
  'input.border': 'outline 12.00 0xFF000000 0.00 none',
  'input.enabledBorder': 'outline 12.00 0xFF455A64 1.00 solid',
  'input.focusedBorder': 'outline 12.00 0xFF4DB6AC 2.00 solid',
  'input.errorBorder': 'outline 12.00 0xFFFF5252 1.00 solid',
  'input.padding': '16.00 14.00 16.00 14.00',
  'input.label': '0xFFB0BEC5 null wnull null null',
  'input.hint': '0xFF78909C null wnull null null',
  'input.icons': '0xFF90A4AE 0xFF90A4AE',
  'chip.shape': 'null',
  'divider': 'null null',
  'listTile.padding': 'null',
  'fab.bg': '0xFF4DB6AC',
  'fab.fg': '0xFFFFFFFF',
  'fab.geometry': 'rrect 16.00 0xFF000000 0.00 none elevation 2.00',
  'snackBar': 'floating rrect 10.00 0xFF000000 0.00 none',
  'bottomNav': 'null null null null null',
  'textSelection': '0xFF4DB6AC 0x4D4DB6AC 0xFF4DB6AC',
  'actionIcons': 'set',
};
