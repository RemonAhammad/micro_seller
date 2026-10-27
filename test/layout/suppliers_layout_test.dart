// Layout of the Suppliers and Purchases screens under the Display size and
// Text size settings: from a 320 dp layout at 150% text up to a 411 dp phone,
// nothing overflows or is cut off, an amount is never split across lines or
// ellipsized, and no word of a name breaks across lines. At 100% text on a
// 360 dp or larger phone, rows keep the layout they had.
import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/suppliers/presentation/purchase_detail_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/purchase_form_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/purchase_list_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/supplier_detail_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/supplier_form_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/supplier_list_screen.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_detail_providers.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_provider.dart';
import 'package:micro_seller/shared/widgets/app_button.dart';

import '../support/isar_core.dart';
import '../support/layout_harness.dart';

const _longName = 'Mohammad Abdur Rahman Chowdhury Trading Co.';
const _email = 'mohammad.abdur.rahman.chowdhury@tradingcompany.com.bd';
const _big = 12345678.9;

Supplier _bigSupplier() => Supplier(
      id: 1,
      name: _longName,
      company: 'Chowdhury & Sons Wholesale Distributors Ltd.',
      phone: '+880 1712-345678',
      email: _email,
      address: 'House 12, Road 5, Block C, Mirpur-10, Dhaka 1216, Bangladesh',
      notes: 'Delivers on Tuesdays only; call ahead before 10 AM.',
      totalPurchases: 12345,
      totalPaid: _big,
      totalDue: _big,
    );
Supplier _plainSupplier() => Supplier(id: 2, name: 'Rahim');
Supplier _smallSupplier() => Supplier(
      id: 3,
      name: 'Karim Traders',
      company: 'Karim',
      phone: '01712345678',
      totalPurchases: 3,
      totalPaid: 5000,
      totalDue: 1250.5,
    );

List<Product> _products() => [
      Product(
        id: 1,
        name: 'Premium Basmati Rice (Extra Long Grain) 25 kg Family Pack',
        sku: 'RICE-BASMATI-XL-25KG-000123456',
        sellingPrice: _big,
        costPrice: _big,
        stockQty: 12345,
        supplierId: 1,
      ),
      Product(
        id: 2,
        name: 'Soybean Oil 5 L',
        sku: 'OIL-5L',
        sellingPrice: 900,
        costPrice: 850,
        supplierId: 1,
      ),
      for (var i = 3; i < 9; i++)
        Product(
          id: i,
          name: 'Product number $i with a fairly long descriptive name',
          sku: 'SKU-$i-LONG-CODE-0000$i',
          sellingPrice: 1234.5 * i,
          costPrice: 999.99 * i,
          stockQty: 100 * i,
          supplierId: i.isOdd ? 1 : 3,
        ),
    ];

List<StockMovement> _movements() => [
      StockMovement(
        id: 1,
        productId: 1,
        productName:
            'Premium Basmati Rice (Extra Long Grain) 25 kg Family Pack',
        type: StockMovementType.restock,
        qty: 12345,
        supplierId: 1,
        createdAt: DateTime(2026, 10, 19, 22, 30),
      ),
      StockMovement(
        id: 2,
        productId: 2,
        productName: 'Soybean Oil 5 L',
        type: StockMovementType.restock,
        qty: 5,
        supplierId: 1,
        createdAt: DateTime(2026, 10, 18, 9, 5),
      ),
    ];

/// Six long-named lines of 1250 each, nothing paid, a long reference.
Purchase _bigPurchase() => Purchase(
      id: 1,
      supplierId: 1,
      supplierName: _longName,
      items: [
        for (final p in _products().take(6))
          PurchaseItem(
            productId: p.id,
            productName: p.name,
            qty: 1250,
            unitCost: 9876.54,
            totalCost: 9876.54 * 1250,
          ),
      ],
      totalAmount: _big,
      paymentMethod: PurchasePaymentMethod.bkash,
      notes: 'Paid the courier separately; two cartons were damaged.',
      referenceNumber: 'INV-2026-000123456789-CHOWDHURY',
      createdAt: DateTime(2026, 10, 19, 22, 30),
    );
Purchase _paidPurchase() => Purchase(
      id: 2,
      items: [
        PurchaseItem(
            productId: 3,
            productName: 'Sugar',
            qty: 1,
            unitCost: 250,
            totalCost: 250),
      ],
      totalAmount: 250,
      amountPaid: 250,
      createdAt: DateTime(2026, 10, 1, 8),
    );
Purchase _bulkPurchase() => Purchase(
      id: 3,
      supplierId: 3,
      supplierName: 'Karim Traders',
      items: [
        PurchaseItem(
            productId: 4,
            productName: 'Flour',
            qty: 12345,
            unitCost: 1000.5,
            totalCost: 12351172.25),
      ],
      totalAmount: 12351172.25,
      amountPaid: 6789.5,
      paymentMethod: PurchasePaymentMethod.other,
      createdAt: DateTime(2026, 10, 2, 8),
    );

const _eps = 0.5;
final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _amount = RegExp(r'৳-?[\d,]+(\.\d+)?');

/// No amount is ellipsized or split across lines, and no word of a
/// paragraph drawn in Roboto (measured as on a phone) is broken across
/// lines, other than [unbreakable] ones longer than any line. Labels the
/// app styles without a font family are drawn in the far wider test font
/// here, so they're left out.
void _expectWholeWords(WidgetTester tester, String where,
    {Set<String> unbreakable = const {}}) {
  requireRoboto();
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final text = p.text.toPlainText();
    if (text.isEmpty || !p.hasSize) continue;
    if (text.contains('৳')) {
      expect(p.didExceedMaxLines, isFalse,
          reason: '$where: "$text" ellipsized');
    }
    if (p.text.style?.fontFamily != 'Roboto' || unbreakable.contains(text)) {
      continue;
    }
    final lineTops = {
      for (final box in p.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length)))
        box.top.roundToDouble(),
    }.toList()
      ..sort();
    for (final top in lineTops.skip(1)) {
      final at = p.getPositionForOffset(Offset(0, top + 2)).offset;
      if (at <= 0 || at >= text.length) continue;
      final inAmount =
          _amount.allMatches(text).any((m) => m.start < at && at < m.end);
      final inWord =
          _wordChar.hasMatch(text[at - 1]) && _wordChar.hasMatch(text[at]);
      expect(inAmount || inWord, isFalse,
          reason: '$where: "${text.substring(0, at)}|${text.substring(at)}"');
    }
  }
}

/// [text]'s field label is shown whole, not ellipsized.
void _expectFullLabel(WidgetTester tester, String text, String where) {
  for (final p in tester.renderObjectList<RenderParagraph>(find.text(text))) {
    expect(p.didExceedMaxLines, isFalse, reason: '$where: "$text" cut off');
  }
}

/// [a] and [b] sit side by side on one line, [b] ending at [right].
void _expectBeside(WidgetTester tester, Finder a, Finder b, double right,
    String where) {
  final ra = tester.getRect(a);
  final rb = tester.getRect(b);
  expect(rb.left, greaterThan(ra.right - _eps), reason: where);
  expect(rb.top, lessThan(ra.bottom), reason: where);
  expect(rb.right, closeTo(right, _eps), reason: where);
}

/// Every layout width and text scale, each pumped fresh by [pump] and
/// checked by [check]; the tree is torn down after each.
Future<void> _sweep(
  WidgetTester tester,
  Widget Function() build,
  Future<void> Function(String where, double width, double textScale) check, {
  List<Override> overrides = const [],
  Future<void> Function()? afterEach,
}) async {
  addTearDown(tester.view.reset);
  for (final width in kLayoutWidths) {
    for (final t in kLayoutTextScales) {
      setLayoutScreen(tester, width);
      await pumpLayoutApp(tester, build(), textScale: t, overrides: overrides);
      // List entrance animations.
      await tester.pump(const Duration(seconds: 1));
      await check('${width.toInt()} dp at ${t}x text', width, t);
      await afterEach?.call();
      await tester.pumpWidget(const SizedBox());
    }
  }
}

/// [_sweep] on tablets and in Split View ([forEachTabletLayout]): each
/// tablet window, portrait and landscape, and each Split View width, at 100%
/// and 150% text, beside the sidebar the window gets in the app.
Future<void> _sweepTablets(
  WidgetTester tester,
  Widget Function() build,
  Future<void> Function(String where, Size window, double textScale) check, {
  List<Override> overrides = const [],
  Future<void> Function()? afterEach,
}) =>
    forEachTabletLayout(tester, (where, window, t) async {
      await pumpLayoutApp(tester, build(), textScale: t, overrides: overrides);
      // List entrance animations.
      await tester.pump(const Duration(seconds: 1));
      await check(where, window, t);
      await afterEach?.call();
    });

/// Frames enough for a route (a sheet, a dialog) to finish opening or
/// closing.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs the database's real work (the test's fake clock doesn't) until
/// [finder] shows up.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 2000 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump();
  }
  expect(finder, findsWidgets);
  await _pumpFrames(tester);
}

/// Lets the database finish every read a screen started (a stream's first
/// value, a picker's query) before the test moves on: a read left waiting
/// on this test's fake clock would never finish, and would hold up the
/// next test's reads and closing the database.
Future<void> _settleDb(WidgetTester tester, Isar isar) async {
  var done = false;
  unawaited(isar.suppliers.count().then((_) => done = true));
  for (var i = 0; i < 2000 && !done; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump();
  }
  expect(done, isTrue, reason: 'the database never finished');
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump();
  }
}

Finder _button<T>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

void main() {
  final coreLibrary = isarCoreLibrary();
  Directory? dir;
  Isar? isar;

  setUpAll(() async {
    await loadRoboto();
    CurrencyFormatter.setSymbol('৳');
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_suppliers');
    isar = await Isar.open(
      kIsarSchemas,
      directory: dir!.path,
      name: 'suppliers_layout',
      inspector: false,
    );
    await isar!.writeTxn(() async {
      await isar!.suppliers
          .putAll([_bigSupplier(), _plainSupplier(), _smallSupplier()]);
      await isar!.products.putAll(_products());
      await isar!.stockMovements.putAll(_movements());
      await isar!.purchases
          .putAll([_bigPurchase(), _paidPurchase(), _bulkPurchase()]);
    });
  });

  tearDownAll(() async {
    await isar?.close(deleteFromDisk: true).timeout(const Duration(minutes: 1));
    await dir?.delete(recursive: true);
  });

  testWidgets('supplier list', (tester) async {
    requireRoboto();
    final suppliers = [_bigSupplier(), _plainSupplier(), _smallSupplier()];
    String due(Supplier s) => 'Due: ${CurrencyFormatter.format(s.totalDue)}';
    await _sweep(tester, () => const SupplierListScreen(),
        overrides: [
          suppliersProvider.overrideWithValue(AsyncValue.data(suppliers)),
        ], (where, width, t) async {
      expectCleanLayout(tester, where);
      for (final s in suppliers) {
        expectWholeText(tester, find.text(s.name), where);
      }
      expectWholeText(tester, find.text(due(_bigSupplier())), where);
      _expectWholeWords(tester, where);
      if (width >= 360 && t == 1.0) {
        // The due at the end of the supplier's row, as before.
        for (final s in [_bigSupplier(), _smallSupplier()]) {
          final row = find
              .ancestor(of: find.text(s.name), matching: find.byType(InkWell))
              .first;
          _expectBeside(tester, find.text(s.name), find.text(due(s)),
              tester.getRect(row).right, where);
        }
      }
    });
  });

  testWidgets('supplier form, filled in and failing validation',
      (tester) async {
    requireRoboto();
    await _sweep(tester, () => SupplierFormScreen(supplier: _bigSupplier()),
        (where, _, _) async {
      expectCleanLayout(tester, where);
      _expectWholeWords(tester, where);
    });
    await _sweep(tester, () => const SupplierFormScreen(),
        (where, _, _) async {
      final save = find.byType(AppButton);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expectCleanLayout(tester, '$where, invalid');
      expectWholeText(tester, find.textContaining('Name'), '$where, invalid');
    });
  });

  group('supplier detail', () {
    List<Override> overrides(Supplier s, List<Product> products,
            List<StockMovement> movements) =>
        [
          supplierByIdProvider(s.id).overrideWithValue(AsyncValue.data(s)),
          supplierProductsProvider(s.id)
              .overrideWithValue(AsyncValue.data(products)),
          supplierStockMovementsProvider(s.id)
              .overrideWithValue(AsyncValue.data(movements)),
        ];

    testWidgets('with long details, big amounts and history',
        (tester) async {
      requireRoboto();
      final s = _bigSupplier();
      final products = _products().where((p) => p.supplierId == 1).toList();
      await _sweep(tester, () => const SupplierDetailScreen(supplierId: 1),
          overrides: overrides(s, products, _movements()),
          (where, width, t) async {
        expectCleanLayout(tester, where);
        for (final text in [
          s.company,
          s.phone,
          _email,
          s.address,
          '12345',
          CurrencyFormatter.format(_big),
          'Pay Due',
        ]) {
          expectWholeText(tester, find.text(text), where);
        }
        _expectWholeWords(tester, where, unbreakable: {_email});
        // New Purchase and Pay Due don't overlap.
        final pair = tester.getRect(find.byType(ButtonPair));
        final buttons = [
          for (final finder in [
            _button<FilledButton>('New Purchase'),
            _button<OutlinedButton>('Pay Due'),
          ])
            tester.getRect(finder),
        ];
        expect(buttons[0].overlaps(buttons[1]), isFalse, reason: where);
        for (final b in buttons) {
          expect(pair.contains(b.center), isTrue, reason: where);
        }
        if (width >= 360 && t == 1.0) {
          // Stats as label … value lines, as before.
          final card = tester.getRect(find
              .ancestor(of: find.text('Paid'), matching: find.byType(Container))
              .first);
          _expectBeside(tester, find.text('Paid'),
              find.text(CurrencyFormatter.format(_big)).first,
              card.right - 16, where);
        }

        await tester.ensureVisible(find.text('Pay Due'));
        await _pumpFrames(tester);
        await tester.tap(find.text('Pay Due'));
        await _pumpFrames(tester);
        expectCleanLayout(tester, '$where, pay dialog');
        expectWholeText(
            tester,
            find.text('Due: ${CurrencyFormatter.format(_big)}'),
            '$where, pay dialog');
        await tester.tap(find.text('Cancel'));
        await _pumpFrames(tester);

        // The restock history at the end of the page: the quantity stays
        // inside its badge.
        await tester.scrollUntilVisible(find.text('+12345'), 200,
            scrollable: find.byType(Scrollable).first);
        expectCleanLayout(tester, '$where, restocks');
        expectWholeText(tester, find.text('+12345'), '$where, restocks');
        _expectWholeWords(tester, '$where, restocks', unbreakable: {_email});
        final qty = tester.getRect(find.text('+12345'));
        final badge = tester.getRect(find
            .ancestor(of: find.text('+12345'), matching: find.byType(Container))
            .first);
        expect(badge.contains(qty.topLeft) && badge.contains(qty.bottomRight),
            isTrue,
            reason: '$where, restocks');
      });
    });

    testWidgets('with nothing but a name', (tester) async {
      requireRoboto();
      await _sweep(tester, () => const SupplierDetailScreen(supplierId: 2),
          overrides: overrides(_plainSupplier(), [], []),
          (where, width, t) async {
        expectCleanLayout(tester, where);
        expectWholeText(tester, find.text('Restock Activity'), where);
        _expectWholeWords(tester, where);
      });
    });

    testWidgets('with an ordinary supplier', (tester) async {
      requireRoboto();
      final s = _smallSupplier();
      await _sweep(tester, () => const SupplierDetailScreen(supplierId: 3),
          overrides: overrides(s, [], []), (where, width, t) async {
        expectCleanLayout(tester, where);
        _expectWholeWords(tester, where);
        if (width >= 360 && t == 1.0) {
          // Company and phone as label … value lines, as before.
          final card = tester.getRect(find
              .ancestor(of: find.text('Company'), matching: find.byType(Container))
              .first);
          _expectBeside(tester, find.text('Company'), find.text('Karim'),
              card.right - 16, where);
          final call = tester.getRect(find
              .ancestor(of: find.text(s.phone), matching: find.byType(Row))
              .first);
          _expectBeside(tester, find.text('Phone'), find.text(s.phone),
              call.right - 8 - 18, where);
        }
      });
    });
  });

  testWidgets('purchase list', (tester) async {
    requireRoboto();
    final purchases = [_bigPurchase(), _paidPurchase(), _bulkPurchase()];
    await _sweep(tester, () => const PurchaseListScreen(),
        overrides: [
          purchasesProvider.overrideWithValue(AsyncValue.data(purchases)),
        ], (where, width, t) async {
      expectCleanLayout(tester, where);
      for (final text in [
        _longName,
        'Karim Traders',
        CurrencyFormatter.format(_big),
        'Due: ${CurrencyFormatter.format(_big)}',
        'Paid',
      ]) {
        expectWholeText(tester, find.text(text), where);
      }
      _expectWholeWords(tester, where);
      if (width >= 360 && t == 1.0) {
        // The total at the end of the supplier's line, as before.
        for (final (name, total) in [
          ('No supplier', CurrencyFormatter.format(250)),
          ('Karim Traders', CurrencyFormatter.format(12351172.25)),
        ]) {
          final card = tester.getRect(find
              .ancestor(of: find.text(name), matching: find.byType(InkWell))
              .first);
          _expectBeside(
              tester, find.text(name), find.text(total), card.right - 14, where);
        }
      }
    });
    await _sweep(tester, () => const PurchaseListScreen(),
        overrides: [
          purchasesProvider
              .overrideWithValue(const AsyncValue.data(<Purchase>[])),
        ], (where, _, _) async {
      expectCleanLayout(tester, '$where, empty');
      expectWholeText(tester, find.text('No purchases yet'), '$where, empty');
    });
  });

  testWidgets('purchase detail', (tester) async {
    if (isar == null) return markTestSkipped('no Isar core library');
    requireRoboto();
    final db = isar!;
    for (final p in [_bigPurchase(), _paidPurchase(), _bulkPurchase()]) {
      await _sweep(tester, () => PurchaseDetailScreen(purchaseId: p.id),
          overrides: [isarProvider.overrideWithValue(AsyncValue.data(db))],
          afterEach: () => _settleDb(tester, db), (where, width, t) async {
        where = '$where, purchase ${p.id}';
        expectCleanLayout(tester, where);
        for (final text in [
          '${p.items.first.qty}',
          p.items.first.productName,
          CurrencyFormatter.format(p.totalAmount),
          if (p.referenceNumber.isNotEmpty) p.referenceNumber,
        ]) {
          expectWholeText(tester, find.text(text), where);
        }
        // A reference code has no place to break; it wraps anywhere.
        _expectWholeWords(tester, where, unbreakable: {p.referenceNumber});
        if (width >= 360 && t == 1.0 && p.id == 2) {
          // The line total at the end of the item's row, as before.
          final row = tester.getRect(find
              .ancestor(of: find.text('Sugar'), matching: find.byType(Padding))
              .first);
          _expectBeside(tester, find.text('Sugar'),
              find.text(CurrencyFormatter.format(250)).first,
              row.right - 12, where);
        }
        if (p.balanceDue > 0) {
          await tester.ensureVisible(find.text('Record Payment'));
          await _pumpFrames(tester);
          await tester.tap(find.text('Record Payment'));
          await _pumpFrames(tester);
          expectCleanLayout(tester, '$where, pay dialog');
          await tester.tap(find.text('Cancel'));
          await _pumpFrames(tester);
        }
      });
    }
  });

  testWidgets('purchase form, its pickers and its items', (tester) async {
    if (isar == null) return markTestSkipped('no Isar core library');
    requireRoboto();
    final db = isar!;
    await _sweep(tester, () => const PurchaseFormScreen(supplierId: 1),
        overrides: [isarProvider.overrideWithValue(AsyncValue.data(db))],
        afterEach: () => _settleDb(tester, db), (where, width, t) async {
      await _pumpUntilFound(tester, find.text(_longName));
      expectCleanLayout(tester, where);
      _expectWholeWords(tester, where);
      _expectFullLabel(tester, 'Amount Paid', where);

      // The product picker, filtered to the supplier's products.
      await tester.tap(_button<TextButton>('Add'));
      await _pumpUntilFound(tester, _button<FilledButton>('Add'));
      expectCleanLayout(tester, '$where, products');
      final chip = tester.getRect(find.byType(FilterChip));
      expect(chip.right, lessThanOrEqualTo(width - 16 + _eps),
          reason: '$where, products');
      _expectWholeWords(tester, '$where, products');
      // Three products added. On a 320 dp layout with large text the next
      // Add can be below the bottom of the screen: the list scrolls it into
      // view first (only when it isn't), or the tap would hit nothing.
      for (var i = 0; i < 3; i++) {
        final add = _button<FilledButton>('Add').first;
        await Scrollable.ensureVisible(tester.element(add),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        await tester.pump();
        await tester.tap(add);
        await tester.pump();
      }
      // Every tap landed: the picker counts three.
      expect(find.text('3 items'), findsOneWidget,
          reason: '$where, products added');
      expectCleanLayout(tester, '$where, products added');
      _expectWholeWords(tester, '$where, products added');
      await tester.tap(find.text('Done'));
      await _pumpFrames(tester);

      // The items, the big one first.
      where = '$where, items';
      expectCleanLayout(tester, where);
      expectWholeText(
          tester, find.text(CurrencyFormatter.format(_big)), where);
      _expectWholeWords(tester, where);
      _expectFullLabel(tester, 'Unit Cost', where);
      _expectFullLabel(tester, 'Amount Paid', where);
      final costs = find.widgetWithText(TextField, 'Unit Cost');
      expect(costs, findsNWidgets(3), reason: where);
      if (width >= 360 && t == 1.0) {
        // Pay Full beside the field and each total beside its unit cost
        // field, as before.
        final field = tester.getRect(find.byType(TextFormField).first);
        expect(tester.getRect(_button<TextButton>('Pay Full')).left,
            greaterThan(field.right),
            reason: where);
        final totals =
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 70);
        expect(totals, findsNWidgets(3), reason: where);
        for (var i = 0; i < 3; i++) {
          final cost = tester.getRect(costs.at(i));
          final total = tester.getRect(totals.at(i));
          expect(total.left, closeTo(cost.right + 8, _eps), reason: where);
          expect(total.center.dy, closeTo(cost.center.dy, 1), reason: where);
        }
      }

      // The supplier picker.
      expect(find.byType(FilterChip), findsNothing, reason: where);
      await tester.tap(find.text(_longName));
      await _pumpUntilFound(tester, find.text('Rahim'));
      expectCleanLayout(tester, '$where, suppliers');
      _expectWholeWords(tester, '$where, suppliers');
      await tester.tap(find.text('Rahim'));
      await _pumpFrames(tester);
      expectCleanLayout(tester, '$where, supplier picked');
    });
  });

  // iPads and Android tablets in both orientations, and the app's window in
  // Split View: beside the 56 dp rail below 600 dp, the 200 dp sidebar from
  // there.
  group('on tablets and in Split View', () {
    testWidgets('the supplier list and form', (tester) async {
      requireRoboto();
      final suppliers = [_bigSupplier(), _plainSupplier(), _smallSupplier()];
      await _sweepTablets(tester, () => const SupplierListScreen(),
          overrides: [
            suppliersProvider.overrideWithValue(AsyncValue.data(suppliers)),
          ], (where, window, t) async {
        expectCleanLayout(tester, where);
        for (final s in suppliers) {
          expectWholeText(tester, find.text(s.name), where);
        }
        expectWholeText(tester,
            find.text('Due: ${CurrencyFormatter.format(_big)}'), where);
        _expectWholeWords(tester, where);
      });
      await _sweepTablets(tester, () => SupplierFormScreen(supplier: _bigSupplier()),
          (where, window, t) async {
        expectCleanLayout(tester, '$where, form');
        _expectWholeWords(tester, '$where, form');
      });
    });

    testWidgets('supplier detail and its pay dialog', (tester) async {
      requireRoboto();
      final s = _bigSupplier();
      await _sweepTablets(tester, () => const SupplierDetailScreen(supplierId: 1),
          overrides: [
            supplierByIdProvider(s.id).overrideWithValue(AsyncValue.data(s)),
            supplierProductsProvider(s.id).overrideWithValue(AsyncValue.data(
                _products().where((p) => p.supplierId == 1).toList())),
            supplierStockMovementsProvider(s.id)
                .overrideWithValue(AsyncValue.data(_movements())),
          ], (where, window, t) async {
        expectCleanLayout(tester, where);
        for (final text in [
          s.company,
          s.phone,
          _email,
          s.address,
          CurrencyFormatter.format(_big),
        ]) {
          expectWholeText(tester, find.text(text), where);
        }
        _expectWholeWords(tester, where, unbreakable: {_email});
        // New Purchase and Pay Due side by side or stacked, never
        // overlapping.
        final buttons = [
          tester.getRect(_button<FilledButton>('New Purchase')),
          tester.getRect(_button<OutlinedButton>('Pay Due')),
        ];
        expect(buttons[0].overlaps(buttons[1]), isFalse, reason: where);

        await tester.ensureVisible(find.text('Pay Due'));
        await _pumpFrames(tester);
        await tester.tap(find.text('Pay Due'));
        await _pumpFrames(tester);
        expectCleanLayout(tester, '$where, pay dialog');
        expectWholeText(tester,
            find.text('Due: ${CurrencyFormatter.format(_big)}'),
            '$where, pay dialog');
        await tester.enterText(find.byType(TextField), '12345678.9');
        await tester.pump();
        expectCleanLayout(tester, '$where, pay dialog');
        await tester.tap(find.text('Cancel'));
        await _pumpFrames(tester);
      });
    });

    testWidgets('the purchase list', (tester) async {
      requireRoboto();
      final purchases = [_bigPurchase(), _paidPurchase(), _bulkPurchase()];
      await _sweepTablets(tester, () => const PurchaseListScreen(),
          overrides: [
            purchasesProvider.overrideWithValue(AsyncValue.data(purchases)),
          ], (where, window, t) async {
        expectCleanLayout(tester, where);
        for (final text in [
          _longName,
          CurrencyFormatter.format(_big),
          'Due: ${CurrencyFormatter.format(_big)}',
        ]) {
          expectWholeText(tester, find.text(text), where);
        }
        _expectWholeWords(tester, where);
      });
    });

    testWidgets('purchase detail and its pay dialog', (tester) async {
      if (isar == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final db = isar!;
      final p = _bigPurchase();
      await _sweepTablets(tester, () => PurchaseDetailScreen(purchaseId: p.id),
          overrides: [isarProvider.overrideWithValue(AsyncValue.data(db))],
          afterEach: () => _settleDb(tester, db), (where, window, t) async {
        await _pumpUntilFound(tester, find.text(p.referenceNumber));
        expectCleanLayout(tester, where);
        for (final text in [
          '${p.items.first.qty}',
          p.items.first.productName,
          CurrencyFormatter.format(p.totalAmount),
          p.referenceNumber,
        ]) {
          expectWholeText(tester, find.text(text), where);
        }
        _expectWholeWords(tester, where, unbreakable: {p.referenceNumber});
        await tester.ensureVisible(find.text('Record Payment'));
        await _pumpFrames(tester);
        await tester.tap(find.text('Record Payment'));
        await _pumpFrames(tester);
        expectCleanLayout(tester, '$where, pay dialog');
        await tester.tap(find.text('Cancel'));
        await _pumpFrames(tester);
      });
    });

    testWidgets('the purchase form with an item', (tester) async {
      if (isar == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final db = isar!;
      await _sweepTablets(tester, () => const PurchaseFormScreen(supplierId: 1),
          overrides: [isarProvider.overrideWithValue(AsyncValue.data(db))],
          afterEach: () => _settleDb(tester, db), (where, window, t) async {
        await _pumpUntilFound(tester, find.text(_longName));
        expectCleanLayout(tester, where);
        _expectWholeWords(tester, where);
        _expectFullLabel(tester, 'Amount Paid', where);

        // The product picker: the big product added.
        await tester.tap(_button<TextButton>('Add'));
        await _pumpUntilFound(tester, _button<FilledButton>('Add'));
        expectCleanLayout(tester, '$where, products');
        _expectWholeWords(tester, '$where, products');
        await tester.tap(_button<FilledButton>('Add').first);
        await tester.pump();
        expect(find.text('1 item'), findsOneWidget, reason: where);
        await tester.tap(find.text('Done'));
        await _pumpFrames(tester);

        where = '$where, items';
        expectCleanLayout(tester, where);
        expectWholeText(
            tester, find.text(CurrencyFormatter.format(_big)), where);
        _expectWholeWords(tester, where);
        _expectFullLabel(tester, 'Unit Cost', where);
        _expectFullLabel(tester, 'Amount Paid', where);
      });
    });
  });
}
