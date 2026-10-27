import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/variant_utils.dart';
import 'package:micro_seller/data/models/category.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/services/device_channel.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/categories/presentation/category_screen.dart';
import 'package:micro_seller/features/categories/providers/category_provider.dart';
import 'package:micro_seller/features/products/presentation/catalog_share_screen.dart';
import 'package:micro_seller/features/products/presentation/product_detail_screen.dart';
import 'package:micro_seller/features/products/presentation/product_form_screen.dart';
import 'package:micro_seller/features/products/presentation/product_list_screen.dart';
import 'package:micro_seller/features/products/presentation/widgets/stock_badge.dart';
import 'package:micro_seller/features/products/providers/product_detail_providers.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';
import 'package:micro_seller/features/scanner/presentation/scanner_screen.dart';
import 'package:micro_seller/shared/screens/qr_scanner_screen.dart';
import 'package:micro_seller/shared/widgets/app_button.dart';
import 'package:micro_seller/shared/widgets/scanner_camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../support/fake_camera.dart';
import '../support/fake_device_channel.dart';
import '../support/isar_core.dart';
import '../support/layout_harness.dart';

// The Products, Scanner and Categories screens under the Display size and
// Text size settings: from the narrowest layout the Display size allows to a
// 411 dp phone, beside the sidebar rail, at 100% to 150% text, with
// worst-case data (long names and SKUs, eight-digit amounts, many variants,
// a long scanned code). Nothing may overflow or be cut off, an amount is
// never wrapped or ellipsized, a short label is never split mid-word, and at
// 100% on a 360 dp or wider phone each layout is the one it was before. The
// same in every tablet window (iPads and Android tablets, both orientations,
// Split View), and for the scanners' camera-off views and dialog.

const _eps = 0.01;

const _longName =
    'Mohammad Abdur Rahman Chowdhury Trading Co. Premium Basmati Rice 25kg';
const _longSku = 'SKU-MARCTC-PREMIUM-BASMATI-25KG-000123';
const _longCategory = 'Groceries & Household Essentials';
const _supplierName = 'Mohammad Abdur Rahman Chowdhury Trading Co.';
const _price = 12345678.9;
const _qrCode = 'FOUND-CODE';
const _longCode = 'https://example.com/a/very/long/path/that/goes/on/and/on'
    '?with=query&and=more&ref=8901234567890123456789';

/// The app theme with Roboto named where the theme leaves the family out
/// (button labels, app bar titles). A phone draws those in Roboto, its
/// default font; a test would draw them in the wide square test font, and a
/// label would wrap or overflow where it doesn't on a phone.
final ThemeData _phoneTheme = () {
  final t = AppTheme.lightTheme;
  TextStyle? roboto(TextStyle? s) => s?.copyWith(fontFamily: 'Roboto');
  ButtonStyle? button(ButtonStyle? s) => s?.copyWith(
      textStyle: WidgetStatePropertyAll(roboto(s.textStyle?.resolve({}))));
  return t.copyWith(
    filledButtonTheme:
        FilledButtonThemeData(style: button(t.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: button(t.outlinedButtonTheme.style)),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: button(t.elevatedButtonTheme.style)),
    appBarTheme: t.appBarTheme
        .copyWith(titleTextStyle: roboto(t.appBarTheme.titleTextStyle)),
  );
}();

Product _product({int id = 1, int supplierId = 0, bool variants = false}) {
  final attributes = [
    VariantAttribute(name: 'Size', options: ['Small', 'Medium', 'Extra Large']),
    VariantAttribute(
        name: 'Colour', options: ['Midnight Blue', 'Forest Green']),
    VariantAttribute(
        name: 'Material', options: ['Organic Cotton Blend', 'Polyester']),
  ];
  final combinations = generateCombinations(attributes, baseSku: _longSku);
  for (var i = 0; i < combinations.length; i++) {
    combinations[i]
      ..stockQty = i == 0 ? 0 : 123456
      ..priceAdjustment = i.isEven ? 12345678.9 : -1234567.89;
  }
  return Product(
    id: id,
    name: _longName,
    sku: _longSku,
    description: 'A long description of the product. ' * 6,
    sellingPrice: _price,
    costPrice: 9876543.21,
    stockQty: 1234567,
    lowStockThreshold: 1000000,
    category: _longCategory,
    qrCode: 'https://example.com/p/8901234567890123456789012345678901234567890',
    variantAttributes: variants ? attributes : const [],
    variantCombinations: variants ? combinations : const [],
    supplierId: supplierId,
    createdAt: DateTime(2026, 9, 30, 23, 59),
    updatedAt: DateTime(2026, 10, 19, 12),
  );
}

List<Product> _products() => [
      _product(),
      Product(
          id: 2,
          name: 'Oil',
          sku: 'O',
          sellingPrice: 1234.5,
          stockQty: 5,
          category: _longCategory),
      Product(id: 3, name: _longName, sku: _longSku, sellingPrice: 0.5),
      for (var i = 4; i < 10; i++)
        Product(
          id: i,
          name: '$_longName $i',
          sku: '$_longSku-$i',
          sellingPrice: 98765432.1,
          stockQty: 99999999,
          category: _longCategory,
        ),
    ];

List<Category> _categories() => [
      Category(id: 1, name: _longCategory),
      Category(id: 2, name: _supplierName),
      Category(id: 3, name: 'Snacks'),
    ];

String _where(double width, double t) => '${width.toInt()} dp at ${t}x text';

/// Runs the frames that finish what was just started (entrance animations,
/// a dialog or sheet coming in). A ticker's first frame only starts it, and
/// a child faded all the way out isn't painted: an overflow inside it would
/// go unreported.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// Pumps [screen] beside the rail on a [width] dp layout at [t] text, the
/// way a phone draws it, past its entrance animations.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required double width,
  required double t,
  List<Override> overrides = const [],
  double height = 800,
  bool rail = true,
  Locale? locale,
}) async {
  setLayoutScreen(tester, width, height: height);
  await _pumpHere(tester, screen,
      t: t, overrides: overrides, rail: rail, locale: locale);
}

/// [_pump] in the window as it is (a tablet's, from [forEachTabletLayout]):
/// beside the sidebar the window gets, or over all of it without [rail].
Future<void> _pumpHere(
  WidgetTester tester,
  Widget screen, {
  required double t,
  List<Override> overrides = const [],
  bool rail = true,
  Locale? locale,
}) async {
  await pumpLayoutApp(
    tester,
    Theme(data: _phoneTheme, child: screen),
    textScale: t,
    overrides: overrides,
    rail: rail,
    locale: locale,
  );
  await _frames(tester);
}

/// Clears the screen between combinations, so each pump starts fresh.
Future<void> _clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Lets Isar's background work finish until [done] (a lookup the screen
/// started), then draws the result.
Future<void> _settleDb(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'the database lookup never finished');
  await _frames(tester);
}

/// No word of [finder]'s text is split across lines: each paragraph is at
/// least as wide as its longest word.
void _expectWholeWords(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    expect(p.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.size.width + 0.5),
        reason: '$where: a word of "${p.text.toPlainText()}" is split');
  }
}

/// [finder]'s text (an amount) is drawn whole on one line: not ellipsized,
/// not wrapped. It may be shrunk to fit.
void _expectOneWholeLine(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    expect(p.didExceedMaxLines, isFalse, reason: '$where: "$text" cut');
    expect(p.size.width,
        greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5),
        reason: '$where: "$text" wrapped');
  }
}

/// Whether [a] and [b] sit side by side (on one row) rather than stacked.
bool _sideBySide(WidgetTester tester, Finder a, Finder b) {
  final ra = tester.getRect(a), rb = tester.getRect(b);
  return rb.top < ra.bottom - _eps && ra.top < rb.bottom - _eps;
}

Finder _icon(ThinIconBuilder builder) => find.byWidgetPredicate(
    (w) => w is ThinIcon && w.builder == builder,
    description: 'ThinIcon');

/// Scans [code] on the scanner tab and waits for its lookup, or only for the
/// frames when it can't finish ([settle] false).
Future<void> _scan(WidgetTester tester, String code,
    {bool settle = true}) async {
  tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      BarcodeCapture(barcodes: [Barcode(rawValue: code)]));
  await tester.pump();
  if (settle) {
    await _settleDb(tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty);
  } else {
    await _frames(tester);
  }
}

/// Every way a scanner's camera can be off, as the camera fails to start
/// and as the phone reports its access: refused while Android may still ask,
/// refused for good (iOS, or Android's "Don't ask again"), forbidden by a
/// device policy, no camera at all, and a camera that fails.
const _cameraOff = [
  ('refused, may ask again', FakeCamera.refused, CameraAccess.denied),
  ('refused', FakeCamera.refused, CameraAccess.permanentlyDenied),
  ('restricted', FakeCamera.refused, CameraAccess.restricted),
  ('no camera', FakeCamera.noCamera, CameraAccess.granted),
  ('failing', FakeCamera.broken, CameraAccess.granted),
];

/// The camera-off view laid out: nothing overflows, its text is drawn whole
/// and no word of it (a button label included) is split across lines.
void _expectCleanCameraOff(WidgetTester tester, String where) {
  expectCleanLayout(tester, where);
  final view = find.byType(ScannerErrorView);
  expect(view, findsOneWidget, reason: where);
  final texts = find.descendant(of: view, matching: find.byType(Text));
  expectWholeText(tester, texts, where);
  _expectWholeWords(tester, texts, where);
}

/// A screen whose button shows the camera dialog for [access], as a product
/// photo taken with a refused camera does.
Widget _cameraDialogHost(CameraAccess access, DeviceChannel device) =>
    Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCameraBlockedDialog(context, access, device),
            child: const Text('Show'),
          ),
        ),
      ),
    );

/// The camera dialog laid out, as [_expectCleanCameraOff] checks the view.
void _expectCleanCameraDialog(WidgetTester tester, String where) {
  expectCleanLayout(tester, where);
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget, reason: where);
  final texts = find.descendant(of: dialog, matching: find.byType(Text));
  expectWholeText(tester, texts, where);
  _expectWholeWords(tester, texts, where);
}

void main() {
  final coreLibrary = isarCoreLibrary();
  final camera = FakeCamera();
  final device = FakeDeviceChannel();
  late Directory dir;
  late Isar isar;
  late int supplierId;

  setUpAll(() async {
    await loadRoboto();
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    CurrencyFormatter.setSymbol('৳');
    MobileScannerPlatform.instance = camera;
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_products_layout');
    isar = await Isar.open(
      kIsarSchemas,
      directory: dir.path,
      name: 'products_layout',
      inspector: false,
    );
    await isar.writeTxn(() async {
      supplierId = await isar.suppliers.put(Supplier(
        name: _supplierName,
        company: 'Chowdhury Wholesale & Distribution Limited',
        phone: '+8801712345678',
      ));
      for (var i = 0; i < 8; i++) {
        await isar.suppliers.put(Supplier(
          name: 'Supplier $i $_supplierName',
          company: 'Company $i Chowdhury Wholesale & Distribution Limited',
        ));
      }
      await isar.products.put(_product(id: 1)..qrCode = _qrCode);
    });
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  // Every check below measures text as a phone draws it, in Roboto.
  setUp(requireRoboto);

  // A test that turned the camera off leaves it on for the next.
  tearDown(() {
    camera.startError = null;
    MobileScannerController.resetPlatformSessionOwner();
  });

  List<Override> listOverrides(List<Product> products) => [
        productsProvider.overrideWithValue(AsyncValue.data(products)),
        categoriesProvider.overrideWithValue(AsyncValue.data(_categories())),
      ];

  group('product list', () {
    testWidgets('grid tiles and list rows lay out at every width and text size',
        (tester) async {
      addTearDown(tester.view.reset);
      final price = CurrencyFormatter.format(_price);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(tester, const ProductListScreen(),
              width: width, t: t, overrides: listOverrides(_products()));
          // Grid: the no-photo placeholder (icon + a long category) shrinks
          // into a short photo area instead of overflowing it.
          expectCleanLayout(tester, '$where, grid');
          _expectOneWholeLine(tester, find.text(price), '$where, grid');

          // List rows.
          await tester.tap(_icon(tabler.List.new));
          await _frames(tester);
          expectCleanLayout(tester, '$where, list');
          final name = find.text(_longName).first;
          final amount = find.text(price);
          _expectOneWholeLine(tester, amount, '$where, list');
          // A big price never squeezes the name: its words stay whole.
          _expectWholeWords(tester, name, '$where, list');
          // At 100% on a 360 dp or wider phone, price and stock stay beside
          // the name as before.
          if (t == 1.0 && width >= 360) {
            expect(_sideBySide(tester, name, amount), isTrue, reason: where);
          }
          await _clear(tester);
        }
      }
    });

    testWidgets('empty and filtered-out lists lay out', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(tester, const ProductListScreen(),
              width: width, t: t, overrides: listOverrides(const []));
          expectCleanLayout(tester, '$where, empty');
          await _clear(tester);
          await _pump(tester, const ProductListScreen(),
              width: width, t: t, overrides: listOverrides(_products()));
          await tester.enterText(find.byType(TextField), 'no such product');
          await _frames(tester);
          expectCleanLayout(tester, '$where, filtered out');
          await _clear(tester);
        }
      }
    });
  });

  group('product detail', () {
    final overrides = [
      productByIdProvider(1)
          .overrideWithValue(AsyncValue.data(_product(variants: true))),
    ];

    testWidgets('lays out at every width and text size', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(tester, const ProductDetailScreen(productId: 1),
              width: width, t: t, overrides: overrides);
          // Info rows, variant rows (a long SKU, two big amounts) and the
          // QR code all fit their card.
          expectCleanLayout(tester, where);
          for (final amount in [_price, 9876543.21]) {
            _expectOneWholeLine(
                tester, find.text(CurrencyFormatter.format(amount)), where);
          }
          _expectWholeWords(
              tester, find.textContaining('Price: +৳12,345,678.9'), where);
          _expectWholeWords(tester, find.text('Low Stock Threshold'), where);

          // The stock badge sits beside the name, or under it once the name
          // would have too little room for its words.
          final name = find.text(_longName);
          final badge = find.byType(StockBadge);
          _expectWholeWords(tester, name, where);
          if (t == 1.0 && width >= 360) {
            expect(tester.getRect(badge).left,
                greaterThanOrEqualTo(tester.getRect(name).right - _eps),
                reason: '$where: the badge left the name\'s side');
          }
          await _clear(tester);
        }
      }
    });

    testWidgets('right-to-left, missing product and delete dialog lay out',
        (tester) async {
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: ProductDetailScreen(productId: 1),
        ),
        width: 320,
        t: 1.5,
        overrides: overrides,
      );
      expectCleanLayout(tester, 'right to left');
      await tester.tap(_icon(tabler.Trash.new));
      await _frames(tester);
      expectCleanLayout(tester, 'delete dialog');
      await _clear(tester);

      await _pump(tester, const ProductDetailScreen(productId: 1),
          width: 320,
          t: 1.5,
          overrides: [
            productByIdProvider(1)
                .overrideWithValue(const AsyncValue.data(null)),
          ]);
      expectCleanLayout(tester, 'not found');
      await _clear(tester);
    });
  });

  group('product form', () {
    final categories = [
      categoriesProvider.overrideWithValue(AsyncValue.data(_categories())),
    ];

    testWidgets('a new product lays out at every width and text size',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          // Tall enough that the whole form is laid out.
          await _pump(tester, const ProductFormScreen(),
              width: width, t: t, height: 2400, overrides: categories);
          expectCleanLayout(tester, where);
          // "Variant Attributes" and its Add button share a line, or the
          // button moves under it: it stays on the screen.
          final add = tester.getRect(find.text('Add'));
          expect(add.right, lessThanOrEqualTo(width - 20 + _eps),
              reason: where);
          _expectWholeWords(tester, find.text('Variant Attributes'), where);

          // Selling and cost price side by side as before at 100% on a
          // 360 dp or wider phone; one above the other where a half-width
          // field would leave its label a letter or two.
          final selling = find.widgetWithText(TextFormField, 'Selling Price');
          final cost = find.widgetWithText(TextFormField, 'Cost Price');
          if (t == 1.0 && width >= 360) {
            expect(_sideBySide(tester, selling, cost), isTrue, reason: where);
          }
          if (width == 320) {
            expect(_sideBySide(tester, selling, cost), isFalse, reason: where);
          }

          // Saving the empty form shows each field's error under it.
          await tester.tap(find.byType(AppButton));
          await _frames(tester);
          expectCleanLayout(tester, '$where, errors shown');
          expectWholeText(
              tester, find.text('Product name is required'), where);
          await _clear(tester);
        }
      }
    });

    testWidgets('an edited product with variants and a supplier lays out',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(
            tester,
            ProductFormScreen(
                product: _product(supplierId: supplierId, variants: true)),
            width: width,
            t: t,
            height: 3200,
            overrides: [
              ...categories,
              isarProvider.overrideWith((ref) async => isar),
            ],
          );
          await _settleDb(tester,
              () => find.text(_supplierName).evaluate().isNotEmpty);
          expectCleanLayout(tester, where);
          _expectWholeWords(tester, find.text('Combinations (12)'), where);
          final regenerate = tester.getRect(find.text('Regenerate'));
          expect(regenerate.right, lessThanOrEqualTo(width - 20 + _eps),
              reason: where);

          // A combination's stock / price / SKU fields: three to a row as
          // before on a 411 dp phone at 100%, fewer where that would leave
          // each label a letter or two.
          // (The last combination built: the form's own SKU field comes
          // first.)
          final stock = find.widgetWithText(TextField, 'Stock').last;
          final adjustment = find.widgetWithText(TextField, 'Price +/-').last;
          final sku = find.widgetWithText(TextField, 'SKU').last;
          if (t == 1.0 && width == 411) {
            expect(_sideBySide(tester, stock, adjustment), isTrue,
                reason: where);
            expect(_sideBySide(tester, adjustment, sku), isTrue,
                reason: where);
          }
          if (width == 320) {
            expect(_sideBySide(tester, adjustment, sku), isFalse,
                reason: where);
          }
          await _clear(tester);
        }
      }
    });

    testWidgets('closing the form before its supplier loads is safe',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        ProductFormScreen(product: _product(supplierId: supplierId)),
        width: 360,
        t: 1.0,
        overrides: [
          ...categories,
          isarProvider.overrideWith((ref) async => isar),
        ],
      );
      // Leave at once; the supplier lookup finishes after the form is gone.
      await _clear(tester);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expectCleanLayout(tester, 'after closing');
    });

    testWidgets('its photo and supplier sheets lay out', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(
            tester,
            ProductFormScreen(product: _product()),
            width: width,
            t: t,
            overrides: [
              ...categories,
              isarProvider.overrideWith((ref) async => isar),
            ],
          );
          await tester.tap(find.byType(AnimatedContainer).first);
          await _frames(tester);
          expectCleanLayout(tester, '$where, photo sheet');
          await _clear(tester);

          await _pump(tester, const ProductFormScreen(),
              width: width,
              t: t,
              overrides: [
                ...categories,
                isarProvider.overrideWith((ref) async => isar),
              ]);
          await tester.tap(find.text('Supplier (optional)'));
          await _settleDb(tester,
              () => find.byType(DraggableScrollableSheet).evaluate().isNotEmpty);
          expectCleanLayout(tester, '$where, supplier sheet');
          await _clear(tester);
        }
      }
    });
  });

  group('catalog share', () {
    testWidgets('lays out at every width and text size', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(tester, const CatalogShareScreen(),
              width: width,
              t: t,
              overrides: [
                productsProvider
                    .overrideWithValue(AsyncValue.data(_products())),
              ]);
          await tester.tap(find.text('Select All'));
          await tester.pump();
          expectCleanLayout(tester, where);
          // Each price is shrunk onto its line, never wrapped mid-number.
          _expectOneWholeLine(tester,
              find.text(CurrencyFormatter.format(98765432.1)), where);
          // The share buttons' labels wrap between words, never inside one;
          // side by side as before at 100% on a 360 dp or wider phone.
          final image = find.text('Share as Image');
          final pdf = find.text('Share as PDF');
          _expectWholeWords(tester, image, where);
          _expectWholeWords(tester, pdf, where);
          if (t == 1.0 && width >= 360) {
            expect(_sideBySide(tester, image, pdf), isTrue, reason: where);
          }
          await _clear(tester);

          await _pump(tester, const CatalogShareScreen(),
              width: width,
              t: t,
              overrides: [
                productsProvider.overrideWithValue(const AsyncValue.data([])),
              ]);
          expectCleanLayout(tester, '$where, empty');
          await _clear(tester);
        }
      }
    });

    testWidgets('lays out with Bold text on', (tester) async {
      addTearDown(tester.view.reset);
      // The phone's Bold text setting draws every label heavier, so wider.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final where = '${_where(320, 1.3)}, bold text';
      await _pump(tester, const CatalogShareScreen(),
          width: 320,
          t: 1.3,
          overrides: [
            productsProvider.overrideWithValue(AsyncValue.data(_products())),
          ]);
      await tester.tap(find.text('Select All'));
      await tester.pump();
      expectCleanLayout(tester, where);
      _expectWholeWords(tester, find.text('Share as Image'), where);
      _expectWholeWords(tester, find.text('Share as PDF'), where);
    });
  });

  group('scanner', () {
    // A short window: 320 dp wide is a small phone zoomed in, about 640 tall.
    const height = 640.0;

    testWidgets('its result panel lays out at every width and text size',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      final db = [isarProvider.overrideWith((ref) async => isar)];
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          for (final (state, code) in [
            ('matched', _qrCode),
            ('no match', _longCode),
            ('a long code',
                'BEGIN:VCARD N:Chowdhury;Mohammad Abdur Rahman ' * 14),
          ]) {
            final where = '${_where(width, t)}, $state';
            await _pump(tester, const ScannerScreen(),
                width: width, t: t, height: height, overrides: db);
            expectCleanLayout(tester, '$where, before scanning');
            await _scan(tester, code);
            // The panel fits the screen, scrolling inside if it must.
            expectCleanLayout(tester, where);
            final scanAgain = find.text('Scan again');
            final action = find.text(
                state == 'matched' ? 'View product' : 'Add as new product');
            for (final button in [scanAgain, action]) {
              expect(tester.getRect(button).bottom,
                  lessThanOrEqualTo(height + _eps),
                  reason: '$where: a button is off the screen');
            }
            _expectWholeWords(tester, scanAgain, where);
            _expectWholeWords(tester, action, where);
            if (t == 1.0 && width == 411) {
              expect(_sideBySide(tester, scanAgain, action), isTrue,
                  reason: where);
            }
            await _clear(tester);
          }
        }
      }
    });

    testWidgets('its result panel lays out with Bold text on', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      addTearDown(tester.view.reset);
      // The phone's Bold text setting draws every label heavier, so wider.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final db = [isarProvider.overrideWith((ref) async => isar)];
      for (final (state, code) in [
        ('matched', _qrCode),
        ('no match', _longCode),
      ]) {
        final where = '${_where(320, 1.3)}, bold text, $state';
        await _pump(tester, const ScannerScreen(),
            width: 320, t: 1.3, height: height, overrides: db);
        await _scan(tester, code);
        expectCleanLayout(tester, where);
        _expectWholeWords(tester, find.text('Scan again'), where);
        _expectWholeWords(
            tester,
            find.text(
                state == 'matched' ? 'View product' : 'Add as new product'),
            where);
        await _clear(tester);
      }
    });

    testWidgets('lays out while looking a code up', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(tester, const ScannerScreen(),
              width: width,
              t: t,
              height: height,
              overrides: [
                // The lookup never finishes.
                isarProvider.overrideWithValue(const AsyncValue.loading()),
              ]);
          await _scan(tester, _longCode, settle: false);
          expectCleanLayout(tester, where);
          _expectWholeWords(tester, find.text('Scan again'), where);
          await _clear(tester);
        }
      }
    });

    testWidgets("the product form's QR scanner lays out", (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          // A route of its own, over the whole window.
          await _pump(tester, const QrScannerScreen(),
              width: width, t: t, height: height, rail: false);
          expectCleanLayout(tester, _where(width, t));
          await _clear(tester);
        }
      }
    });
  });

  group('camera off', () {
    final overrides = [deviceChannelProvider.overrideWithValue(device)];

    // As short as the scanner layouts above.
    const height = 640.0;

    testWidgets('both scanners say why at every width and text size',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          for (final (state, error, access) in _cameraOff) {
            for (final qr in [false, true]) {
              final where = '${_where(width, t)}, '
                  '${qr ? 'QR scanner' : 'scanner tab'}, $state';
              camera.startError = error;
              device.camera = access;
              await _pump(
                tester,
                qr ? const QrScannerScreen() : const ScannerScreen(),
                width: width,
                t: t,
                height: height,
                // The QR scanner is a route of its own, over the whole
                // window.
                rail: !qr,
                overrides: overrides,
              );
              _expectCleanCameraOff(tester, where);
              await _clear(tester);
            }
          }
        }
      }
    });

    testWidgets('the scanner says why right to left', (tester) async {
      addTearDown(tester.view.reset);
      for (final (state, error, access) in _cameraOff) {
        final where = '${_where(320, 1.5)}, Arabic, $state';
        camera.startError = error;
        device.camera = access;
        await _pump(tester, const ScannerScreen(),
            width: 320,
            t: 1.5,
            height: height,
            overrides: overrides,
            locale: const Locale('ar'));
        _expectCleanCameraOff(tester, where);
        await _clear(tester);
      }
    });

    testWidgets('the scanner and the dialog say why with Bold text on',
        (tester) async {
      addTearDown(tester.view.reset);
      // The phone's Bold text setting draws every label heavier, so wider.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      for (final (state, error, access) in _cameraOff) {
        final where = '${_where(320, 1.5)}, bold text, $state';
        camera.startError = error;
        device.camera = access;
        await _pump(tester, const ScannerScreen(),
            width: 320, t: 1.5, height: height, overrides: overrides);
        _expectCleanCameraOff(tester, where);
        await _clear(tester);
      }
      for (final access in [
        CameraAccess.permanentlyDenied,
        CameraAccess.restricted,
      ]) {
        final where = '${_where(320, 1.5)}, bold text, ${access.name}';
        await _pump(tester, _cameraDialogHost(access, device),
            width: 320, t: 1.5, height: height);
        await tester.tap(find.text('Show'));
        await _frames(tester);
        _expectCleanCameraDialog(tester, where);
        await _clear(tester);
      }
    });

    testWidgets('the camera dialog lays out at every width and text size',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          for (final access in [
            CameraAccess.denied,
            CameraAccess.permanentlyDenied,
            CameraAccess.restricted,
          ]) {
            final where = '${_where(width, t)}, ${access.name}';
            await _pump(tester, _cameraDialogHost(access, device),
                width: width, t: t, height: height);
            await tester.tap(find.text('Show'));
            await _frames(tester);
            _expectCleanCameraDialog(tester, where);
            await _clear(tester);
          }
        }
      }
    });
  });

  group('tablets', () {
    final categories = [
      categoriesProvider.overrideWithValue(AsyncValue.data(_categories())),
    ];

    testWidgets('the product list lays out in every tablet window',
        (tester) async {
      final price = CurrencyFormatter.format(_price);
      await forEachTabletLayout(tester, (where, window, t) async {
        await _pumpHere(tester, const ProductListScreen(),
            t: t, overrides: listOverrides(_products()));
        expectCleanLayout(tester, '$where, grid');
        _expectOneWholeLine(tester, find.text(price), '$where, grid');

        await tester.tap(_icon(tabler.List.new));
        await _frames(tester);
        expectCleanLayout(tester, '$where, list');
        final name = find.text(_longName).first;
        final amount = find.text(price);
        _expectOneWholeLine(tester, amount, '$where, list');
        _expectWholeWords(tester, name, '$where, list');
        // Beside the sidebar with labels, price and stock stay beside the
        // name at 100%.
        if (t == 1.0 && window.width >= kWideRailMinWidth) {
          expect(_sideBySide(tester, name, amount), isTrue, reason: where);
        }
      });
    });

    testWidgets('the product form lays out in every tablet window',
        (tester) async {
      await forEachTabletLayout(tester, (where, window, t) async {
        await _pumpHere(tester, const ProductFormScreen(),
            t: t, overrides: categories);
        expectCleanLayout(tester, '$where, new product');
        _expectWholeWords(tester, find.text('Variant Attributes'), where);
        final selling = find.widgetWithText(TextFormField, 'Selling Price');
        final cost = find.widgetWithText(TextFormField, 'Cost Price');
        if (window.width >= kWideRailMinWidth) {
          expect(_sideBySide(tester, selling, cost), isTrue, reason: where);
        }

        // Saving the empty form shows each field's error under it.
        await tester.scrollUntilVisible(
          find.byType(AppButton),
          400,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first,
        );
        await tester.pump();
        await tester.tap(find.byType(AppButton));
        await _frames(tester);
        expectCleanLayout(tester, '$where, errors shown');
        expectWholeText(
            tester, find.text('Product name is required'), where);
        await _clear(tester);

        // An edited product with every variant: twelve combinations.
        await _pumpHere(
            tester, ProductFormScreen(product: _product(variants: true)),
            t: t, overrides: categories);
        expectCleanLayout(tester, '$where, variants');
        _expectWholeWords(tester, find.text('Combinations (12)'), where);
      });
    });

    testWidgets('both scanners lay out in every tablet window',
        (tester) async {
      await forEachTabletLayout(tester, (where, window, t) async {
        await _pumpHere(tester, const ScannerScreen(), t: t, overrides: [
          // The lookup never finishes.
          isarProvider.overrideWithValue(const AsyncValue.loading()),
        ]);
        expectCleanLayout(tester, '$where, scanner tab');
        await _scan(tester, _longCode, settle: false);
        expectCleanLayout(tester, '$where, looking a code up');
        _expectWholeWords(tester, find.text('Scan again'), where);
        await _clear(tester);

        // A route of its own, over the whole window.
        await _pumpHere(tester, const QrScannerScreen(), t: t, rail: false);
        expectCleanLayout(tester, '$where, QR scanner');
      });
    });

    testWidgets("the scanner's result panel lays out in every tablet window",
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      final db = [isarProvider.overrideWith((ref) async => isar)];
      await forEachTabletLayout(tester, (where, window, t) async {
        for (final (state, code) in [
          ('matched', _qrCode),
          ('no match', _longCode),
        ]) {
          await _pumpHere(tester, const ScannerScreen(), t: t, overrides: db);
          await _scan(tester, code);
          expectCleanLayout(tester, '$where, $state');
          final scanAgain = find.text('Scan again');
          final action = find.text(
              state == 'matched' ? 'View product' : 'Add as new product');
          for (final button in [scanAgain, action]) {
            expect(tester.getRect(button).bottom,
                lessThanOrEqualTo(window.height + _eps),
                reason: '$where, $state: a button is off the screen');
          }
          _expectWholeWords(tester, scanAgain, '$where, $state');
          _expectWholeWords(tester, action, '$where, $state');
          await _clear(tester);
        }
      });
    });

    testWidgets('the camera-off views and dialog lay out in every tablet '
        'window', (tester) async {
      final overrides = [deviceChannelProvider.overrideWithValue(device)];
      await forEachTabletLayout(tester, (where, window, t) async {
        for (final (state, error, access) in _cameraOff) {
          camera.startError = error;
          device.camera = access;
          await _pumpHere(tester, const ScannerScreen(),
              t: t, overrides: overrides);
          _expectCleanCameraOff(tester, '$where, scanner tab, $state');
          await _clear(tester);
          await _pumpHere(tester, const QrScannerScreen(),
              t: t, overrides: overrides, rail: false);
          _expectCleanCameraOff(tester, '$where, QR scanner, $state');
          await _clear(tester);
        }
        camera.startError = null;
        for (final access in [
          CameraAccess.permanentlyDenied,
          CameraAccess.restricted,
        ]) {
          await _pumpHere(tester, _cameraDialogHost(access, device), t: t);
          await tester.tap(find.text('Show'));
          await _frames(tester);
          _expectCleanCameraDialog(tester, '$where, dialog, ${access.name}');
          await _clear(tester);
        }
      });
    });
  });

  group('categories', () {
    testWidgets('the list, its dialogs and the empty state lay out',
        (tester) async {
      addTearDown(tester.view.reset);
      final listed = [
        categoriesProvider.overrideWithValue(AsyncValue.data(_categories())),
      ];
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = _where(width, t);
          await _pump(tester, const CategoryScreen(),
              width: width, t: t, overrides: listed);
          expectCleanLayout(tester, where);
          expectWholeText(tester, find.text(_longCategory), where);

          await tester.tap(find.byType(FloatingActionButton));
          await _frames(tester);
          expectCleanLayout(tester, '$where, add dialog');
          await tester.tap(find.text('Cancel'));
          await _frames(tester);

          await tester.tap(_icon(tabler.Pencil.new).first);
          await _frames(tester);
          expectCleanLayout(tester, '$where, edit dialog');
          await tester.tap(find.text('Cancel'));
          await _frames(tester);

          await tester.drag(find.text(_longCategory), Offset(-width, 0));
          await _frames(tester);
          expectCleanLayout(tester, '$where, delete dialog');
          await _clear(tester);

          await _pump(tester, const CategoryScreen(),
              width: width,
              t: t,
              overrides: [
                categoriesProvider.overrideWithValue(const AsyncValue.data([])),
              ]);
          expectCleanLayout(tester, '$where, empty');
          await _clear(tester);
        }
      }
    });
  });
}
