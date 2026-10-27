// Share sheets on an iPad point at the control that was tapped. There the
// share sheet is a popover anchored to a rect (share_plus's
// `sharePositionOrigin`); without one it opens from the middle of the screen,
// pointing at nothing. Each order screen passes the rect of what the seller
// tapped: the order detail's actions menu button, each tile of the sheet a
// saved order opens, and the order list's Export CSV button.
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/pdf_service.dart';
import 'package:micro_seller/features/orders/presentation/order_detail_screen.dart';
import 'package:micro_seller/features/orders/presentation/order_form_screen.dart';
import 'package:micro_seller/features/orders/presentation/order_list_screen.dart';
import 'package:micro_seller/features/orders/providers/order_pages_provider.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/isar_core.dart';
import 'support/layout_harness.dart';

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// path_provider's channel, for the temporary folder a share writes to.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// The system's save sheet, unable to open: on iOS, Download PDF then offers
/// the PDF in the share sheet, which has Save to Files too.
class _FailingFilePicker extends FilePickerPlatform {
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => throw PlatformException(code: 'save_file_error');
}

/// An iPad Air in landscape, where the share sheet is a popover. The screen
/// is beside the 200 dp sidebar, so a control's rect is nowhere near the
/// window's corner.
const _iPad = Size(1180, 820);

final _order = Order(
  id: 1,
  orderNumber: 'ORD-001',
  customerId: 1,
  customerName: 'Rahim Uddin',
  customerPhone: '01712345678',
  items: [
    OrderItem(
      productId: 1,
      productName: 'Rice 5kg',
      qty: 2,
      unitPrice: 450,
      totalPrice: 900,
    ),
  ],
  subtotal: 900,
  totalAmount: 900,
  amountPaid: 500,
  paymentStatus: PaymentStatus.partial,
  orderStatus: OrderStatus.confirmed,
  createdAt: DateTime(2026, 10, 19, 10, 30),
  updatedAt: DateTime(2026, 10, 19, 10, 30),
);

/// Where the share sheet was asked to point.
Rect _originOf(Map<Object?, Object?> shared) => Rect.fromLTWH(
  shared['originX']! as double,
  shared['originY']! as double,
  shared['originWidth']! as double,
  shared['originHeight']! as double,
);

/// A few frames, for menus, sheets and the progress spinner to open or close.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [done], letting real work run meanwhile: the database, the
/// receipt's rendering and its PDF (on an isolate), file writes.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String what,
) async {
  for (var i = 0; i < 600 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'waiting for $what');
}

void main() {
  final coreLibrary = isarCoreLibrary();
  Isar? db;
  Directory? dbDir;

  /// What the share sheet was given, in order.
  late List<Map<Object?, Object?>> shared;
  late Directory temp;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    CurrencyFormatter.setSymbol('৳');
    // The receipt's watermark icon is decoded once and kept for the session.
    // Decoded inside a test, its future would belong to that test's fake
    // clock, and the next test's receipt would wait for it forever.
    await loadPdfWatermarkIcon();
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    // The order list's export loads every order on a worker isolate.
    dbWorkerCoreLibrary = coreLibrary;
    dbDir = await Directory.systemTemp.createTemp('micro_seller_orders_share');
    final isar = db = await Isar.open(
      kIsarSchemas,
      directory: dbDir!.path,
      name: 'orders_share_origin_test',
      inspector: false,
    );
    isar.writeTxnSync(() {
      isar.customers.putSync(
        Customer(id: 1, name: 'Rahim Uddin', phone: '01712345678'),
      );
      isar.products.putSync(
        Product(id: 1, name: 'Rice 5kg', sellingPrice: 450, stockQty: 40),
      );
      isar.orders.putSync(_order);
    });
  });

  tearDownAll(() async {
    await db?.close(deleteFromDisk: true);
    await dbDir?.delete(recursive: true);
  });

  setUp(() {
    shared = [];
    temp = Directory.systemTemp.createTempSync('orders_share_origin');
    FilePickerPlatform.instance = _FailingFilePicker();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'com.apple.UIKit.activity.CopyToPasteboard';
    });
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => call.method == 'getTemporaryDirectory' ? temp.path : null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_pathChannel, null);
    temp.deleteSync(recursive: true);
  });

  /// [screen] on an iPad, as the app shows it: beside the sidebar.
  Future<void> pumpOnIPad(
    WidgetTester tester,
    Widget screen, [
    List<Override> overrides = const [],
  ]) async {
    setLayoutScreen(
      tester,
      _iPad.width,
      height: _iPad.height,
      devicePixelRatio: 2,
    );
    addTearDown(tester.view.reset);
    await pumpLayoutApp(
      tester,
      screen,
      overrides: [isarProvider.overrideWith((ref) async => db!), ...overrides],
    );
    await _settle(tester);
  }

  /// The PDF a share sheet was given, removed after the test: Download PDF
  /// writes it to a folder of its own in the system temp folder.
  String sharedPdf(Map<Object?, Object?> shared) {
    final path = (shared['paths']! as List).single as String;
    addTearDown(() {
      final dir = File(path).parent;
      if (!dir.path.startsWith(temp.path) && dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    return path;
  }

  testWidgets(
    "the order detail's menu points the share sheet at its button",
    (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      await pumpOnIPad(tester, OrderDetailScreen(orderId: _order.id), [
        orderByIdProvider(_order.id).overrideWithValue(AsyncData(_order)),
      ]);
      final menu = find.byType(PopupMenuButton<String>);
      final button = tester.getRect(menu);
      expect(button.left, greaterThan(kWideRailWidth), reason: 'in the bar');

      // Download PDF too: the save sheet can't open, so the share sheet
      // offers the PDF.
      const items = ['Share via WhatsApp', 'Share PDF', 'Download PDF'];
      for (final (i, item) in items.indexed) {
        await tester.tap(menu);
        await _settle(tester);
        await tester.tap(find.text(item));
        await _pumpUntil(tester, () => shared.length > i, item);
        await _settle(tester);
        expect(_originOf(shared[i]), button, reason: item);
      }
      expect(shared[0]['text'], contains(_order.orderNumber));
      expect(sharedPdf(shared[1]), endsWith('/ORD-001.pdf'));
      expect(sharedPdf(shared[2]), endsWith('/ORD-001_receipt.pdf'));

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    "a saved order's sheet points the share sheet at the tile tapped",
    (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      await pumpOnIPad(tester, const OrderFormScreen());
      bool showing(Finder finder) => finder.evaluate().isNotEmpty;

      await tester.tap(find.text('Select or create customer'));
      await _pumpUntil(
        tester,
        () => showing(find.text('Rahim Uddin')),
        'the customers',
      );
      await _settle(tester);
      await tester.tap(find.text('Rahim Uddin').last);
      await _settle(tester);

      await tester.tap(find.text('Add').first);
      final picker = find.byType(DraggableScrollableSheet);
      await _pumpUntil(
        tester,
        () => showing(
          find.descendant(of: picker, matching: find.text('Rice 5kg')),
        ),
        'the products',
      );
      await _settle(tester);
      await tester.tap(
        find.descendant(of: picker, matching: find.text('Add')).first,
      );
      await _settle(tester);
      await tester.tap(find.text('Done').last);
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'New Order'));
      await _pumpUntil(
        tester,
        () => showing(find.text('Share PDF')),
        'the saved order',
      );
      await _settle(tester);

      // Download PDF too: the save sheet can't open, so the share sheet
      // offers the PDF.
      const tiles = ['Share via WhatsApp', 'Share PDF', 'Download PDF'];
      for (final (i, label) in tiles.indexed) {
        final tile = tester.getRect(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        );
        await tester.tap(find.text(label));
        await _pumpUntil(tester, () => shared.length > i, label);
        await _settle(tester);
        expect(_originOf(shared[i]), tile, reason: label);
      }
      expect(shared[0]['text'], contains('ORD-'));
      expect(sharedPdf(shared[1]), endsWith('.pdf'));
      expect(sharedPdf(shared[2]), endsWith('_invoice.pdf'));
      // Each tile its own rect.
      expect({for (final s in shared) _originOf(s)}, hasLength(3));

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    "the order list's export points the share sheet at its button",
    (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      await pumpOnIPad(tester, const OrderListScreen(), [
        orderTabCountsProvider.overrideWithValue(
          const AsyncData([1, 0, 1, 0, 0]),
        ),
        orderPagesProvider.overrideWithBuild(
          (ref, pages) => Stream.value(OrderPage([_order], hasMore: false)),
        ),
      ]);
      final export = find.byTooltip('Export CSV');
      expect(export, findsOneWidget);
      final button = tester.getRect(find.byType(IconButton));

      await tester.tap(find.byType(IconButton));
      await _pumpUntil(tester, () => shared.isNotEmpty, 'the export');
      await _settle(tester);
      expect(_originOf(shared.single), button);
      expect(shared.single['subject'], 'orders_export');

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
