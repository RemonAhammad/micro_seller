import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/l10n/translations_en.dart';
import 'package:micro_seller/shared/widgets/section_help.dart';

// The ? on each main screen: what the screen is for, when to use it, and the
// screens it works with, each one tap away.

void main() {
  test('every sidebar section has help, a route and real strings', () {
    for (final item in sidebarItems) {
      final help = kSectionHelp[item.key];
      expect(help, isNotNull, reason: item.key);
      expect(kSectionRoutes[item.key], isNotNull, reason: item.key);
      for (final key in [help!.what, help.when, for (final r in help.related) r.$2]) {
        expect(translationsEn[key], isNotNull, reason: '${item.key}: $key');
      }
      for (final (related, _) in help.related) {
        expect(kSectionRoutes[related], isNotNull, reason: '${item.key} → $related');
        expect(related, isNot(item.key));
      }
    }
  });

  testWidgets('a related section opens that screen', (tester) async {
    final router = GoRouter(routes: [
      for (final MapEntry(key: section, value: path) in kSectionRoutes.entries)
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(
            appBar: AppBar(
              title: Text('screen:$section'),
              actions: [SectionHelpButton(section)],
            ),
          ),
        ),
    ], initialLocation: '/orders');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('About this screen'));
    await tester.pumpAndSettle();
    expect(find.text(translationsEn['helpOrdersWhat']!), findsOneWidget);
    expect(find.text('When to use it'), findsOneWidget);
    expect(find.text('Works with'), findsOneWidget);
    expect(find.text(translationsEn['helpOrdersDues']!), findsOneWidget);

    await tester.tap(find.text(translationsEn['helpOrdersDues']!));
    await tester.pumpAndSettle();
    expect(find.text('screen:dues'), findsOneWidget);
    expect(find.text(translationsEn['helpOrdersWhat']!), findsNothing);
  });
}
