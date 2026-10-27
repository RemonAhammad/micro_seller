// Where the share sheet points from the customer screens. On an iPad the
// share sheet is a popover anchored to the control that was tapped
// (share_origin.dart): the customer detail's Statement and Remind and the
// Due Book's Remind each pass their own button's rect, so the popover points
// at the button instead of opening from the middle of the screen. Remind
// shares the reminder when WhatsApp doesn't open (an iPad without it).
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/customers/presentation/customer_detail_screen.dart';
import 'package:micro_seller/features/customers/presentation/due_book_screen.dart';
import 'package:micro_seller/features/customers/providers/customer_detail_providers.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// url_launcher's platform side, faked so WhatsApp "doesn't open". A
// dependency of url_launcher, not of the app.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/isar_core.dart';
import 'support/layout_harness.dart';

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// path_provider's channel, for the temporary folder the statement is
/// written to.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// A device where WhatsApp doesn't open (an iPad without it): every link is
/// refused, and recorded.
class _NoWhatsApp extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return false;
  }
}

final _karim = Customer(
  id: 9,
  name: 'Karim Uddin',
  phone: '01712345678',
  tag: CustomerTag.regular,
  totalOrders: 1,
  totalSpent: 1250,
  outstandingBalance: 1000,
  createdAt: DateTime(2025, 3, 2),
);

final _order = Order(
  id: 1,
  orderNumber: 'ORD-0001',
  customerId: 9,
  customerName: 'Karim Uddin',
  customerPhone: '01712345678',
  subtotal: 1250,
  totalAmount: 1250,
  amountPaid: 250,
  paymentStatus: PaymentStatus.partial,
  orderStatus: OrderStatus.completed,
  createdAt: DateTime(2026, 9, 1),
);

final _due = CustomerDue(
  customer: _karim,
  orderDues: [OrderDue(_order, 1000)],
  totalDue: 1000,
);

/// The customer detail and the Due Book without a database: Karim owes
/// 1000 on one order.
List<Override> _overrides() => [
  customerByIdProvider(_karim.id).overrideWithValue(AsyncValue.data(_karim)),
  customerMonthlySpendingProvider(
    _karim.id,
  ).overrideWithValue(AsyncValue.data({DateTime(2026, 9, 1): 1250.0})),
  customerPaymentsProvider(
    _karim.id,
  ).overrideWithValue(const AsyncValue.data(<Payment>[])),
  customerOrdersProvider(_karim.id).overrideWithBuild(
    (ref, notifier) =>
        Stream.value(CustomerOrdersPage([_order], hasMore: false)),
  ),
  duesProvider.overrideWithValue(AsyncValue.data([_due])),
];

/// The button whose label is [label]: a [ButtonStyleButton] (the `.icon`
/// constructors build subclasses, which `find.byType` doesn't match).
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  final coreLibrary = isarCoreLibrary();
  Directory? dir;
  Isar? isar;
  late Directory temp;
  late UrlLauncherPlatform realLauncher;
  late _NoWhatsApp launcher;

  /// What the share sheet was given.
  late List<Map<Object?, Object?>> shared;

  setUpAll(() async {
    await loadRoboto();
    realLauncher = UrlLauncherPlatform.instance;
    CurrencyFormatter.setSymbol('৳');
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_share_origin');
    isar = await Isar.open(
      kIsarSchemas,
      directory: dir!.path,
      name: 'customers_share_origin',
      inspector: false,
    );
    await isar!.writeTxn(() async {
      await isar!.customers.put(_karim);
      await isar!.orders.put(_order);
      await isar!.payments.put(
        Payment(
          customerId: 9,
          orderId: 1,
          amount: 250,
          paidAt: DateTime(2026, 9, 1),
        ),
      );
    });
  });

  tearDownAll(() async {
    UrlLauncherPlatform.instance = realLauncher;
    await isar?.close(deleteFromDisk: true).timeout(const Duration(minutes: 1));
    await dir?.delete(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    launcher = _NoWhatsApp();
    UrlLauncherPlatform.instance = launcher;
    shared = [];
    temp = Directory.systemTemp.createTempSync('customers_share_origin');
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

  /// The share sheet was told to point at [rect].
  void expectOrigin(Map<Object?, Object?> arguments, Rect rect) {
    expect(arguments['originX'], rect.left);
    expect(arguments['originY'], rect.top);
    expect(arguments['originWidth'], rect.width);
    expect(arguments['originHeight'], rect.height);
  }

  /// Pumps [screen] beside the sidebar in an iPad Air's portrait window
  /// (820 × 1180 dp, the 200 dp sidebar), and lets its entrances finish.
  Future<void> pumpOnIpad(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
  }) async {
    setLayoutScreen(tester, 820, height: 1180, devicePixelRatio: 2);
    addTearDown(tester.view.reset);
    await pumpLayoutApp(
      tester,
      screen,
      overrides: [..._overrides(), ...overrides],
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the customer detail\'s Remind points at Remind', (tester) async {
    await pumpOnIpad(tester, const CustomerDetailScreen(customerId: 9));
    final remind = _button('Remind');
    final rect = tester.getRect(remind);
    await tester.tap(remind);
    await tester.pumpAndSettle();

    // WhatsApp was tried first, with the Bangladeshi number in full.
    expect(launcher.launched.single, startsWith('https://wa.me/8801712345678'));
    final share = shared.single;
    expectOrigin(share, rect);
    expect(share['text'], contains('Karim Uddin'));
    expect(share['text'], contains('ORD-0001'));
    // Not the screen's middle: the button, beside the 200 dp sidebar.
    expect(rect.left, greaterThan(200));
  });

  testWidgets('the customer detail\'s Statement points at Statement', (
    tester,
  ) async {
    if (isar == null) return markTestSkipped('no Isar core library');
    await pumpOnIpad(
      tester,
      const CustomerDetailScreen(customerId: 9),
      overrides: [isarProvider.overrideWith((ref) async => isar!)],
    );
    final statement = _button('Statement');
    final rect = tester.getRect(statement);
    expect(rect, isNot(tester.getRect(_button('Remind'))));
    await tester.tap(statement);
    // The statement renders for real (the database, the page capture, the
    // PDF on an isolate): real time passes until it reaches the share
    // sheet, the spinner turning meanwhile.
    for (var i = 0; i < 1500 && shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(shared, hasLength(1), reason: 'the statement was never shared');
    final share = shared.single;
    expectOrigin(share, rect);
    final path = (share['paths']! as List).single as String;
    expect(path, endsWith('statement_Karim_Uddin.pdf'));
    expect(File(path).readAsBytesSync().take(4), '%PDF'.codeUnits);
    // The spinner is gone and no error was shown.
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the Due Book\'s Remind points at its card\'s Remind', (
    tester,
  ) async {
    await pumpOnIpad(tester, const DueBookScreen());
    final card = find.ancestor(
      of: find.text('Karim Uddin'),
      matching: find.byType(Card),
    );
    final remind = find.descendant(of: card, matching: _button('Remind'));
    final rect = tester.getRect(remind);
    await tester.tap(remind);
    await tester.pumpAndSettle();

    expect(launcher.launched, hasLength(1));
    final share = shared.single;
    expectOrigin(share, rect);
    expect(share['text'], contains('Karim Uddin'));
    // Inside the card, beside the sidebar.
    final cardRect = tester.getRect(card);
    expect(rect.left, greaterThanOrEqualTo(cardRect.left));
    expect(rect.right, lessThanOrEqualTo(cardRect.right));
  });
}
