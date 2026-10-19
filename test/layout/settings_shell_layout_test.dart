import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/router/app_router.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';

// The app's shell (the sidebar beside every screen) from the narrowest layout
// (320 dp) to a tablet's labelled sidebar (≥ 600 dp), up to a large phone
// font (150%) and on a phone held sideways; and the first-run tour, which
// can't run under a Display size zoom.

const _eps = 0.01;

/// Logical widths: the phones' icon rail, and the labelled sidebar from
/// 600 dp.
const _widths = [...kLayoutWidths, 600.0, 800.0];

/// A phone upright, and held sideways.
const _heights = [800.0, 360.0];

/// Latin, right-to-left and two scripts the test font draws wide.
const _langs = ['en', 'fr', 'ar', 'bn', 'th'];

/// The sidebar.
final _sidebar = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_Sidebar',
);

/// Pumps the app's router on the Settings tab, with [lang] strings,
/// [textScale] over the whole app and the Display size at [percent].
Future<void> _pumpShell(
  WidgetTester tester, {
  double textScale = 1,
  String lang = 'en',
  int percent = 100,
}) async {
  // Settings: the one tab that needs no database.
  appRouter.go('/settings');
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
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
          child: AppZoom(displayPercent: percent, child: child!),
        ),
      ),
    ),
  );
  // The app's strings and the saved settings load asynchronously.
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    // No Security rows: they would query the biometric hardware.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
  });

  testWidgets('the sidebar lays out at every size, in every script', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final lang in _langs) {
      for (final height in _heights) {
        for (final width in _widths) {
          for (final t in kLayoutTextScales) {
            final where =
                '$lang, ${width.toInt()}×${height.toInt()} dp at ${t}x';
            // The tour done: it isn't what is measured here.
            SharedPreferences.setMockInitialValues({'tour_completed': true});
            setLayoutScreen(tester, width, height: height);
            await _pumpShell(tester, textScale: t, lang: lang);
            expectCleanLayout(tester, where);
            // The icon rail on a phone, the labelled sidebar from 600 dp.
            final sidebar = tester.getRect(_sidebar);
            expect(
              sidebar.width,
              width >= 600 ? 200 : kRailWidth,
              reason: where,
            );
            // A label is whole, in its 44 dp tile, inside the sidebar.
            for (final p in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: _sidebar, matching: find.byType(RichText)),
            )) {
              final text = p.text.toPlainText();
              final rect = p.localToGlobal(Offset.zero) & p.size;
              expect(
                p.size.height,
                greaterThanOrEqualTo(p.textSize.height - _eps),
                reason: '$where: "$text" cut off',
              );
              expect(rect.height, lessThanOrEqualTo(44), reason: where);
              expect(
                rect.left,
                greaterThanOrEqualTo(sidebar.left - _eps),
                reason: '$where: "$text" past the sidebar',
              );
              expect(
                rect.right,
                lessThanOrEqualTo(sidebar.right + _eps),
                reason: '$where: "$text" past the sidebar',
              );
            }
            // The last tab can be scrolled to, sideways too.
            final settings = find.descendant(
              of: _sidebar,
              matching: find.byTooltip(
                sidebarItems.last.label(tester.element(_sidebar)),
              ),
            );
            final settingsTile = width >= 600
                ? find.descendant(
                    of: _sidebar,
                    matching: find.text(
                      sidebarItems.last.label(tester.element(_sidebar)),
                    ),
                  )
                : settings;
            await tester.ensureVisible(settingsTile);
            await tester.pump();
            final tile = tester.getRect(settingsTile);
            expect(tile.top, greaterThanOrEqualTo(-_eps), reason: where);
            expect(
              tile.bottom,
              lessThanOrEqualTo(height + _eps),
              reason: where,
            );
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    }
  });

  group('first-run tour', () {
    testWidgets('under a Display size zoom, is skipped and marked done', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      setLayoutScreen(tester, 411);
      await _pumpShell(tester, percent: 90);
      // The tour waits 1.5 s for the first screen to settle.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(ShowcaseView.get().isShowcaseRunning, isFalse);
      // Not a first run: no tour on a later start either, and the rating
      // prompt, which waits for the tour, can be shown.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_completed'), isTrue);
    });

    testWidgets('at 100% runs, and is marked done only when finished', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      setLayoutScreen(tester, 411);
      await _pumpShell(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(ShowcaseView.get().isShowcaseRunning, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_completed'), isNull);

      ShowcaseView.get().dismiss();
      await tester.pumpAndSettle();
      expect(ShowcaseView.get().isShowcaseRunning, isFalse);
      expect(prefs.getBool('tour_completed'), isTrue);
    });
  });
}
