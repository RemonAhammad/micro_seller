import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/product_serial.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/data/services/serial_service.dart';
import 'package:micro_seller/features/products/presentation/product_form_screen.dart';

import 'support/isar_core.dart';
import 'support/screen_harness.dart';

/// The product form's "Sold by" unit: labels follow it, the stock fields take
/// decimals for kg / litre / metre only, and the unit and decimals are saved.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // Real Roboto, so the menu is as wide as on a phone (the test font draws
  // every letter as a wide square).
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    for (final w in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/roboto/Roboto-$w.ttf'));
    }
    await loader.load();
  });
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

  final soldBy = find.byKey(const ValueKey('soldByField'));

  /// Touches the "Sold by" field at [fraction] of its width and returns the
  /// touch point and the open menu's rect.
  Future<(Offset, Rect)> openUnitMenu(WidgetTester tester, double fraction) async {
    await reveal(tester, soldBy);
    final fieldRect = tester.getRect(soldBy);
    final touch = Offset(fieldRect.left + fieldRect.width * fraction, fieldRect.top + 20);
    await tester.tapAt(touch);
    await tester.pumpAndSettle();
    final menu = find.ancestor(of: find.byType(PopupMenuItem<QuantityUnit>).first, matching: find.byType(Material)).first;
    return (touch, tester.getRect(menu));
  }

  Future<void> pickUnit(WidgetTester tester, String name) async {
    // A touch in the left half: the menu starts at the finger, sized to its
    // names, not field-wide from the field's edge.
    final (touch, menu) = await openUnitMenu(tester, 0.3);
    expect(menu.left, moreOrLessEquals(touch.dx, epsilon: 1), reason: 'opens at the finger');
    expect(menu.width, lessThan(tester.getSize(soldBy).width), reason: 'the menu is not field-wide');
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

    testWidgets('the Sold by menu opens where the field is touched, on either side', (tester) async {
      late Isar isar;
      await tester.runAsync(() async => isar = await openTestIsar('form_unit_menu'));
      await pumpScreen(tester, isar: isar, screen: const ProductFormScreen());

      // Left half: the menu starts at the finger.
      var (touch, menu) = await openUnitMenu(tester, 0.2);
      expect(menu.left, moreOrLessEquals(touch.dx, epsilon: 1));
      expect(menu.top, moreOrLessEquals(touch.dy, epsilon: 1), reason: 'the current unit at the finger');
      expect(find.byType(PopupMenuItem<QuantityUnit>), findsNWidgets(QuantityUnit.values.length));
      await tester.tapAt(const Offset(5, 5)); // dismiss
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<QuantityUnit>), findsNothing);

      // Right half: it ends at the finger, so it stays on screen.
      (touch, menu) = await openUnitMenu(tester, 0.8);
      expect(menu.right, moreOrLessEquals(touch.dx, epsilon: 1));
      expect(menu.width, lessThan(tester.getSize(soldBy).width));

      await tester.tap(find.text('Metre (m)').last);
      await tester.pumpAndSettle();
      expect(find.descendant(of: soldBy, matching: find.text('Metre (m)')), findsOneWidget, reason: 'the field shows the pick');
    });

    testWidgets('serial numbers and warranty: only for Piece; saved with the product', (tester) async {
      late Isar isar;
      await tester.runAsync(() async => isar = await openTestIsar('form_serials'));
      await pumpScreen(tester, isar: isar, screen: const ProductFormScreen());

      final serialSwitch = find.byKey(const ValueKey('trackSerialsSwitch'));
      await reveal(tester, serialSwitch);
      expect(serialSwitch, findsOneWidget, reason: 'Piece is the default');
      // At the very end: after the variants, just above the save button.
      final heading = find.text('Serial numbers & warranty');
      final button = find.ancestor(of: find.text('Add Product'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      await reveal(tester, button);
      expect(tester.getTopLeft(heading).dy, greaterThan(tester.getTopLeft(find.text('Variant Attributes')).dy));
      expect(tester.getTopLeft(heading).dy, lessThan(tester.getTopLeft(button).dy));
      expect(field('Warranty (months)'), findsOneWidget);

      await pickUnit(tester, 'Kilogram (kg)');
      expect(serialSwitch, findsNothing, reason: 'not for weighed goods');
      expect(field('Warranty (months)'), findsNothing);
      await pickUnit(tester, 'Piece');

      await type(tester, 'Product Name', 'Phone X');
      await type(tester, 'Category', 'Phones');
      await type(tester, 'SKU', 'PX');
      await type(tester, 'Selling Price', '20000');
      await type(tester, 'Warranty (months)', '12');
      await reveal(tester, serialSwitch);
      await tester.tap(serialSwitch);
      await tester.pumpAndSettle();
      final variantsNote = find.text('Variants can\'t be used while serial numbers are tracked.');
      await reveal(tester, variantsNote);
      expect(variantsNote, findsOneWidget, reason: 'the variants editor gives way');

      // Two serials, pasted at once; a repeat is refused in the sheet.
      final addSerials = find.byKey(const ValueKey('addSerialsButton'));
      await reveal(tester, addSerials);
      await tester.tap(addSerials);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('serialEntryField')), 'IMEI-1\nIMEI-2\nimei-1');
      await tester.tap(find.byKey(const ValueKey('serialEntryAdd')));
      await tester.pumpAndSettle();
      expect(find.text('imei-1 is already added'), findsOneWidget);
      await tester.tap(find.text('Done (2)'));
      await tester.pumpAndSettle();

      expect(await textOf(tester, 'Stock Quantity'), '2', reason: 'stock is the serial count');
      expect(tester.widget<TextField>(field('Stock Quantity').first).readOnly, isTrue);
      await reveal(tester, find.text('IMEI-2'));
      expect(find.text('IMEI-2'), findsOneWidget);

      await save(tester, 'Add Product');
      expect(find.text(kBelowScreen), findsOneWidget, reason: 'saved and closed');
      final saved = (await tester.runAsync(() => isar.products.where().findFirst()))!;
      expect((saved.trackSerials, saved.warrantyMonths, saved.stockQty), (true, 12, 2.0));
      final units = (await tester.runAsync(() => SerialService.ofProduct(isar, saved.id)))!;
      expect(units.map((u) => u.serial), ['IMEI-1', 'IMEI-2']);
    });

    testWidgets('editing a tracked product: remove one serial, the stock follows', (tester) async {
      late Isar isar;
      late Product phone;
      await tester.runAsync(() async {
        isar = await openTestIsar('form_serials_edit');
        await isar.writeTxn(() async {
          final id = await isar.products.put(Product(
              name: 'Phone X', sku: 'PX', category: 'Phones', sellingPrice: 20000, trackSerials: true, warrantyMonths: 6));
          await SerialService.add(isar, id, ['A1', 'A2', 'A3']);
          phone = (await isar.products.get(id))!;
        });
      });
      await pumpScreen(tester, isar: isar, screen: ProductFormScreen(product: phone));

      expect(await textOf(tester, 'Stock Quantity'), '3');
      expect(await textOf(tester, 'Warranty (months)'), '6');
      await reveal(tester, find.text('A2'));
      final removeA2 = find.descendant(
          of: find.ancestor(of: find.text('A2'), matching: find.byType(Row)).first, matching: find.byType(IconButton));
      await tester.tap(removeA2);
      await tester.pump();
      expect(await textOf(tester, 'Stock Quantity'), '2');

      await save(tester, 'Update Product');
      final units = (await tester.runAsync(() => SerialService.ofProduct(isar, phone.id)))!;
      expect({for (final u in units) u.serial: u.status},
          {'A1': SerialStatus.inStock, 'A2': SerialStatus.removed, 'A3': SerialStatus.inStock});
      expect((await tester.runAsync(() => isar.products.get(phone.id)))!.stockQty, 2);
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
