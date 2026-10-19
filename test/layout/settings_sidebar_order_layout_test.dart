import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/features/settings/presentation/sidebar_order_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';

// Layout of Settings → Sidebar Order from the narrowest layout (320 dp) to a
// large phone font (150%), in every language: every tab's row whole, its
// switch and grip on screen. (Its drag under the Display size zoom is in
// sidebar_order_zoom_test.dart.)

const _eps = 0.01;

/// Every language the app ships.
final _langs = [
  for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
];

/// Pumps Sidebar Order the way the app shows it: in the Settings branch's
/// Navigator beside the sidebar rail, with [lang] strings and [textScale].
Future<void> _pump(WidgetTester tester, double textScale, String lang) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
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
                  builder: (_) => const SidebarOrderScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The app's strings and the saved order load asynchronously.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('Sidebar Order lays out at every size, in every language', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final lang in _langs) {
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = '$lang, ${width.toInt()} dp at ${t}x';
          SharedPreferences.setMockInitialValues({});
          // Tall enough for every tab's row to be built.
          setLayoutScreen(tester, width, height: 2400);
          await _pump(tester, t, lang);
          expectCleanLayout(tester, where);
          final screen = find.byType(SidebarOrderScreen);
          for (final p in tester.renderObjectList<RenderParagraph>(
            find.descendant(of: screen, matching: find.byType(RichText)),
          )) {
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
          // Every tab's row, its switch and grip inside the window.
          for (final key in defaultSidebarOrder) {
            final row = find.byKey(ValueKey(key));
            expect(row, findsOneWidget, reason: '$where: $key');
            final rect = tester.getRect(row);
            for (final part in [
              find.byType(CupertinoSwitch),
              find.byType(ReorderableDragStartListener),
            ]) {
              final r = tester.getRect(
                find.descendant(of: row, matching: part).first,
              );
              expect(
                r.left,
                greaterThanOrEqualTo(rect.left - _eps),
                reason: '$where: $key',
              );
              expect(
                r.right,
                lessThanOrEqualTo(width + _eps),
                reason: '$where: $key',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });
}
