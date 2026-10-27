// Layout of the Expenses, Cash Register and Inventory screens under the
// Display size / Text size settings: from the narrowest layout the Display
// size allows (320 dp) up to a large phone font (150%), with worst-case data
// (long names, big amounts, many variants), every screen, menu, dialog and
// sheet lays out without overflowing and draws every amount whole. At 100%
// text on a 360 / 411 dp phone, rows that fit look as they did before.
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/date_formatter.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/category.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/cash_register/presentation/cash_register_screen.dart';
import 'package:micro_seller/features/cash_register/providers/cash_register_provider.dart';
import 'package:micro_seller/features/categories/providers/category_provider.dart';
import 'package:micro_seller/features/expenses/presentation/expense_form_screen.dart';
import 'package:micro_seller/features/expenses/presentation/expense_list_screen.dart';
import 'package:micro_seller/features/expenses/presentation/widgets/expense_card.dart';
import 'package:micro_seller/features/expenses/providers/expense_provider.dart';
import 'package:micro_seller/features/inventory/presentation/inventory_screen.dart';
import 'package:micro_seller/features/inventory/presentation/stock_adjustment_screen.dart';
import 'package:micro_seller/features/inventory/presentation/widgets/stock_movement_tile.dart';
import 'package:micro_seller/features/inventory/providers/inventory_provider.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../support/isar_core.dart';
import '../support/layout_harness.dart';

const _eps = 0.01;

/// A long business name, as sellers type them.
const _long = 'Mohammad Abdur Rahman Chowdhury Trading Co.';

/// A big amount: "৳12,345,678.9".
const _big = 12345678.9;

// ─── Errors and text checks ─────────────────────────────────────────────────

/// Overflows reported from these shared widgets belong to them, not to these
/// screens, and are covered by their own tests. AppButton's label has no font
/// family, so tests draw it in the 1-em-square test font, far wider than
/// Roboto: without a Flexible label it overflows here even at 100%.
const _knownForeign = ['lib/shared/widgets/app_button.dart'];

bool _isKnownForeign(FlutterErrorDetails e) {
  final text = e.toString();
  return text.contains('overflowed') && _knownForeign.any(text.contains);
}

/// Runs [body] and returns the errors Flutter reported meanwhile (overflows
/// included), except the known ones of shared widgets.
Future<List<String>> _errorsDuring(Future<void> Function() body) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return [
    for (final e in errors)
      if (!_isKnownForeign(e)) e.toString(),
  ];
}

/// Every paragraph [finder] matches is drawn in full: not ellipsized and not
/// cut off by its box. (A FittedBox may shrink it.)
void _expectWhole(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder).toList();
  expect(paragraphs, isNotEmpty, reason: '$where: $finder');
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    expect(p.didExceedMaxLines, isFalse, reason: '$where: "$text" truncated');
    expect(
      p.size.width,
      greaterThanOrEqualTo(p.textSize.width - _eps),
      reason: '$where: "$text" cut off',
    );
    expect(
      p.size.height,
      greaterThanOrEqualTo(p.textSize.height - _eps),
      reason: '$where: "$text" cut off',
    );
  }
}

/// Every widget [finder] matches is drawn between [left] and [right].
void _expectWithin(
  WidgetTester tester,
  Finder finder,
  double left,
  double right,
  String where,
) {
  final count = finder.evaluate().length;
  expect(count, greaterThan(0), reason: '$where: $finder');
  for (var i = 0; i < count; i++) {
    final r = tester.getRect(finder.at(i));
    expect(r.left, greaterThanOrEqualTo(left - _eps), reason: '$where: $r');
    expect(r.right, lessThanOrEqualTo(right + _eps), reason: '$where: $r');
  }
}

/// [finder] is drawn at its laid-out size: no FittedBox shrank it.
bool _fullSize(WidgetTester tester, Finder finder) =>
    (tester.getRect(finder).width - tester.getSize(finder).width).abs() < _eps;

/// [finder]'s paragraph is a single line: it didn't have to wrap.
bool _oneLine(WidgetTester tester, Finder finder) {
  final p = tester.renderObject<RenderParagraph>(finder);
  return p.size.width >= p.getMaxIntrinsicWidth(double.infinity) - _eps;
}

/// [a] and [b] sit on the same line.
bool _sameLine(WidgetTester tester, Finder a, Finder b) =>
    (tester.getRect(a).center.dy - tester.getRect(b).center.dy).abs() < 2;

/// The column [finder]'s text sits in.
Rect _column(WidgetTester tester, Finder finder) => tester.getRect(
  find.ancestor(of: finder, matching: find.byType(Column)).first,
);

/// The nearest Container around [finder]: a card or tile's box.
Rect _box(WidgetTester tester, Finder finder) => tester.getRect(
  find.ancestor(of: finder, matching: find.byType(Container)).first,
);

/// Every (width, text scale) the screens must lay out at.
Iterable<(double, double)> get _combos sync* {
  for (final width in kLayoutWidths) {
    for (final t in kLayoutTextScales) {
      yield (width, t);
    }
  }
}

/// Pumps [home] at [width] dp and [textScale] the way the app shows it,
/// then lets it settle.
Future<void> _show(
  WidgetTester tester,
  Widget home, {
  required double width,
  required double textScale,
  double height = 800,
  List<Override> overrides = const [],
}) async {
  setLayoutScreen(tester, width, height: height);
  await pumpLayoutApp(tester, home, textScale: textScale, overrides: overrides);
  await tester.pumpAndSettle();
}

// ─── Data ───────────────────────────────────────────────────────────────────

DateTime get _thisMonth {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1, 10, 30);
}

List<Expense> _bigExpenses() => [
  for (final c in ExpenseCategory.values)
    Expense(
      id: c.index + 1,
      title: '$_long courier bill for October',
      amount: _big,
      category: c,
      date: _thisMonth,
      notes: 'Paid in cash to $_long at the Chattogram warehouse gate',
    ),
];

List<CashRegister> _registers({bool open = true}) {
  const amount = _big;
  final now = DateTime.now();
  return [
    if (open)
      CashRegister(
        id: 100,
        openingAmount: amount,
        totalCashIn: amount * 8,
        totalCashOut: amount,
        openedAt: now,
      ),
    for (var i = 0; i < 3; i++)
      CashRegister(
        id: i + 1,
        openingAmount: amount,
        totalCashIn: amount * 8,
        totalCashOut: amount,
        // Short, then over, by a big amount: the difference row shows.
        closingAmount: i.isEven ? 1.5 : amount * 81,
        isClosed: true,
        openedAt: now.subtract(Duration(days: i + 1)),
        closedAt: now.subtract(Duration(days: i + 1)),
      ),
  ];
}

const _comboLabels = [
  'Size: Extra Extra Large / Color: Midnight Blue / Material: Organic Cotton',
  'Size: S / Color: Red / Material: Silk',
  'Size: Medium / Color: Forest Green / Material: Polyester Blend',
];

Product _variantProduct({int id = Isar.autoIncrement, int supplierId = 0}) =>
    Product(
      id: id,
      name: '$_long Premium Cotton T-Shirt Collection',
      sku: 'SKU-MOHAMMAD-ABDUR-RAHMAN-0001234567',
      sellingPrice: _big,
      stockQty: 1234567,
      lowStockThreshold: 100000,
      category: '$_long Apparel',
      supplierId: supplierId,
      variantAttributes: [
        VariantAttribute(
          name: 'Size',
          options: ['S', 'Medium', 'Extra Extra Large'],
        ),
      ],
      variantCombinations: [
        for (var i = 0; i < 6; i++)
          VariantCombination(
            combinationKey: 'k$i',
            displayLabel: _comboLabels[i % 3],
            stockQty: i == 0 ? 0 : 1234567,
            sku: 'SKU-$i',
          ),
      ],
    );

List<Product> _bigProducts() => [
  _variantProduct(id: 1),
  Product(
    id: 2,
    name: '$_long Premium Basmati Rice 25kg Sack',
    sku: 'SKU-MOHAMMAD-ABDUR-RAHMAN-0001234567-RICE-25KG',
    sellingPrice: _big,
    stockQty: 1234567,
    lowStockThreshold: 1234567,
    category: '$_long Category 2',
  ),
  Product(
    id: 3,
    name: 'Oil',
    sellingPrice: 10,
    stockQty: 0,
    lowStockThreshold: 1000000,
  ),
];

List<Category> _longCategories() => [
  for (var i = 0; i < 3; i++) Category(id: i + 1, name: '$_long Category $i'),
];

List<StockMovement> _bigMovements() => [
  for (final type in StockMovementType.values)
    StockMovement(
      id: type.index + 1,
      productId: 1,
      productName: '$_long Premium Cotton T-Shirt (Size: Extra Large)',
      type: type,
      qty: type.index.isEven ? 1234567 : -1234567,
      reason: 'Purchase from $_long Wholesale Supplier Limited',
      createdAt: _thisMonth,
    ),
];

/// The movement history, without a database.
class _MovementPages extends StockMovementPages {
  _MovementPages(this.page);

  final StockMovementPage page;

  @override
  Stream<StockMovementPage> build() => Stream.value(page);
}

List<Override> _inventory(
  List<Product> products, {
  List<Category>? categories,
  List<StockMovement>? movements,
}) => [
  productsProvider.overrideWithValue(AsyncValue.data(products)),
  categoriesProvider.overrideWithValue(
    AsyncValue.data(categories ?? _longCategories()),
  ),
  stockMovementPagesProvider.overrideWith(
    () => _MovementPages(
      StockMovementPage(movements ?? _bigMovements(), hasMore: false),
    ),
  ),
];

void main() {
  final coreLibrary = isarCoreLibrary();
  Directory? dir;
  late Isar isar;
  late int variantId, typicalId;

  setUpAll(() async {
    await loadRoboto();
    // The settings provider loads the symbol from preferences.
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    CurrencyFormatter.setSymbol('৳');
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_money_stock');
    isar = await Isar.open(
      kIsarSchemas,
      directory: dir!.path,
      name: 'money_stock_layout',
      inspector: false,
    );
    await isar.writeTxn(() async {
      final supplierId = await isar.suppliers.put(
        Supplier(
          name: '$_long Wholesale Supplier Limited',
          company: '$_long Imports & Exports Ltd.',
          phone: '+8801712345678',
        ),
      );
      await isar.suppliers.putAll([
        for (var i = 0; i < 12; i++)
          Supplier(name: '$_long Supplier $i', company: '$_long Company $i'),
      ]);
      variantId = await isar.products.put(
        _variantProduct(supplierId: supplierId),
      );
      typicalId = await isar.products.put(
        Product(
          name: 'T-Shirt',
          sku: 'TS-01',
          sellingPrice: 450,
          stockQty: 120,
          variantAttributes: [
            VariantAttribute(name: 'Size', options: ['M', 'L']),
          ],
          variantCombinations: [
            VariantCombination(
              combinationKey: 'Size:M',
              displayLabel: 'Size: M',
              stockQty: 5,
            ),
            VariantCombination(
              combinationKey: 'Size:L',
              displayLabel: 'Size: L',
              stockQty: 12,
            ),
          ],
        ),
      );
    });
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    // Bounded: a read the test clock never let finish must not hang the run.
    await isar
        .close(deleteFromDisk: true)
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
    try {
      await dir?.delete(recursive: true);
    } on FileSystemException {
      // Left in the temp directory.
    }
  });

  group('expenses', () {
    testWidgets('the list lays out at every width and text size', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final amount = CurrencyFormatter.format(_big);
      final total = CurrencyFormatter.format(_big * 5);
      final date = DateFormatter.format(_thisMonth);
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        final errors = await _errorsDuring(
          () => _show(
            tester,
            const ExpenseListScreen(),
            width: width,
            textScale: t,
            overrides: [
              expensesProvider.overrideWithValue(
                AsyncValue.data(_bigExpenses()),
              ),
            ],
          ),
        );
        expect(errors, isEmpty, reason: where);

        // The month's total and entry count stay whole, inside the banner.
        final banner = _box(tester, find.text(total)).deflate(16);
        _expectWhole(tester, find.text(total), where);
        _expectWithin(
          tester,
          find.text(total),
          banner.left,
          banner.right,
          where,
        );
        _expectWithin(tester, find.text('5'), banner.left, banner.right, where);

        // Each card's amount and date stay whole, inside the card.
        final cards = find.byType(ExpenseCard);
        for (var i = 0; i < cards.evaluate().length; i++) {
          final card = tester.getRect(cards.at(i)).deflate(14);
          final cardAmount = find.descendant(
            of: cards.at(i),
            matching: find.text(amount),
          );
          _expectWhole(tester, cardAmount, where);
          _expectWithin(tester, cardAmount, card.left, card.right, where);
          final cardDate = find.descendant(
            of: cards.at(i),
            matching: find.text(date),
          );
          _expectWhole(tester, cardDate, where);
          _expectWithin(tester, cardDate, card.left, card.right, where);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('its empty state and delete dialog lay out', (tester) async {
      addTearDown(tester.view.reset);
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        var errors = await _errorsDuring(
          () => _show(
            tester,
            const ExpenseListScreen(),
            width: width,
            textScale: t,
            overrides: [
              expensesProvider.overrideWithValue(const AsyncValue.data([])),
            ],
          ),
        );
        expect(errors, isEmpty, reason: 'empty, $where');

        errors = await _errorsDuring(() async {
          await _show(
            tester,
            const ExpenseListScreen(),
            width: width,
            textScale: t,
            overrides: [
              expensesProvider.overrideWithValue(
                AsyncValue.data(_bigExpenses()),
              ),
            ],
          );
          await tester.tap(
            find
                .byWidgetPredicate(
                  (w) => w is ThinIcon && w.builder == tabler.Trash.new,
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget, reason: where);
        });
        expect(errors, isEmpty, reason: 'delete dialog, $where');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the form lays out at every width and text size', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final expense = _bigExpenses().first;
      final date = '${_thisMonth.day}/${_thisMonth.month}/${_thisMonth.year}';
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        // Tall enough that the whole form is built.
        final errors = await _errorsDuring(
          () => _show(
            tester,
            ExpenseFormScreen(expense: expense),
            width: width,
            textScale: t,
            height: 1600,
          ),
        );
        expect(errors, isEmpty, reason: where);
        _expectWhole(tester, find.text(date), where);
        for (final label in [
          'Logistics',
          'Packaging',
          'Marketing',
          'Supplies',
          'Other',
        ]) {
          _expectWhole(tester, find.text(label), where);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a card looks as before at 100% where it fits', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      final expense = Expense(
        id: 1,
        title: 'Courier bill',
        amount: 1250,
        category: ExpenseCategory.logistics,
        date: _thisMonth,
      );
      final amount = CurrencyFormatter.format(1250);
      for (final width in [360.0, 411.0]) {
        final where = '$width dp at 1x text';
        final errors = await _errorsDuring(
          () => _show(
            tester,
            const ExpenseListScreen(),
            width: width,
            textScale: 1,
            overrides: [
              expensesProvider.overrideWithValue(AsyncValue.data([expense])),
            ],
          ),
        );
        expect(errors, isEmpty, reason: where);
        final card = find.byType(ExpenseCard);
        final cardAmount = find.descendant(
          of: card,
          matching: find.text(amount),
        );
        // Category and date side by side; the amount at its own size, at
        // the card's end; the banner's total at its own size.
        expect(
          _sameLine(
            tester,
            find.text('Logistics'),
            find.text(DateFormatter.format(_thisMonth)),
          ),
          isTrue,
          reason: where,
        );
        expect(_fullSize(tester, cardAmount), isTrue, reason: where);
        expect(
          tester.getRect(cardAmount).right,
          closeTo(tester.getRect(card).right - 14, _eps),
          reason: where,
        );
        // The banner's total comes first: above the list.
        expect(
          _fullSize(tester, find.text(amount).first),
          isTrue,
          reason: where,
        );
        await tester.pumpWidget(const SizedBox());

        // Even a month of big expenses fits the banner at its own size.
        await _errorsDuring(
          () => _show(
            tester,
            const ExpenseListScreen(),
            width: width,
            textScale: 1,
            overrides: [
              expensesProvider.overrideWithValue(
                AsyncValue.data(_bigExpenses()),
              ),
            ],
          ),
        );
        expect(
          _fullSize(tester, find.text(CurrencyFormatter.format(_big * 5))),
          isTrue,
          reason: where,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('cash register', () {
    List<Override> registers(List<CashRegister> list) => [
      cashRegistersProvider.overrideWithValue(AsyncValue.data(list)),
    ];

    testWidgets('the open register and history lay out at every width and '
        'text size', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      final money = find.textContaining('৳');
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        final errors = await _errorsDuring(
          () => _show(
            tester,
            const CashRegisterScreen(),
            width: width,
            textScale: t,
            // Tall enough for the open card and the whole history.
            height: 2400,
            overrides: registers(_registers()),
          ),
        );
        expect(errors, isEmpty, reason: where);

        // Every amount whole, inside its card: 16 dp of page padding and at
        // least 14 of card padding on each side of the screen beside the
        // rail.
        expect(money, findsAtLeastNWidgets(4 + 3 * 6), reason: where);
        _expectWhole(tester, money, where);
        _expectWithin(tester, money, kRailWidth + 30, width - 30, where);
        // And every label and the opening time, whole.
        for (final text in [
          'Register Open',
          'Opening Cash Amount',
          'Expected Closing',
          'Opening',
          'Difference',
        ]) {
          _expectWhole(tester, find.text(text), where);
        }
        _expectWhole(
          tester,
          find.text(DateFormatter.formatWithTime(_registers().first.openedAt)),
          where,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('its dialogs and the closed state lay out', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        for (final button in ['Cash In', 'Cash Out', 'Close Register']) {
          final errors = await _errorsDuring(() async {
            await _show(
              tester,
              const CashRegisterScreen(),
              width: width,
              textScale: t,
              overrides: registers(_registers()),
            );
            await tester.tap(
              find.ancestor(
                of: find.text(button),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget, reason: where);
          });
          expect(errors, isEmpty, reason: '$button dialog, $where');
          if (button == 'Close Register') {
            _expectWhole(tester, find.textContaining('Expected: ৳'), where);
          }
          await tester.pumpWidget(const SizedBox());
        }

        final errors = await _errorsDuring(() async {
          await _show(
            tester,
            const CashRegisterScreen(),
            width: width,
            textScale: t,
            overrides: registers(_registers(open: false)),
          );
          await tester.tap(find.text('Open Register'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget, reason: where);
        });
        expect(errors, isEmpty, reason: 'closed state, $where');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('its rows look as before at 100% where they fit', (
      tester,
    ) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final list = [
        CashRegister(
          id: 2,
          openingAmount: 5000,
          totalCashIn: 1250,
          totalCashOut: 300,
          openedAt: now,
        ),
        CashRegister(
          id: 1,
          openingAmount: 4000,
          totalCashIn: 2500,
          totalCashOut: 450,
          closingAmount: 6100,
          isClosed: true,
          openedAt: now.subtract(const Duration(days: 1)),
          closedAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      for (final width in [360.0, 411.0]) {
        final where = '$width dp at 1x text';
        final errors = await _errorsDuring(
          () => _show(
            tester,
            const CashRegisterScreen(),
            width: width,
            textScale: 1,
            height: 2000,
            overrides: registers(list),
          ),
        );
        expect(errors, isEmpty, reason: where);
        // The open card comes first, then the history's cards.
        final history = find
            .ancestor(
              of: find.text('Closed').first,
              matching: find.byType(Container),
            )
            .at(1);
        for (final (card, label, value) in [
          (
            find.byType(CustomScrollView),
            'Opening Cash Amount',
            list.first.openingAmount,
          ),
          (
            find.byType(CustomScrollView),
            'Expected Closing',
            list.first.expectedClosing,
          ),
          (history, 'Opening', list[1].openingAmount),
          (history, 'Closing', list[1].closingAmount!),
        ]) {
          final labelText = find
              .descendant(of: card, matching: find.text(label))
              .first;
          final valueText = find
              .descendant(
                of: card,
                matching: find.text(CurrencyFormatter.format(value)),
              )
              .first;
          expect(
            _sameLine(tester, labelText, valueText),
            isTrue,
            reason: '$label, $where',
          );
          expect(_oneLine(tester, labelText), isTrue, reason: '$label, $where');
          expect(
            _fullSize(tester, valueText),
            isTrue,
            reason: '$label, $where',
          );
        }
        // The opening time beside the title on a 411 dp phone (on 360 dp it
        // used to overflow the card).
        if (width == 411) {
          expect(
            _sameLine(
              tester,
              find.text('Register Open'),
              find.text(DateFormatter.formatWithTime(list.first.openedAt)),
            ),
            isTrue,
            reason: where,
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('inventory', () {
    testWidgets('stock levels lay out at every width and text size', (
      tester,
    ) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      final products = _bigProducts();
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        final errors = await _errorsDuring(
          () => _show(
            tester,
            const InventoryScreen(),
            width: width,
            textScale: t,
            height: 2400,
            overrides: _inventory(products),
          ),
        );
        expect(errors, isEmpty, reason: where);
        for (final p in products) {
          final name = find.text(p.name);
          final tileBox = find
              .ancestor(of: name, matching: find.byType(Container))
              .first;
          final tile = tester.getRect(tileBox).deflate(14);
          // The name keeps a usable column: the stock column next to it
          // used to take the whole tile (a 0 dp wide name at 150%).
          expect(
            _column(tester, name).width,
            greaterThanOrEqualTo(0.3 * tile.width),
            reason: '${p.name}, $where',
          );
          final stock = find
              .descendant(of: tileBox, matching: find.text('${p.totalStock}'))
              .first;
          _expectWhole(tester, stock, where);
          _expectWithin(tester, stock, tile.left, tile.right, where);
          _expectWhole(
            tester,
            find.text('of ${p.lowStockThreshold} threshold'),
            where,
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the category filter and the menus lay out with long names', (
      tester,
    ) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      final category = _longCategories().last.name;
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        final errors = await _errorsDuring(() async {
          await _show(
            tester,
            const InventoryScreen(),
            width: width,
            textScale: t,
            overrides: _inventory(_bigProducts()),
          );
          // The category menu, then the long category picked from it.
          await tester.tap(find.text('All'));
          await tester.pumpAndSettle();
          final item = find.widgetWithText(PopupMenuItem<String?>, category);
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          await tester.tap(item);
          await tester.pumpAndSettle();
          // The sort menu.
          await tester.tap(find.text('Low Stock'));
          await tester.pumpAndSettle();
          expect(find.text('Low Stock First'), findsOneWidget, reason: where);
        });
        expect(errors, isEmpty, reason: where);
        // With the long category picked, the bar keeps the count and the
        // sort button on screen.
        _expectWithin(tester, find.text(category), kRailWidth, width, where);
        _expectWithin(tester, find.text('1'), kRailWidth, width - 8, where);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('movements and empty tabs lay out at every width and text '
        'size', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        var errors = await _errorsDuring(() async {
          await _show(
            tester,
            const InventoryScreen(),
            width: width,
            textScale: t,
            overrides: _inventory(_bigProducts()),
          );
          await tester.tap(find.text('Movements'));
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty, reason: where);
        final tiles = find.byType(StockMovementTile);
        expect(tiles, findsWidgets, reason: where);
        _expectWhole(tester, find.text('+1234567'), where);
        _expectWhole(tester, find.text('-1234567'), where);
        _expectWithin(
          tester,
          find.textContaining('1234567'),
          kRailWidth + 16,
          width - 16,
          where,
        );
        await tester.pumpWidget(const SizedBox());

        errors = await _errorsDuring(() async {
          await _show(
            tester,
            const InventoryScreen(),
            width: width,
            textScale: t,
            overrides: _inventory(
              const [],
              categories: const [],
              movements: const [],
            ),
          );
          await tester.tap(find.text('Movements'));
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty, reason: 'empty, $where');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('looks as before at 100% where it fits', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      final products = [
        Product(
          id: 1,
          name: 'Rice 5kg',
          sku: 'RICE-5',
          sellingPrice: 450,
          stockQty: 25,
          category: 'Grocery',
        ),
        Product(
          id: 2,
          name: 'Soybean Oil 1L',
          sku: 'OIL-1',
          sellingPrice: 180,
          stockQty: 4,
          lowStockThreshold: 1000,
        ),
      ];
      for (final width in [360.0, 411.0]) {
        final where = '$width dp at 1x text';
        final errors = await _errorsDuring(
          () => _show(
            tester,
            const InventoryScreen(),
            width: width,
            textScale: 1,
            overrides: _inventory(
              products,
              categories: [Category(id: 1, name: 'Grocery')],
            ),
          ),
        );
        expect(errors, isEmpty, reason: where);
        for (final p in products) {
          final caption = find.text('of ${p.lowStockThreshold} threshold');
          expect(
            _fullSize(tester, find.text('${p.totalStock}')),
            isTrue,
            reason: where,
          );
          expect(_oneLine(tester, caption), isTrue, reason: where);
          expect(_oneLine(tester, find.text(p.name)), isTrue, reason: where);
        }
        // Filter at the start, its count beside it, sort at the end.
        expect(_fullSize(tester, find.text('All')), isTrue, reason: where);
        expect(_oneLine(tester, find.text('All')), isTrue, reason: where);
        expect(
          tester.getRect(find.text('2')).left,
          // Caret, padding and border of the chip, then the gap.
          closeTo(
            tester.getRect(find.text('All')).right + 16 + 10 + 1 + 6,
            _eps,
          ),
          reason: where,
        );
        expect(
          tester
              .getRect(find.byWidgetPredicate((w) => w is PopupMenuButton).last)
              .right,
          closeTo(width - 8, _eps),
          reason: where,
        );
        await tester.pumpWidget(const SizedBox());

        // Even 7-digit stock (and 6-digit thresholds) keep their size and
        // one line.
        final big = [
          _variantProduct(id: 1),
          Product(
            id: 2,
            name: 'Screws 4mm',
            sku: 'SCR-4',
            sellingPrice: 2,
            stockQty: 1234567,
            lowStockThreshold: 10000,
          ),
          // Past 40% of the tile, but it fit beside its name before: a 40%
          // cap used to shrink it at 360 dp.
          Product(
            id: 3,
            name: 'Nails',
            sku: 'NL-1',
            sellingPrice: 1,
            stockQty: 1234567890,
            lowStockThreshold: 100,
          ),
        ];
        await _errorsDuring(
          () => _show(
            tester,
            const InventoryScreen(),
            width: width,
            textScale: 1,
            height: 2400,
            overrides: _inventory(big),
          ),
        );
        // As before: the stock column at its own width, 8 dp before the
        // adjust button, and the name column filling the rest of the tile.
        final nails = find.text('1234567890');
        final nailsTile = _box(tester, find.text('Nails'));
        final adjust = tester.getRect(
          find.byWidgetPredicate((w) => w is IconButton).at(2),
        );
        expect(_fullSize(tester, nails), isTrue, reason: where);
        expect(
          tester.getRect(nails).right,
          closeTo(adjust.left - 8, _eps),
          reason: where,
        );
        expect(
          _column(tester, find.text('Nails')).right,
          closeTo(_column(tester, nails).left, _eps),
          reason: where,
        );
        expect(
          _column(tester, find.text('Nails')).left,
          closeTo(nailsTile.left + 14, _eps),
          reason: where,
        );
        expect(_oneLine(tester, find.text('of 100 threshold')), isTrue,
            reason: where);
        for (final p in big) {
          final tile = find
              .ancestor(of: find.text(p.name), matching: find.byType(Container))
              .first;
          expect(
            _fullSize(
              tester,
              find
                  .descendant(of: tile, matching: find.text('${p.totalStock}'))
                  .first,
            ),
            isTrue,
            reason: '${p.name}, $where',
          );
          expect(
            _oneLine(tester, find.text('of ${p.lowStockThreshold} threshold')),
            isTrue,
            reason: '${p.name}, $where',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('stock adjustment', () {
    /// Pumps until [ready] finds a widget, letting the database's real async
    /// work (the product watcher, the supplier lookups) run in between: the
    /// test clock doesn't drive Isar. Polls rather than allowing a fixed
    /// time, so a slow machine only takes longer; fails after [timeout].
    Future<void> pumpUntilFound(
      WidgetTester tester,
      Finder ready, {
      Duration timeout = const Duration(seconds: 30),
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (ready.evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out after $timeout waiting for $ready');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    }

    Future<List<String>> show(
      WidgetTester tester,
      int productId, {
      required double width,
      required double textScale,
      double height = 800,
      Future<void> Function()? then,
    }) => _errorsDuring(() async {
      setLayoutScreen(tester, width, height: height);
      await pumpLayoutApp(
        tester,
        StockAdjustmentScreen(productId: productId),
        textScale: textScale,
        overrides: [isarProvider.overrideWith((ref) async => isar)],
      );
      // Loaded: the product (its combination chips), and its linked
      // supplier if it has one.
      await pumpUntilFound(
        tester,
        productId == variantId
            ? find.text('$_long Wholesale Supplier Limited')
            : find.byType(ChoiceChip),
      );
      await tester.pumpAndSettle();
      if (then != null) await then();
    });

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      // Lets the closed product watcher's last native message land.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    testWidgets('lays out at every width and text size', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      final product = _variantProduct();
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        final errors = await show(
          tester,
          variantId,
          width: width,
          textScale: t,
          height: 2400,
          then: () async {
            // A damage adjustment: its helper text and no supplier row.
            await tester.tap(find.text('Damage'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Restock'));
            await tester.pumpAndSettle();
          },
        );
        expect(errors, isEmpty, reason: where);

        // The product name keeps a usable column beside its stock, which
        // stays whole inside the header.
        final name = find.text(product.name);
        final header = _box(tester, name).deflate(16);
        expect(
          _column(tester, name).width,
          greaterThanOrEqualTo(0.3 * (header.width - 60)),
          reason: where,
        );
        final stock = find.text('${product.totalStock}');
        _expectWhole(tester, stock, where);
        _expectWithin(tester, stock, header.left, header.right, where);

        // Every combination's stock count stays visible in its chip, and
        // every chip on screen.
        final chips = find.byType(ChoiceChip);
        expect(
          chips,
          findsNWidgets(1 + product.variantCombinations.length),
          reason: where,
        );
        for (var i = 1; i < chips.evaluate().length; i++) {
          final chip = tester.getRect(chips.at(i));
          final count = find.descendant(
            of: chips.at(i),
            matching: find.textContaining(RegExp(r'\(\d+\)')),
          );
          _expectWhole(tester, count, where);
          _expectWithin(tester, count, chip.left, chip.right, where);
          expect(
            chip.left,
            greaterThanOrEqualTo(kRailWidth + 20 - _eps),
            reason: where,
          );
          expect(
            chip.right,
            lessThanOrEqualTo(width - 20 + _eps),
            reason: where,
          );
        }
        // The linked supplier, loaded with the product.
        _expectWhole(
          tester,
          find.text('$_long Wholesale Supplier Limited'),
          where,
        );
        await dispose(tester);
      }
    });

    testWidgets('its supplier picker lays out at every width and text size', (
      tester,
    ) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      for (final (width, t) in _combos) {
        final where = '$width dp at ${t}x text';
        final errors = await show(
          tester,
          variantId,
          width: width,
          textScale: t,
          then: () async {
            final supplier = find.text('$_long Wholesale Supplier Limited');
            await tester.ensureVisible(supplier);
            await tester.pumpAndSettle();
            await tester.tap(supplier);
            await pumpUntilFound(tester, find.text('$_long Supplier 0'));
            await tester.pumpAndSettle();
            expect(
              find.text('$_long Supplier 0'),
              findsOneWidget,
              reason: where,
            );
          },
        );
        expect(errors, isEmpty, reason: where);
        await dispose(tester);
      }
    });

    testWidgets('looks as before at 100% where it fits', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        final where = '$width dp at 1x text';
        final errors = await show(
          tester,
          typicalId,
          width: width,
          textScale: 1,
        );
        expect(errors, isEmpty, reason: where);
        expect(_fullSize(tester, find.text('17')), isTrue, reason: where);
        expect(
          _oneLine(tester, find.text('total stock')),
          isTrue,
          reason: where,
        );
        expect(_oneLine(tester, find.text('T-Shirt')), isTrue, reason: where);
        // Each chip shows its label and count in full.
        for (final text in ['Size: M', 'Size: L', '(5)', '(12)']) {
          _expectWhole(tester, find.textContaining(text), where);
        }
        await dispose(tester);

        // Even a 7-digit total keeps its size and its caption one line.
        await show(tester, variantId, width: width, textScale: 1);
        expect(
          _fullSize(tester, find.text('${_variantProduct().totalStock}')),
          isTrue,
          reason: where,
        );
        expect(
          _oneLine(tester, find.text('total stock')),
          isTrue,
          reason: where,
        );
        await dispose(tester);
      }
    });

    testWidgets('lays out on tablets and in Split View', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      final product = _variantProduct();
      await forEachTabletLayout(tester, (where, window, t) async {
        final errors = await _errorsDuring(() async {
          await pumpLayoutApp(
            tester,
            StockAdjustmentScreen(productId: variantId),
            textScale: t,
            overrides: [isarProvider.overrideWith((ref) async => isar)],
          );
          await pumpUntilFound(
            tester,
            find.text('$_long Wholesale Supplier Limited'),
          );
          await tester.pumpAndSettle();
          // A whole-number quantity, typed in Bengali digits.
          final qty = find.widgetWithText(TextFormField, 'Adjust Quantity');
          await tester.ensureVisible(qty);
          await tester.pumpAndSettle();
          await tester.enterText(qty, '১২৩৪৫৬৭');
          await tester.pump();
          expect(find.text('1234567'), findsOneWidget, reason: where);
        });
        expect(errors, isEmpty, reason: where);
        // The stock stays whole inside the header; every combination chip
        // shows its count, inside the page.
        final name = find.text(product.name);
        final header = _box(tester, name).deflate(16);
        final stock = find.text('${product.totalStock}');
        _expectWhole(tester, stock, where);
        _expectWithin(tester, stock, header.left, header.right, where);
        final chips = find.byType(ChoiceChip);
        for (var i = 1; i < chips.evaluate().length; i++) {
          final count = find.descendant(
            of: chips.at(i),
            matching: find.textContaining(RegExp(r'\(\d+\)')),
          );
          _expectWhole(tester, count, where);
          final chip = tester.getRect(chips.at(i));
          expect(
            chip.left,
            greaterThanOrEqualTo(railWidthFor(window.width) + 20 - _eps),
            reason: where,
          );
          expect(
            chip.right,
            lessThanOrEqualTo(window.width - 20 + _eps),
            reason: where,
          );
        }
        await dispose(tester);
      });
    });
  });

  // iPads and Android tablets in both orientations, and the app's window in
  // Split View: beside the 56 dp rail below 600 dp, the 200 dp sidebar from
  // there.
  group('on tablets and in Split View', () {
    /// Pumps [home] in the tablet window [forEachTabletLayout] set up, and
    /// lets it settle.
    Future<void> showOnTablet(
      WidgetTester tester,
      Widget home,
      double textScale, {
      List<Override> overrides = const [],
    }) async {
      await pumpLayoutApp(
        tester,
        home,
        textScale: textScale,
        overrides: overrides,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('expenses: the list, its export button and the form', (
      tester,
    ) async {
      final amount = CurrencyFormatter.format(_big);
      final total = CurrencyFormatter.format(_big * 5);
      await forEachTabletLayout(tester, (where, window, t) async {
        var errors = await _errorsDuring(
          () => showOnTablet(
            tester,
            const ExpenseListScreen(),
            t,
            overrides: [
              expensesProvider.overrideWithValue(
                AsyncValue.data(_bigExpenses()),
              ),
            ],
          ),
        );
        expect(errors, isEmpty, reason: where);
        final banner = _box(tester, find.text(total)).deflate(16);
        _expectWhole(tester, find.text(total), where);
        _expectWithin(tester, find.text(total), banner.left, banner.right,
            where);
        final cards = find.byType(ExpenseCard);
        expect(cards, findsWidgets, reason: where);
        for (var i = 0; i < cards.evaluate().length; i++) {
          final card = tester.getRect(cards.at(i)).deflate(14);
          final cardAmount = find.descendant(
            of: cards.at(i),
            matching: find.text(amount),
          );
          _expectWhole(tester, cardAmount, where);
          _expectWithin(tester, cardAmount, card.left, card.right, where);
        }
        // The export button stays in the app bar, inside the window.
        _expectWithin(
          tester,
          find.byTooltip('Export CSV'),
          railWidthFor(window.width),
          window.width,
          where,
        );
        await tester.pumpWidget(const SizedBox());

        errors = await _errorsDuring(
          () => showOnTablet(
            tester,
            ExpenseFormScreen(expense: _bigExpenses().first),
            t,
          ),
        );
        expect(errors, isEmpty, reason: 'form, $where');
        for (final label in [
          'Logistics',
          'Packaging',
          'Marketing',
          'Supplies',
          'Other',
        ]) {
          _expectWhole(tester, find.text(label), 'form, $where');
        }
      });
    });

    testWidgets('the cash register, its dialogs and the closed state', (
      tester,
    ) async {
      final money = find.textContaining('৳');
      List<Override> registers({bool open = true}) => [
        cashRegistersProvider.overrideWithValue(
          AsyncValue.data(_registers(open: open)),
        ),
      ];
      await forEachTabletLayout(tester, (where, window, t) async {
        final rail = railWidthFor(window.width);
        var errors = await _errorsDuring(
          () => showOnTablet(
            tester,
            const CashRegisterScreen(),
            t,
            overrides: registers(),
          ),
        );
        expect(errors, isEmpty, reason: where);
        // Every amount whole, inside its card, at the top and at the end of
        // the history.
        _expectWhole(tester, money, where);
        _expectWithin(tester, money, rail + 30, window.width - 30, where);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -4000),
          4000,
        );
        await tester.pumpAndSettle();
        _expectWhole(tester, money, '$where, history');
        _expectWithin(
          tester,
          money,
          rail + 30,
          window.width - 30,
          '$where, history',
        );
        await tester.pumpWidget(const SizedBox());

        for (final button in ['Cash In', 'Cash Out', 'Close Register']) {
          errors = await _errorsDuring(() async {
            await showOnTablet(
              tester,
              const CashRegisterScreen(),
              t,
              overrides: registers(),
            );
            await tester.tap(
              find.ancestor(
                of: find.text(button),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget, reason: where);
            await tester.enterText(find.byType(TextField).first, '12345678.9');
            await tester.pump();
          });
          expect(errors, isEmpty, reason: '$button dialog, $where');
          await tester.pumpWidget(const SizedBox());
        }

        errors = await _errorsDuring(() async {
          await showOnTablet(
            tester,
            const CashRegisterScreen(),
            t,
            overrides: registers(open: false),
          );
          await tester.tap(find.text('Open Register'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget, reason: where);
        });
        expect(errors, isEmpty, reason: 'closed state, $where');
      });
    });

    testWidgets('inventory: stock levels and movements', (tester) async {
      final products = _bigProducts();
      await forEachTabletLayout(tester, (where, window, t) async {
        var errors = await _errorsDuring(
          () => showOnTablet(
            tester,
            const InventoryScreen(),
            t,
            overrides: _inventory(products),
          ),
        );
        expect(errors, isEmpty, reason: where);
        for (final p in products) {
          final name = find.text(p.name);
          if (name.evaluate().isEmpty) continue; // below a short window
          final tileBox = find
              .ancestor(of: name, matching: find.byType(Container))
              .first;
          final tile = tester.getRect(tileBox).deflate(14);
          final stock = find
              .descendant(of: tileBox, matching: find.text('${p.totalStock}'))
              .first;
          _expectWhole(tester, stock, where);
          _expectWithin(tester, stock, tile.left, tile.right, where);
        }
        await tester.pumpWidget(const SizedBox());

        errors = await _errorsDuring(() async {
          await showOnTablet(
            tester,
            const InventoryScreen(),
            t,
            overrides: _inventory(products),
          );
          await tester.tap(find.text('Movements'));
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty, reason: 'movements, $where');
        expect(find.byType(StockMovementTile), findsWidgets, reason: where);
        _expectWithin(
          tester,
          find.textContaining('1234567'),
          railWidthFor(window.width) + 16,
          window.width - 16,
          'movements, $where',
        );
      });
    });
  });

  testWidgets('right-to-left layouts stay clean', (tester) async {
    addTearDown(tester.view.reset);
    Widget rtl(Widget child) =>
        Directionality(textDirection: TextDirection.rtl, child: child);
    for (final (width, t) in [(320.0, 1.5), (411.0, 1.0)]) {
      final where = 'RTL, $width dp at ${t}x text';
      for (final (home, overrides) in <(Widget, List<Override>)>[
        (
          const ExpenseListScreen(),
          [expensesProvider.overrideWithValue(AsyncValue.data(_bigExpenses()))],
        ),
        (
          const CashRegisterScreen(),
          [
            cashRegistersProvider.overrideWithValue(
              AsyncValue.data(_registers()),
            ),
          ],
        ),
        (const InventoryScreen(), _inventory(_bigProducts())),
      ]) {
        final errors = await _errorsDuring(
          () => _show(
            tester,
            rtl(home),
            width: width,
            textScale: t,
            overrides: overrides,
          ),
        );
        expect(errors, isEmpty, reason: '${home.runtimeType}, $where');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
