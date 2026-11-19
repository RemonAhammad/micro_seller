import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/data/models/category.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/features/categories/providers/category_provider.dart';
import 'package:micro_seller/features/inventory/presentation/inventory_screen.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';

/// The Inventory category filter: picking "All Categories" must clear it.
/// Its menu value used to be null, which PopupMenuButton reports as a
/// cancel, so the reset never reached onSelected.
void main() {
  final shirt = Product(id: 1, name: 'Blue Shirt', sellingPrice: 10, stockQty: 5, category: 'Clothing');
  final soap = Product(id: 2, name: 'Lemon Soap', sellingPrice: 2, stockQty: 5, category: 'Toiletries');

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) => Stream.value([shirt, soap])),
        categoriesProvider.overrideWith(
          (ref) => Stream.value([Category(name: 'Clothing'), Category(name: 'Toiletries')]),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InventoryScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('All Categories clears the filter, and filtering works again after', (tester) async {
    await pump(tester);
    expect(find.text('Blue Shirt'), findsOneWidget);
    expect(find.text('Lemon Soap'), findsOneWidget);

    await pick(tester, 'Clothing');
    expect(find.text('Blue Shirt'), findsOneWidget);
    expect(find.text('Lemon Soap'), findsNothing);

    await pick(tester, 'All Categories');
    expect(find.text('Blue Shirt'), findsOneWidget);
    expect(find.text('Lemon Soap'), findsOneWidget);

    await pick(tester, 'Toiletries');
    expect(find.text('Blue Shirt'), findsNothing);
    expect(find.text('Lemon Soap'), findsOneWidget);
  });

  testWidgets('closing the menu without a choice keeps the filter', (tester) async {
    await pump(tester);
    await pick(tester, 'Clothing');

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Blue Shirt'), findsOneWidget);
    expect(find.text('Lemon Soap'), findsNothing);
  });
}
