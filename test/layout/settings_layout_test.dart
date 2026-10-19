import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';

// Layout of Settings under the Display size / Text size settings: every
// section, row, picker and dialog lays out cleanly from the narrowest layout
// (320 dp) to a large phone font (150%), in every language and with long
// data, and looks as before at 100% text on a phone.

const _eps = 0.01;

/// Every language the app ships.
final _langs = [
  for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
];

/// Languages in Latin script, which the test draws in Roboto's real widths:
/// where a broken word is a layout fault and not the test font's.
const _latin = {'en', 'es', 'fr', 'pt', 'tr', 'id', 'vi', 'ms'};

/// The version the About row reads, as the build sets it.
const _version = '1.0.4 (9)';

/// Tall enough for the whole Settings list to be built at once.
const _tall = 6000.0;

/// The app's light theme as a phone draws it. The theme's button and app bar
/// title styles name no font family: a phone draws those in its system font
/// (Roboto on Android), a test in its square test font, far wider. Naming
/// Roboto there measures them as on a phone.
final ThemeData _phoneTheme = () {
  final theme = AppTheme.lightTheme;
  ButtonStyle? roboto(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle?.resolve(states)?.copyWith(fontFamily: 'Roboto'),
    ),
  );
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: roboto(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: roboto(theme.outlinedButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: roboto(theme.elevatedButtonTheme.style),
    ),
  );
}();

/// Long data in every field Settings shows, an auto-backup failure for the
/// Drive banner, and [lang] as the app's language.
Map<String, Object> _prefs(String lang) => {
  'language': lang,
  'shopName': 'Mohammad Abdur Rahman Chowdhury Trading Company Limited',
  'shopPhone': '+880 1712-345678, +880 1812-345678',
  // The longest symbol the currency picker offers.
  'currencySymbol': 'KSh',
  'downloadDirectory':
      '/storage/emulated/0/Download/Micro Seller/Invoices/2026/October',
  'lastBackupTime': '2026-10-19T12:30:00.000',
  'autoBackup': true,
  'autoBackupError':
      'Google Drive access was revoked. Sign in again to '
      'resume automatic backups.',
  'lowStockThreshold': 100000,
  'taxRate': 12.5,
};

/// Drive without Google: signed out, and five backups to restore.
class _FakeDrive extends DriveService {
  /// How many times Sign in was pressed.
  int signIns = 0;

  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    signIns++;
    return null;
  }

  @override
  Future<List<DriveBackupInfo>> listBackups() async => [
    for (var i = 0; i < 5; i++)
      DriveBackupInfo(
        fileId: 'backup-$i',
        name: 'sellerbook_backup_2026-10-${19 - i}_12-30-00.json',
        createdTime: DateTime(2026, 10, 19 - i, 12, 30),
      ),
  ];
}

/// Pumps Settings the way the app shows it on a phone: in a shell branch's
/// Navigator beside the sidebar rail, so a sheet opens beside the rail and a
/// dialog over the whole window, with the app's theme, [lang] strings and
/// [textScale] over the whole app. Returns a context inside the branch.
Future<BuildContext> _pumpSettings(
  WidgetTester tester, {
  double textScale = 1,
  String lang = 'en',
  _FakeDrive? drive,
}) async {
  late BuildContext branch;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: _phoneTheme,
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
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) {
                    branch = context;
                    return SettingsScreen(driveService: drive ?? _FakeDrive());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The app's strings, the saved settings and the version load
  // asynchronously.
  await tester.pump();
  await tester.pumpAndSettle();
  return branch;
}

/// Runs [body] at every layout width × text scale × [heights] × [langs],
/// clearing the screen after each, with [lang]'s long data saved.
Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(
    String where,
    double width,
    double textScale,
    String lang,
  )
  body, {
  List<double> heights = const [800],
  required List<String> langs,
}) async {
  addTearDown(tester.view.reset);
  for (final lang in langs) {
    for (final height in heights) {
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          SharedPreferences.setMockInitialValues(_prefs(lang));
          setLayoutScreen(tester, width, height: height);
          await body(
            '$lang, ${width.toInt()}×${height.toInt()} dp at ${t}x',
            width,
            t,
            lang,
          );
          await tester.pumpWidget(const SizedBox());
        }
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

/// Every line break in [finder]'s text falls between words: a box too narrow
/// for a word breaks it across lines without reporting any overflow.
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
          text[i - 1].trim().isEmpty || text[i].trim().isEmpty,
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

/// The card [text] is in: its rows' Material, as wide as the card.
Finder _card(Finder text) =>
    find.ancestor(of: text, matching: find.byType(Material)).first;

/// [finder]'s text inside a ListTile (a row's title or subtitle), not a
/// button's label.
Finder _inTile(Finder finder) =>
    find.descendant(of: find.byType(ListTile), matching: finder);

/// Sidebar position's Left / Right toggle.
final _toggle = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_SidebarPositionToggle',
);

/// Scrolls Settings until [finder] is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    // Both Security rows shown.
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

  group('Settings screen', () {
    testWidgets('lays out at every size, in every language', (tester) async {
      requireRoboto();
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpSettings(tester, textScale: t, lang: lang);
          final s = AppStrings.of(branch);
          expectCleanLayout(tester, where);
          _expectNothingCut(tester, find.byType(SettingsScreen), where);
          // The Drive banner, both Security rows and the version are shown.
          expect(
            find.text(s.tr('autoBackupPaused')),
            findsOneWidget,
            reason: where,
          );
          expect(
            find.text(s.tr('securityFingerprint')),
            findsOneWidget,
            reason: where,
          );
          expect(find.text(s.tr('securityPin')), findsOneWidget, reason: where);
          expect(find.text(_version), findsOneWidget, reason: where);
          if (_latin.contains(lang)) {
            // The rows with a control at their end never break a word: the
            // control goes under the texts instead.
            for (final text in [
              s.sidebarPosition,
              s.googleAccount,
              s.signIn,
              s.appVersion,
              _version,
            ]) {
              _expectWholeWords(tester, find.text(text), where);
            }
          }
        },
        heights: const [_tall],
        langs: _langs,
      );
    });

    testWidgets('the end controls sit where ListTile put them, at 100%', (
      tester,
    ) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        final where = '${width.toInt()} dp';
        SharedPreferences.setMockInitialValues(_prefs('en'));
        setLayoutScreen(tester, width, height: _tall);
        final branch = await _pumpSettings(tester);
        final s = AppStrings.of(branch);
        expectCleanLayout(tester, where);
        // Where the toggle is drawn, it is pressed: its right half.
        await tester.tap(
          find.descendant(of: _toggle, matching: find.byType(ThinIcon)).last,
        );
        await tester.pump();
        expect(
          ProviderScope.containerOf(
            branch,
          ).read(settingsProvider.notifier).sidebarPosition,
          Settings.sidebarPositionRight,
          reason: where,
        );
        // The geometry needs Roboto's real widths: in the test font the
        // controls go under the texts.
        for (final (title, control) in [
          (s.sidebarPosition, _toggle),
          (s.googleAccount, find.widgetWithText(TextButton, s.signIn)),
          (s.appVersion, find.text(_version)),
        ]) {
          final card = tester.getRect(_card(find.text(title)));
          final tile = tester.getRect(
            find.ancestor(
              of: find.text(title),
              matching: find.byType(ListTile),
            ),
          );
          final end = tester.getRect(control);
          final what = '$where, $title';
          // ListTile's trailing: its padding from the card's end, centered
          // across the row ...
          expect(end.right, closeTo(card.right - 16, _eps), reason: what);
          expect(end.center.dy, closeTo(tile.center.dy, _eps), reason: what);
          // ... and the title gets what the padding, the icon box, the gaps
          // and the control leave it, as with ListTile's trailing.
          expect(
            tester.getSize(_inTile(find.text(title))).width,
            closeTo(card.width - end.width - 104, _eps),
            reason: what,
          );
          expect(tile.left, closeTo(card.left, _eps), reason: what);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('an end control goes under the texts when a word would break', (
      tester,
    ) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      // "Compte Google" beside "Se connecter" had 20 dp: a letter a line.
      for (final (lang, width, t) in [
        ('fr', 320.0, 1.0),
        ('es', 360.0, 1.3),
        ('en', 320.0, 1.5),
        ('ar', 320.0, 1.5),
      ]) {
        final where = '$lang, ${width.toInt()} dp at ${t}x';
        SharedPreferences.setMockInitialValues(_prefs(lang));
        setLayoutScreen(tester, width, height: _tall);
        final drive = _FakeDrive();
        final branch = await _pumpSettings(
          tester,
          textScale: t,
          lang: lang,
          drive: drive,
        );
        final s = AppStrings.of(branch);
        final rtl = Directionality.of(branch) == TextDirection.rtl;
        expectCleanLayout(tester, where);
        final card = tester.getRect(_card(find.text(s.googleAccount)));
        final subtitle = tester.getRect(_inTile(find.text(s.signIn)));
        final button = tester.getRect(
          find.widgetWithText(TextButton, s.signIn),
        );
        // Under the subtitle, in line with the title.
        expect(
          button.top,
          greaterThanOrEqualTo(subtitle.bottom - _eps),
          reason: where,
        );
        if (rtl) {
          expect(button.right, closeTo(card.right - 72, _eps), reason: where);
        } else {
          expect(button.left, closeTo(card.left + 72, _eps), reason: where);
        }
        // The title has the row to itself.
        expect(
          tester.getSize(_inTile(find.text(s.googleAccount))).width,
          closeTo(card.width - 88, _eps),
          reason: where,
        );
        if (_latin.contains(lang)) {
          _expectWholeWords(tester, find.text(s.googleAccount), where);
          _expectWholeWords(tester, find.text(s.signIn), where);
        }
        // Where it is drawn, it is pressed.
        await tester.tap(find.widgetWithText(TextButton, s.signIn));
        await tester.pump();
        expect(drive.signIns, 1, reason: where);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a row icon is drawn at its coded size, centered in its box', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(_prefs('en'));
      setLayoutScreen(tester, 411, height: _tall);
      final branch = await _pumpSettings(tester);
      final s = AppStrings.of(branch);
      final boxes = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints ==
                const BoxConstraints.tightFor(width: 40, height: 40),
      );
      Finder iconIn(Finder box) =>
          find.descendant(of: box, matching: find.byType(ThinIcon));

      // The Display size row: a 20 dp icon in its 40 dp box (the box's
      // tight size used to stretch it to 40).
      final displayBox = find.descendant(
        of: find.widgetWithText(ListTile, s.displaySize),
        matching: boxes,
      );
      expect(tester.getSize(displayBox), const Size(40, 40));
      expect(tester.getSize(iconIn(displayBox)), const Size(20, 20));
      expect(
        tester.getCenter(iconIn(displayBox)),
        tester.getCenter(displayBox),
      );

      // Every row's icon: the size it is coded with (the ambient 24 when
      // none), centered.
      expect(boxes, findsAtLeastNWidgets(20));
      for (final box in boxes.evaluate()) {
        final icon = iconIn(find.byWidget(box.widget));
        final coded =
            tester.widget<ThinIcon>(icon).size ??
            IconTheme.of(tester.element(icon)).size!;
        expect(tester.getSize(icon), Size.square(coded));
        expect(
          tester.getCenter(icon),
          tester.getCenter(find.byWidget(box.widget)),
        );
      }

      // Sidebar position's toggle: 18 dp icons in its 36 × 30 halves.
      final toggleIcons = find.descendant(
        of: _toggle,
        matching: find.byType(ThinIcon),
      );
      expect(toggleIcons, findsNWidgets(2));
      for (final icon in toggleIcons.evaluate()) {
        expect(tester.getSize(find.byWidget(icon.widget)), const Size(18, 18));
      }
      expect(tester.getSize(_toggle), const Size(76, 34));
    });

    testWidgets('a row draws its ink on its card, not under it', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(_prefs('en'));
      setLayoutScreen(tester, 411, height: _tall);
      final branch = await _pumpSettings(tester);
      final s = AppStrings.of(branch);
      // Flutter reports a row whose ink a coloured box hides; none is.
      expectCleanLayout(tester, 'Settings');

      // Every row paints on a transparent Material inside its card ...
      final tiles = find.byType(ListTile);
      expect(tiles, findsAtLeastNWidgets(20));
      for (final tile in tiles.evaluate()) {
        final material = tester.widget<Material>(
          find
              .ancestor(
                of: find.byWidget(tile.widget),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.type, MaterialType.transparency);
        expect(material.color, isNull);
      }

      // ... not on the screen's, under the card's colour: a press draws
      // there.
      final row = find.widgetWithText(ListTile, s.displaySize);
      final rowInk = Material.of(tester.element(row));
      expect(
        rowInk,
        isNot(same(Material.of(tester.element(find.byType(ListView))))),
      );
      final gesture = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 100));
      expect((rowInk as dynamic).debugInkFeatures, isNotEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('Settings pickers and dialogs', () {
    testWidgets('the currency picker lays out at every size', (tester) async {
      requireRoboto();
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpSettings(tester, textScale: t, lang: lang);
          final s = AppStrings.of(branch);
          await _scrollTo(tester, find.text(s.currencySymbol));
          await tester.tap(find.text(s.currencySymbol));
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          final list = find.descendant(
            of: sheet,
            matching: find.byType(ListView),
          );
          expectCleanLayout(tester, where);
          // The search icon at its coded size (the field's 48 dp icon slot
          // used to stretch it).
          expect(
            tester.getSize(
              find.descendant(
                of: find.byType(TextField),
                matching: find.byType(ThinIcon),
              ),
            ),
            const Size(20, 20),
          );
          // Every symbol whole in its box (KSh wrapped and was cut off at
          // 150%), down the whole list.
          for (var i = 0; i < 12; i++) {
            _expectNothingCut(tester, list, '$where, scrolled $i');
            await tester.drag(list, const Offset(0, -300));
            await tester.pump();
            expectCleanLayout(tester, '$where, scrolled $i');
          }
          expect(find.text('INR'), findsOneWidget, reason: where);
          _expectNothingCut(tester, list, '$where, at the end');
        },
        heights: const [800, 600],
        langs: const ['en', 'fr', 'ar'],
      );
    });

    testWidgets('the language picker lays out at every size', (tester) async {
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpSettings(tester, textScale: t, lang: lang);
          final s = AppStrings.of(branch);
          final row = _inTile(find.text(s.language));
          await _scrollTo(tester, row);
          await tester.tap(row);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          final list = find.descendant(
            of: sheet,
            matching: find.byType(ListView),
          );
          expectCleanLayout(tester, where);
          for (var i = 0; i < 4; i++) {
            _expectNothingCut(tester, sheet, '$where, scrolled $i');
            await tester.drag(list, const Offset(0, -300));
            await tester.pump();
            expectCleanLayout(tester, '$where, scrolled $i');
          }
          // Every language's name, down to the last.
          expect(
            find.text(AppLocalizations.languageNames['ms']!),
            findsOneWidget,
            reason: where,
          );
        },
        heights: const [800, 600],
        langs: const ['en', 'pt', 'ar'],
      );
    });

    testWidgets('editing the shop name lays out at every size', (tester) async {
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpSettings(tester, textScale: t, lang: lang);
          final s = AppStrings.of(branch);
          await _scrollTo(tester, find.text(s.shopName));
          await tester.tap(find.text(s.shopName));
          await tester.pumpAndSettle();
          expectCleanLayout(tester, where);
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget, reason: where);
          for (final text in ['${s.edit} ${s.shopName}', s.cancel, s.save]) {
            expectWholeText(
              tester,
              find.descendant(of: dialog, matching: find.text(text)),
              where,
            );
          }
        },
        heights: const [800, 600],
        langs: const ['en', 'fr', 'ar'],
      );
    });

    testWidgets('the Drive backup picker scrolls five backups at every size', (
      tester,
    ) async {
      requireRoboto();
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpSettings(tester, textScale: t, lang: lang);
          final s = AppStrings.of(branch);
          await _scrollTo(tester, find.text(s.restoreFromDrive));
          await tester.tap(find.text(s.restoreFromDrive));
          // The row's spinner turns while the sheet is open: no settling.
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          // Five long names at a large size ran off the sheet's bottom.
          expectCleanLayout(tester, where);
          final sheet = find.byType(BottomSheet);
          expect(
            find.text(s.selectBackupToRestore),
            findsOneWidget,
            reason: where,
          );
          final last = find.text('sellerbook_backup_2026-10-15_12-30-00.json');
          await tester.scrollUntilVisible(
            last,
            100,
            scrollable: find.descendant(
              of: sheet,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          expectCleanLayout(tester, where);
          final sheetRect = tester.getRect(sheet);
          expect(
            tester.getRect(last).bottom,
            lessThanOrEqualTo(sheetRect.bottom + _eps),
            reason: where,
          );
        },
        heights: const [800, 600],
        langs: const ['en'],
      );
    });
  });
}
