// The customers, suppliers and money screens take amounts as every phone
// types them: a French or Brazilian phone's number pad types 12,50 (the
// typing tests run in France, where ',' is the point), an Arabic one
// ١٢٫٥٠. Each field keeps its text canonical (12.50) and reads it
// back with NumberInput, so the amount reaches the books; money fields take
// the shop currency's decimals (the Kuwaiti Dinar's 3). A dialog with
// nothing to pay keeps its button off, where a tap used to do nothing. On an
// iPad the expense export's share sheet points at its button, and a call
// button on a device that can't call shows the number instead.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/number_input.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/features/cash_register/presentation/cash_register_screen.dart';
import 'package:micro_seller/features/cash_register/providers/cash_register_provider.dart';
import 'package:micro_seller/features/customers/presentation/customer_form_screen.dart';
import 'package:micro_seller/features/customers/presentation/customer_list_screen.dart';
import 'package:micro_seller/features/customers/presentation/due_book_screen.dart';
import 'package:micro_seller/features/customers/providers/customer_provider.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/expenses/presentation/expense_list_screen.dart';
import 'package:micro_seller/features/expenses/providers/expense_provider.dart';
import 'package:micro_seller/features/suppliers/presentation/purchase_form_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/supplier_detail_screen.dart';
import 'package:micro_seller/features/suppliers/presentation/supplier_form_screen.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_detail_providers.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
// url_launcher's platform side, faked so a call or WhatsApp "doesn't open".
// A dependency of url_launcher, not of the app.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/layout_harness.dart';

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// path_provider's channel, for the temporary folder an export writes to.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// A device that can't call (an iPad): every link is refused, and recorded.
class _CantCall extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return false;
  }
}

/// Records supplier payments instead of writing them.
class _Suppliers extends SupplierNotifier {
  final payments = <(int, double)>[];

  @override
  Future<void> recordSupplierPayment(int supplierId, double amount) async =>
      payments.add((supplierId, amount));
}

/// Records the register's cash in and closings instead of writing them.
class _Register extends CashRegisterNotifier {
  final cashIn = <(int, double)>[];
  final closed = <(int, double)>[];

  @override
  Future<void> addCashIn(int id, double amount) async =>
      cashIn.add((id, amount));

  @override
  Future<void> closeRegister(
    int id,
    double closingAmount, {
    String notes = '',
  }) async => closed.add((id, closingAmount));
}

final _karim = Customer(id: 9, name: 'Karim Uddin', phone: '01712345678');
final _rahim = Customer(id: 8, name: 'Rahim');

CustomerDue _due(Customer customer, double total) => CustomerDue(
  customer: customer,
  orderDues: [
    OrderDue(
      Order(
        id: customer.id,
        orderNumber: 'ORD-000${customer.id}',
        customerId: customer.id,
        customerName: customer.name,
        totalAmount: total,
        createdAt: DateTime(2026, 9, 1),
      ),
      total,
    ),
  ],
  totalDue: total,
);

final _supplier = Supplier(
  id: 3,
  name: 'Karim Traders',
  phone: '01712345678',
  totalPurchases: 3,
  totalPaid: 5000,
  totalDue: 1250.5,
);

/// The supplier detail without a database.
List<Override> _supplierDetail() => [
  supplierByIdProvider(
    _supplier.id,
  ).overrideWithValue(AsyncValue.data(_supplier)),
  supplierProductsProvider(
    _supplier.id,
  ).overrideWithValue(const AsyncValue.data(<Product>[])),
  supplierStockMovementsProvider(
    _supplier.id,
  ).overrideWithValue(const AsyncValue.data(<StockMovement>[])),
];

/// The button labelled [label] (the `.icon` constructors build subclasses,
/// which `find.byType` doesn't match), inside a dialog when [inDialog].
Finder _button(String label, {bool inDialog = false}) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return inDialog
      ? find.descendant(of: find.byType(AlertDialog), matching: button)
      : button;
}

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).enabled;

/// [field]'s text.
String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

/// Types [keys] one key at a time at the end of [field]'s text, as a
/// keyboard sends them.
Future<void> _typeKeys(WidgetTester tester, Finder field, String keys) async {
  for (final key in keys.split('')) {
    await tester.enterText(field, _text(tester, field) + key);
    await tester.pump();
  }
}

void main() {
  late UrlLauncherPlatform realLauncher;
  late _CantCall launcher;
  late Directory temp;

  /// What the share sheet was given.
  late List<Map<Object?, Object?>> shared;

  setUpAll(() async {
    await loadRoboto();
    realLauncher = UrlLauncherPlatform.instance;
  });

  tearDownAll(() => UrlLauncherPlatform.instance = realLauncher);

  setUp(() {
    CurrencyFormatter.setSymbol('৳');
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    launcher = _CantCall();
    UrlLauncherPlatform.instance = launcher;
    shared = [];
    temp = Directory.systemTemp.createTempSync('money_screens_input');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'com.apple.UIKit.activity.SaveToFiles';
    });
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => call.method == 'getTemporaryDirectory' ? temp.path : null,
    );
  });

  tearDown(() {
    CurrencyFormatter.setSymbol('৳');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_pathChannel, null);
    temp.deleteSync(recursive: true);
  });

  /// Pumps [screen] beside the sidebar in a phone's window (411 × 914 dp),
  /// or an iPad Air's (820 × 1180 dp, the 200 dp sidebar) when [ipad].
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
    bool ipad = false,
  }) async {
    if (ipad) {
      setLayoutScreen(tester, 820, height: 1180, devicePixelRatio: 2);
    } else {
      setLayoutScreen(tester, 411, height: 914);
    }
    addTearDown(tester.view.reset);
    await pumpLayoutApp(tester, screen, overrides: overrides);
    await tester.pumpAndSettle();
  }

  group('typing amounts', () {
    // A French phone: its number pad's ',' is the decimal point.
    setUp(() => NumberInput.debugDeviceLocale = const Locale('fr', 'FR'));
    tearDown(() => NumberInput.debugDeviceLocale = null);

    testWidgets(
      'the Due Book collects a comma-typed amount, and its full due',
      (tester) async {
        await pump(
          tester,
          const DueBookScreen(),
          overrides: [
            duesProvider.overrideWithValue(
              AsyncValue.data([_due(_karim, 1000)]),
            ),
            openRegisterProvider.overrideWithValue(const AsyncValue.data(null)),
          ],
        );
        await tester.tap(_button('Collect'));
        await tester.pumpAndSettle();
        final amount = find.widgetWithText(TextField, 'Payment Amount');
        await _typeKeys(tester, amount, '12,50');
        expect(_text(tester, amount), '12.50');
        // 12.5 goes to the order, 987.5 left on it.
        expect(find.text(CurrencyFormatter.format(12.5)), findsOneWidget);
        expect(
          find.text('${CurrencyFormatter.format(987.5)} left'),
          findsOneWidget,
        );
        expect(
          _enabled(
            tester,
            find.widgetWithText(FilledButton, 'Collect Payment'),
          ),
          isTrue,
        );

        // Full due: the whole due, to the currency's 2 decimals.
        await tester.tap(find.text('Full due'));
        await tester.pump();
        expect(_text(tester, amount), '1000.00');
      },
    );

    testWidgets('the full due keeps the Kuwaiti Dinar\'s third decimal', (
      tester,
    ) async {
      CurrencyFormatter.setSymbol(CurrencyFormatter.kuwaitiDinarSymbol);
      SharedPreferences.setMockInitialValues({
        'currencySymbol': CurrencyFormatter.kuwaitiDinarSymbol,
      });
      expect(NumberInput.moneyDecimals, 3);
      await pump(
        tester,
        const DueBookScreen(),
        overrides: [
          duesProvider.overrideWithValue(
            AsyncValue.data([_due(_karim, 1000.125)]),
          ),
          openRegisterProvider.overrideWithValue(const AsyncValue.data(null)),
        ],
      );
      await tester.tap(_button('Collect'));
      await tester.pumpAndSettle();
      final amount = find.widgetWithText(TextField, 'Payment Amount');
      await _typeKeys(tester, amount, '0,125');
      expect(_text(tester, amount), '0.125');
      await tester.tap(find.text('Full due'));
      await tester.pump();
      expect(_text(tester, amount), '1000.125');
    });

    testWidgets('the Due Book keeps a decimal minimum due as typed', (
      tester,
    ) async {
      await pump(
        tester,
        const DueBookScreen(),
        overrides: [
          duesProvider.overrideWithValue(
            AsyncValue.data([_due(_karim, 1000), _due(_rahim, 2000)]),
          ),
        ],
      );
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      final minimum = find.byType(TextField).last;
      await _typeKeys(tester, minimum, '1250,5');
      expect(_text(tester, minimum), '1250.5');
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Only Rahim owes that much; the chip names the minimum in full.
      expect(find.text('Rahim'), findsOneWidget);
      expect(find.text('Karim Uddin'), findsNothing);
      expect(
        find.text('≥ ${CurrencyFormatter.format(1250.5)}'),
        findsOneWidget,
      );

      // Reopened, the field shows it as typed: it used to show 1251.
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      expect(_text(tester, find.byType(TextField).last), '1250.5');
    });

    testWidgets('the customer and supplier forms save phones in 0-9', (
      tester,
    ) async {
      for (final form in const [CustomerFormScreen(), SupplierFormScreen()]) {
        await pump(tester, form);
        final phone = find.widgetWithText(TextField, 'Phone');
        // A Bengali keyboard's digits, a space and a dash; letters dropped.
        await _typeKeys(tester, phone, '+৮৮০ ১৭১২-abc৩৪৫৬৭৮');
        expect(_text(tester, phone), '+880 1712-345678', reason: '$form');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the purchase form reads an amount paid typed in Arabic '
        'digits', (tester) async {
      await pump(tester, const PurchaseFormScreen());
      final paid = find.widgetWithText(TextField, 'Amount Paid');
      await _typeKeys(tester, paid, '١٢٫٥');
      expect(_text(tester, paid), '12.5');
      // The summary's Paid line reads it.
      expect(find.text(CurrencyFormatter.format(12.5)), findsOneWidget);
    });

    testWidgets('the supplier pay dialog pays once there\'s an amount', (
      tester,
    ) async {
      final suppliers = _Suppliers();
      await pump(
        tester,
        const SupplierDetailScreen(supplierId: 3),
        overrides: [
          ..._supplierDetail(),
          supplierProvider.overrideWith(() => suppliers),
        ],
      );
      await tester.tap(_button('Pay Due'));
      await tester.pumpAndSettle();
      final pay = _button('Pay Due', inDialog: true);
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      // Nothing to pay: the button is off.
      expect(_enabled(tester, pay), isFalse);
      await _typeKeys(tester, field, '0');
      expect(_enabled(tester, pay), isFalse);
      await tester.enterText(field, '');
      await _typeKeys(tester, field, '1,5');
      expect(_text(tester, field), '1.5');
      expect(_enabled(tester, pay), isTrue);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(suppliers.payments, [(3, 1.5)]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the register\'s cash in and close take a comma-typed amount', (
      tester,
    ) async {
      final register = _Register();
      await pump(
        tester,
        const CashRegisterScreen(),
        overrides: [
          cashRegistersProvider.overrideWithValue(
            AsyncValue.data([
              CashRegister(
                id: 100,
                openingAmount: 1000,
                totalCashIn: 250.5,
                openedAt: DateTime.now(),
              ),
            ]),
          ),
          cashRegisterProvider.overrideWith(() => register),
        ],
      );

      await tester.tap(_button('Cash In'));
      await tester.pumpAndSettle();
      final confirm = _button('Confirm', inDialog: true);
      final amount = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(_enabled(tester, confirm), isFalse);
      await _typeKeys(tester, amount, '12,5');
      expect(_enabled(tester, confirm), isTrue);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(register.cashIn, [(100, 12.5)]);

      // Close: the expected 1250.5 to the currency's decimals; emptied, the
      // button is off; a counted amount closes.
      await tester.tap(_button('Close Register'));
      await tester.pumpAndSettle();
      final close = _button('Close', inDialog: true);
      final counted = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first;
      expect(_text(tester, counted), '1250.50');
      expect(_enabled(tester, close), isTrue);
      await tester.enterText(counted, '');
      await tester.pump();
      expect(_enabled(tester, close), isFalse);
      await _typeKeys(tester, counted, '1240,75');
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(register.closed, [(100, 1240.75)]);
    });

    testWidgets('the close dialog starts empty when more cash went out than '
        'came in', (tester) async {
      final register = _Register();
      await pump(
        tester,
        const CashRegisterScreen(),
        overrides: [
          cashRegistersProvider.overrideWithValue(
            AsyncValue.data([
              CashRegister(id: 100, totalCashOut: 50, openedAt: DateTime.now()),
            ]),
          ),
          cashRegisterProvider.overrideWith(() => register),
        ],
      );
      await tester.tap(_button('Close Register'));
      await tester.pumpAndSettle();
      final close = _button('Close', inDialog: true);
      final counted = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first;
      // -50 can't be counted; the field (which takes no sign) starts empty.
      expect(_text(tester, counted), '');
      expect(_enabled(tester, close), isFalse);
      await _typeKeys(tester, counted, '0');
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(register.closed, [(100, 0.0)]);
    });
  });

  group('searching phones', () {
    // Phones are saved with 0-9; a Bengali or Arabic keyboard types its own
    // digits into a search box, which found no one but in the order form.
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(const Duration(milliseconds: 500)); // the debounce
      await tester.pumpAndSettle();
    }

    testWidgets('the customer list finds a phone typed in Bengali digits', (
      tester,
    ) async {
      await pump(
        tester,
        const CustomerListScreen(),
        overrides: [
          customersProvider.overrideWithValue(
            AsyncValue.data([_karim, _rahim]),
          ),
        ],
      );
      await search(tester, '০১৭১২');
      expect(find.text('Karim Uddin'), findsOneWidget);
      expect(find.text('Rahim'), findsNothing);
      await search(tester, '٠١٧');
      expect(find.text('Karim Uddin'), findsOneWidget);
    });

    testWidgets('the Due Book finds one too', (tester) async {
      await pump(
        tester,
        const DueBookScreen(),
        overrides: [
          duesProvider.overrideWithValue(
            AsyncValue.data([_due(_karim, 1000), _due(_rahim, 2000)]),
          ),
        ],
      );
      await search(tester, '০১৭১২');
      expect(find.text('Karim Uddin'), findsOneWidget);
      expect(find.text('Rahim'), findsNothing);
    });
  });

  group('on an iPad', () {
    testWidgets('the expense export\'s share sheet points at its button', (
      tester,
    ) async {
      await pump(
        tester,
        const ExpenseListScreen(),
        ipad: true,
        overrides: [
          expensesProvider.overrideWithValue(
            AsyncValue.data([
              Expense(
                id: 1,
                title: 'Courier bill',
                amount: 1250,
                category: ExpenseCategory.logistics,
                date: DateTime.now(),
              ),
            ]),
          ),
        ],
      );
      final export = find.ancestor(
        of: find.byTooltip('Export CSV'),
        matching: find.byType(IconButton),
      );
      final rect = tester.getRect(export);
      await tester.tap(export);
      // The CSV is encoded on an isolate: real time passes until it's
      // shared.
      for (var i = 0; i < 500 && shared.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      final share = shared.single;
      expect(share['originX'], rect.left);
      expect(share['originY'], rect.top);
      expect(share['originWidth'], rect.width);
      expect(share['originHeight'], rect.height);
      expect(share['subject'], 'expenses_export');
      // In the app bar's top end, not the middle of the screen.
      expect(rect.left, greaterThan(820 / 2));
      expect(rect.top, lessThan(100));
    });

    testWidgets('the Due Book\'s call button shows the number instead', (
      tester,
    ) async {
      await pump(
        tester,
        const DueBookScreen(),
        ipad: true,
        overrides: [
          duesProvider.overrideWithValue(AsyncValue.data([_due(_karim, 1000)])),
        ],
      );
      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();
      expect(launcher.launched, ['tel:01712345678']);
      expect(
        find.text('Calls aren\'t available on this device'),
        findsOneWidget,
      );
      expect(find.text('Copy number'), findsOneWidget);
    });

    testWidgets('the supplier\'s call button shows the number instead', (
      tester,
    ) async {
      await pump(
        tester,
        const SupplierDetailScreen(supplierId: 3),
        ipad: true,
        overrides: _supplierDetail(),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ThinIcon && w.builder == tabler.Phone.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(launcher.launched, ['tel:01712345678']);
      expect(
        find.text('Calls aren\'t available on this device'),
        findsOneWidget,
      );
      expect(find.text('Copy number'), findsOneWidget);
    });
  });
}
