import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/shared/widgets/entry_date_field.dart';
import 'package:micro_seller/shared/widgets/section_help.dart';

import '../support/layout_harness.dart';

// Layout of the screens' help sheets and of the date and time row, under the
// Display size / Text size settings: clean from 320 dp to a 150% font, in a
// long Latin-script language and right to left.

/// Pumps [home] in a branch Navigator beside the rail, as the app shows a
/// screen, so a sheet opens beside the rail. Returns a context inside it.
Future<BuildContext> _pumpBranch(
  WidgetTester tester,
  Widget home, {
  required double textScale,
  required String lang,
}) async {
  late BuildContext branch;
  await tester.pumpWidget(MaterialApp(
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
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
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
                return home;
              },
            ),
          ),
        ),
      ],
    ),
  ));
  await tester.pump();
  return branch;
}

Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(String where, double textScale, String lang) body, {
  List<String> langs = const ['en'],
}) async {
  addTearDown(tester.view.reset);
  for (final lang in langs) {
    for (final width in kLayoutWidths) {
      for (final t in kLayoutTextScales) {
        setLayoutScreen(tester, width);
        await body('$lang, ${width.toInt()} dp at ${t}x', t, lang);
        await tester.pumpWidget(const SizedBox());
      }
    }
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRoboto();
  });

  testWidgets('every help sheet lays out at every size', (tester) async {
    await _forEachLayout(tester, (where, t, lang) async {
      for (final item in sidebarItems) {
        final branch = await _pumpBranch(tester, const Scaffold(),
            textScale: t, lang: lang);
        showSectionHelp(branch, item.key);
        await tester.pumpAndSettle();
        final at = '$where, ${item.key}';
        expectCleanLayout(tester, at);
        final s = AppLocalizations.of(branch);
        final help = kSectionHelp[item.key]!;
        for (final key in [help.what, help.when, for (final r in help.related) r.$2]) {
          final text = find.text(s.tr(key));
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          expectWholeText(tester, text, at);
        }
        await tester.pumpWidget(const SizedBox());
      }
    }, langs: ['en', 'pt', 'ar']);
  });

  testWidgets('the date and time row lays out at every size', (tester) async {
    await _forEachLayout(tester, (where, t, lang) async {
      final branch = await _pumpBranch(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Builder(
                builder: (context) => EntryDateField(
                  label: AppLocalizations.of(context).tr('orderDate'),
                  value: null,
                  hint: AppLocalizations.of(context).tr('entryDateHint'),
                  onChanged: (_) {},
                  onReset: () {},
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) => EntryDateField(
                  label: AppLocalizations.of(context).tr('paymentDate'),
                  value: DateTime(2026, 12, 31, 23, 59),
                  onChanged: (_) {},
                  onReset: () {},
                ),
              ),
            ],
          ),
        ),
        textScale: t,
        lang: lang,
      );
      expectCleanLayout(tester, where);
      final s = AppLocalizations.of(branch);
      for (final key in ['orderDate', 'entryDateNow', 'entryDateHint', 'paymentDate']) {
        expectWholeText(tester, find.text(s.tr(key)), '$where, $key');
      }
    }, langs: ['en', 'pt', 'ar']);
  });
}
