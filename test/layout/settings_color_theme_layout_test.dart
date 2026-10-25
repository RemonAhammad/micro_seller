import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_color_theme.dart';
import 'package:micro_seller/core/theme/dynamic_color_support.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/features/settings/presentation/color_theme_screen.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/presentation/widgets/color_theme_editor.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';

// Layout of Settings → Color theme and its editor from the narrowest layout
// (320 dp) to a large phone font (150%), left to right and right to left:
// every preset, twelve saved themes with 30-character names, Phone colors,
// the editor with both color pickers, and Settings' Color theme row.

const _eps = 0.01;

/// Languages in Latin script, which the test draws in Roboto's real widths:
/// where a broken word is a layout fault and not the test font's.
const _latin = {'en', 'es', 'fr', 'pt', 'tr', 'id', 'vi', 'ms'};

/// Latin languages with long words, and a right-to-left one.
const _langs = ['en', 'fr', 'ms', 'ar'];

/// Twelve saved themes (the most there can be), each name 30 characters.
final _customs = [
  for (var i = 0; i < kMaxCustomColorThemes; i++)
    AppColorTheme(
      id: 'custom-${i + 1}',
      name: 'Evening Market Ocean Breeze ${(i + 1).toString().padLeft(2, '0')}',
      seed: [0xFF1565C0, 0xFFFFEB3B, 0xFF000000, 0xFFFFFFFF][i % 4],
      accent: i.isEven ? 0xFFFF6F00 : null,
      onPrimary: i % 4 == 1 || i % 4 == 3 ? OnColor.black : OnColor.white,
    ),
];

/// [_customs] saved, the first of them selected.
Map<String, Object> get _prefs => {
  Settings.keyCustomColorThemes: encodeCustomColorThemes(_customs),
  Settings.keyColorThemeId: _customs.first.id,
};

/// Drive without Google: signed out.
class _FakeDrive extends DriveService {
  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;
}

/// Pumps [screen] the way the app shows a Settings page on a phone: in the
/// Settings branch's Navigator beside the sidebar rail, with Phone colors
/// offered (unless not [phone]), [lang] strings and [textScale] over the
/// whole app.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required double textScale,
  required String lang,
  bool phone = true,
}) async {
  Settings.debugResetPrimed();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dynamicColorAvailableProvider.overrideWith((ref) async => phone),
      ],
      child: MaterialApp(
        theme: layoutPhoneTheme,
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Row(
          children: [
            const SizedBox(width: kRailWidth),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => screen),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The strings, the saved settings and Phone colors load asynchronously.
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Runs [body] at every layout width × text scale × language of [langs],
/// with [prefs] ([_prefs] by default) saved and a window [height] tall.
Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(String where, double width, String lang) body, {
  List<String> langs = _langs,
  double height = 4000,
  Map<String, Object>? prefs,
}) async {
  addTearDown(tester.view.reset);
  for (final lang in langs) {
    for (final width in kLayoutWidths) {
      for (final t in kLayoutTextScales) {
        SharedPreferences.setMockInitialValues(prefs ?? _prefs);
        setLayoutScreen(tester, width, height: height);
        await body('$lang, ${width.toInt()} dp at ${t}x', t, lang);
        await tester.pumpWidget(const SizedBox());
      }
    }
  }
}

/// No text under [scope] is cut off: not too short for its lines, and not
/// narrower than a glyph that won't wrap.
void _expectNothingCut(WidgetTester tester, Finder scope, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(
    find.descendant(of: scope, matching: find.byType(RichText)),
  );
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    expect(
      p.size.height,
      greaterThanOrEqualTo(p.textSize.height - _eps),
      reason: '$where: "$text" cut off at the bottom',
    );
    expect(
      p.size.width,
      greaterThanOrEqualTo(p.textSize.width - _eps),
      reason: '$where: "$text" cut off at the side',
    );
  }
}

/// Every line break in [finder]'s text falls between words (or after a
/// hyphen): a box too narrow for a word breaks it across lines without
/// reporting any overflow.
void _expectWholeWords(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    double? lastTop;
    for (var i = 0; i < text.length; i++) {
      final top = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
      if (lastTop != null && top > lastTop + 0.5) {
        expect(
          text[i - 1].trim().isEmpty ||
              text[i].trim().isEmpty ||
              text[i - 1] == '-',
          isTrue,
          reason:
              '$where: "$text" broken inside a word at '
              '"${text.substring(0, i)}|${text.substring(i)}"',
        );
      }
      lastTop = top;
    }
  }
}

/// No word of the editor's labels is broken across lines, in a Latin
/// language (Roboto's real widths).
void _expectEditorWords(WidgetTester tester, String lang, String where) {
  if (!_latin.contains(lang)) return;
  final s = AppStrings.of(tester.element(find.byType(ColorThemeEditor)));
  for (final text in [
    s.textColorWhite,
    s.textColorBlack,
    s.recommended,
    s.readabilityEasy,
    s.readabilityLargeOnly,
    s.readabilityHard,
    s.hardToSeeOnLight,
    s.hardToSeeOnDark,
    s.useAccentColor,
    s.themeStyleVivid,
    s.themeStyleSoft,
    s.themeStyleMuted,
    s.light,
    s.dark,
    s.hue,
    s.saturation,
    s.brightness,
    s.save,
  ]) {
    final found = find.text(text);
    if (found.evaluate().isNotEmpty) {
      _expectWholeWords(tester, found, '$where, "$text"');
    }
  }
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=true\nENABLE_PIN_GATE=true',
    );
    PackageInfo.setMockInitialValues(
      appName: 'Micro Seller',
      packageName: 'com.blackshadowsoftware.micro_seller',
      version: '1.0.4',
      buildNumber: '9',
      buildSignature: '',
    );
  });

  testWidgets('Color theme lays out at every size', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, t, lang) async {
      await _pump(tester, const ColorThemeScreen(), textScale: t, lang: lang);
      final s = AppStrings.of(tester.element(find.byType(ColorThemeScreen)));
      final screen = find.byType(ColorThemeScreen);
      expectCleanLayout(tester, where);
      _expectNothingCut(tester, screen, where);
      // Phone colors, every preset and every saved theme are on it.
      expect(find.text(s.phoneColorsDesc), findsOneWidget, reason: where);
      for (final preset in kPresetColorThemes) {
        expect(
          find.text(s.presetThemeName(preset.id)),
          findsOneWidget,
          reason: '$where, ${preset.id}',
        );
      }
      for (final theme in _customs.skip(1)) {
        expect(find.text(theme.name!), findsOneWidget, reason: where);
      }
      // The selected one's name is beside the preview too.
      expect(find.text(_customs.first.name!), findsNWidgets(2), reason: where);
      expect(
        find.text(s.themeLimitReached(kMaxCustomColorThemes)),
        findsOneWidget,
        reason: where,
      );
      // No preset's name breaks inside a word: the grid has as many columns
      // as keep every name's longest word whole.
      if (_latin.contains(lang)) {
        for (final preset in kPresetColorThemes) {
          _expectWholeWords(
            tester,
            find.text(s.presetThemeName(preset.id)),
            '$where, ${preset.id}',
          );
        }
        for (final text in [
          s.editTheme,
          s.createTheme,
          s.phoneColors,
          s.phoneColorsDesc,
          s.colorThemeDesc,
        ]) {
          _expectWholeWords(tester, find.text(text), where);
        }
      }

      // A saved theme's menu.
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();
      expectCleanLayout(tester, '$where, menu');
      for (final text in [s.edit, s.delete]) {
        expectWholeText(tester, find.text(text).last, '$where, menu');
      }
    });
  });

  testWidgets("Phone colors saved where the phone hasn't them: its note "
      'lays out whole', (tester) async {
    requireRoboto();
    await _forEachLayout(
      tester,
      (where, t, lang) async {
        await _pump(
          tester,
          const ColorThemeScreen(),
          textScale: t,
          lang: lang,
          phone: false,
        );
        final s = AppStrings.of(tester.element(find.byType(ColorThemeScreen)));
        final note = find.text(
          s.phoneColorsUnavailable(s.presetThemeName(kDefaultColorThemeId)),
        );
        expect(note, findsOneWidget, reason: where);
        expectCleanLayout(tester, where);
        _expectNothingCut(tester, find.byType(ColorThemeScreen), where);
        if (_latin.contains(lang)) _expectWholeWords(tester, note, where);
      },
      prefs: {Settings.keyColorThemeId: kPhoneColorThemeId},
    );
  });

  testWidgets('the editor lays out at every size', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, t, lang) async {
      // A saved theme with an accent: both color pickers are shown.
      await _pump(
        tester,
        ColorThemeEditor.edit(theme: _customs.first),
        textScale: t,
        lang: lang,
      );
      final editor = find.byType(ColorThemeEditor);
      final s = AppStrings.of(tester.element(editor));
      expectCleanLayout(tester, where);
      _expectNothingCut(tester, editor, where);
      expect(find.text(s.hexColor), findsNWidgets(2), reason: where);
      expect(find.text(s.recommended), findsOneWidget, reason: where);
      // The full name is in its field.
      expect(find.text(_customs.first.name!), findsOneWidget, reason: where);
      _expectEditorWords(tester, lang, where);

      // The dark preview, and navy: hard to see on the dark background (a
      // hint), and black on it hard to read.
      await tester.tap(find.widgetWithText(ChoiceChip, s.dark));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, s.hexColor).first,
        '000080',
      );
      await tester.pumpAndSettle();
      expectCleanLayout(tester, '$where, dark');
      _expectNothingCut(tester, editor, '$where, dark');
      expect(find.text(s.hardToSeeOnDark), findsOneWidget, reason: where);
      expect(find.text(s.readabilityHard), findsOneWidget, reason: where);
      _expectEditorWords(tester, lang, '$where, dark');
    });
  });

  testWidgets('the editor scrolls whole on a short phone', (tester) async {
    await _forEachLayout(
      tester,
      (where, t, lang) async {
        await _pump(
          tester,
          ColorThemeEditor.edit(theme: _customs.first),
          textScale: t,
          lang: lang,
        );
        final editor = find.byType(ColorThemeEditor);
        final list = find
            .descendant(of: editor, matching: find.byType(Scrollable))
            .first;
        for (var i = 0; i < 12; i++) {
          expectCleanLayout(tester, '$where, scrolled $i');
          await tester.drag(list, const Offset(0, -400));
          await tester.pump();
        }
        expectCleanLayout(tester, '$where, at the end');
        // Save stays on screen under the form.
        final s = AppStrings.of(tester.element(editor));
        final save = tester.getRect(find.widgetWithText(FilledButton, s.save));
        expect(save.bottom, lessThanOrEqualTo(640 + _eps), reason: where);
      },
      langs: const ['en', 'ar'],
      height: 640,
    );
  });

  testWidgets("Settings' Color theme row shows a long name whole", (
    tester,
  ) async {
    await _forEachLayout(
      tester,
      (where, t, lang) async {
        await _pump(
          tester,
          SettingsScreen(driveService: _FakeDrive()),
          textScale: t,
          lang: lang,
        );
        final s = AppStrings.of(tester.element(find.byType(SettingsScreen)));
        expectCleanLayout(tester, where);
        final row = find.widgetWithText(ListTile, s.colorTheme);
        expect(row, findsOneWidget, reason: where);
        _expectNothingCut(tester, row, where);
        expect(
          find.descendant(of: row, matching: find.text(_customs.first.name!)),
          findsOneWidget,
          reason: where,
        );
      },
      langs: const ['en', 'ar'],
      height: 6000,
    );
  });
}
