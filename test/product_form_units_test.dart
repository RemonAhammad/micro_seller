import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/features/products/presentation/product_form_screen.dart';

import 'support/isar_core.dart';
import 'support/screen_harness.dart';

/// The product form's "Sold by" unit: labels follow it, the stock fields take
/// decimals for kg / litre / metre only, and the unit and decimals are saved.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  /// The text field whose label starts with [label] (required fields draw
  /// their label as a widget with a star, the others as labelText).
  Finder field(String label) => find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        final d = w.decoration;
        if (d?.labelText?.startsWith(label) ?? false) return true;
        final l = d?.label;
        return l is Text && (l.data ?? l.textSpan?.toPlainText() ?? '').startsWith(label);
      });

  /// Scrolls the form until [f] is built and on screen.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    final list = find.byType(Scrollable).first;
    if (f.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(f, 150, scrollable: list, maxScrolls: 30);
      } on StateError {
        await tester.scrollUntilVisible(f, -150, scrollable: list, maxScrolls: 30);
      }
    }
    await tester.ensureVisible(f.first);
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    final f = field(label).first;
    await reveal(tester, field(label));
    await tester.enterText(f, text);
    await tester.pump();
  }

  Future<String> textOf(WidgetTester tester, String label) async {
    await reveal(tester, field(label));
    return tester.widget<TextField>(field(label).first).controller!.text;
  }

  Future<void> pickUnit(WidgetTester tester, String name) async {
    final dropdown = find.byType(DropdownButtonFormField<QuantityUnit>);
    await reveal(tester, dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String label) async {
    // The app bar's title says the same: tap the button at the bottom.
    final button = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    await reveal(tester, button);
    await tester.tap(button.first);
    await settleDb(tester);
  }

  group('product form units', skip: isarSkipReason, () {
    testWidgets('a kg product: per-kg labels, 2.5 kg stock, saved with its unit', (tester) async {
      late Isar isar;
      await tester.runAsync(() async => isar = await openTestIsar('form_kg'));
      await pumpScreen(tester, isar: isar, screen: const ProductFormScreen());

      await reveal(tester, find.text('Piece'));
      expect(find.text('Piece'), findsWidgets, reason: 'Piece by default');
      await type(tester, 'Product Name', 'Rui fish');
      await type(tester, 'Category', 'Fish');
      await type(tester, 'SKU', 'RUI-1');
      await pickUnit(tester, 'Kilogram (kg)');
      expect(field('Selling Price (per kg)'), findsOneWidget);
      expect(field('Cost Price (per kg)'), findsOneWidget);

      await type(tester, 'Selling Price', '600');
      await type(tester, 'Stock Quantity', '2.5');
      await type(tester, 'Low Stock Threshold', '0.75');
      expect(await textOf(tester, 'Stock Quantity'), '2.5');
      expect(find.text('kg'), findsWidgets, reason: 'the unit after the stock fields');

      await save(tester, 'Add Product');
      expect(find.text(kBelowScreen), findsOneWidget, reason: 'saved and closed');

      final saved = (await tester.runAsync(() => isar.products.where().findFirst()))!;
      expect(saved.name, 'Rui fish');
      expect(saved.unit, QuantityUnit.kg);
      expect(saved.stockQty, 2.5);
      expect(saved.lowStockThreshold, 0.75);
      expect(saved.sellingPrice, 600);
      expect(saved.category, 'Fish');
    });

    testWidgets('a piece product keeps whole numbers: the point is refused', (tester) async {
      late Isar isar;
      await tester.runAsync(() async => isar = await openTestIsar('form_piece'));
      await pumpScreen(tester, isar: isar, screen: const ProductFormScreen());

      await type(tester, 'Stock Quantity', '2.5');
      expect(await textOf(tester, 'Stock Quantity'), isNot(contains('.')));
      expect(field('Selling Price (per'), findsNothing, reason: 'no unit in a piece price');
    });

    testWidgets('editing a kg product shows its unit and decimal stock', (tester) async {
      late Isar isar;
      late Product fish;
      await tester.runAsync(() async {
        isar = await openTestIsar('form_edit_kg');
        await isar.writeTxn(() async {
          final id = await isar.products.put(Product(
              name: 'Rui fish', sku: 'RUI-1', category: 'Fish', sellingPrice: 600, stockQty: 3.75, lowStockThreshold: 0.5, unit: QuantityUnit.kg));
          fish = (await isar.products.get(id))!;
        });
      });
      await pumpScreen(tester, isar: isar, screen: ProductFormScreen(product: fish));

      await reveal(tester, find.text('Kilogram (kg)'));
      expect(find.text('Kilogram (kg)'), findsOneWidget);
      expect(await textOf(tester, 'Stock Quantity'), '3.75');
      expect(await textOf(tester, 'Low Stock Threshold'), '0.5');

      await type(tester, 'Stock Quantity', '4.125');
      await save(tester, 'Update Product');
      final saved = (await tester.runAsync(() => isar.products.get(fish.id)))!;
      expect(saved.stockQty, 4.125);
      expect(saved.unit, QuantityUnit.kg);
    });
  });
}
