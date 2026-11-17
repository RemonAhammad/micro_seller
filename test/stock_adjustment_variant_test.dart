import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/inventory/presentation/stock_adjustment_screen.dart';

import 'support/isar_core.dart';

/// The Stock Adjustment screen's variation handling: per-combination chips when
/// a product has configured combinations, and a "configure them" hint when it
/// has variant attributes but no combinations. Also guards against the
/// loading-state crash (the StreamBuilder builds once with a null product).
void main() {
  late Isar isar;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurrencyFormatter.setSymbol('\$');
  });
  tearDown(closeTestIsars);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, int productId) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/adjust',
      routes: [
        GoRoute(path: '/adjust', builder: (_, _) => StockAdjustmentScreen(productId: productId)),
        GoRoute(path: '/products/:id/edit', builder: (_, _) => const Scaffold(body: Text('edit form'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [isarProvider.overrideWith((ref) async => isar)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await settle(tester);
  }

  const hint =
      'This product has variations but no combinations are set up yet. Configure them to adjust stock for each variation.';

  group('Stock Adjustment variations', skip: isarSkipReason, () {
    testWidgets('a product with configured combinations shows the chips, no hint', (tester) async {
      await tester.runAsync(() async {
        isar = await openTestIsar('adjust_configured');
        await isar.writeTxn(() => isar.products.put(Product(
              name: 'Shirt',
              sellingPrice: 500,
              variantCombinations: [
                VariantCombination(
                    combinationKey: 'Size:L', displayLabel: 'Size: L', stockQty: 4),
              ],
            )));
      });
      await pumpScreen(tester, 1);

      expect(find.text('Select Combination'), findsOneWidget);
      expect(find.text('Size: L'), findsOneWidget);
      // Base stock is hidden when the product has active combinations.
      expect(find.textContaining('Base stock'), findsNothing);
      expect(find.text(hint), findsNothing);
    });

    testWidgets('attributes but no combinations shows the hint + Edit, no crash', (tester) async {
      await tester.runAsync(() async {
        isar = await openTestIsar('adjust_attrs_only');
        await isar.writeTxn(() => isar.products.put(Product(
              name: 'Hoodie',
              sellingPrice: 900,
              variantAttributes: [
                VariantAttribute(name: 'Size', options: const ['S', 'M']),
              ],
              variantCombinations: const [],
            )));
      });
      await pumpScreen(tester, 1);

      expect(find.text(hint), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Edit'), findsWidgets);
      expect(find.text('Select Combination'), findsNothing);
      // No exception thrown while building (the loading state has a null product).
      expect(tester.takeException(), isNull);
    });

    testWidgets('a plain product shows neither chips nor hint', (tester) async {
      await tester.runAsync(() async {
        isar = await openTestIsar('adjust_plain');
        await isar.writeTxn(() => isar.products.put(
            Product(name: 'Soap', sellingPrice: 40, stockQty: 10)));
      });
      await pumpScreen(tester, 1);

      expect(find.text('Select Combination'), findsNothing);
      expect(find.text(hint), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
