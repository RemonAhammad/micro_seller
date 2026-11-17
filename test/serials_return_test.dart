import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/serial_service.dart';
import 'package:micro_seller/features/returns/presentation/create_return_screen.dart';

import 'support/isar_core.dart';
import 'support/screen_harness.dart';

/// A return of a serial-numbered line: the seller picks which serials come
/// back, and the return carries only those.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  testWidgets('one of two serials comes back', skip: isarSkipReason != null, (tester) async {
    late Isar isar;
    late Order sale;
    await tester.runAsync(() async {
      isar = await openTestIsar('return_serials');
      await isar.writeTxn(() async {
        final pid = await isar.products.put(Product(name: 'Phone X', sellingPrice: 20000, trackSerials: true));
        await SerialService.add(isar, pid, ['IMEI-1', 'IMEI-2']);
        final item = OrderItem(
            productId: pid, productName: 'Phone X', qty: 2, unitPrice: 20000, totalPrice: 40000, serials: ['IMEI-1', 'IMEI-2']);
        final id = await isar.orders.put(Order(
          orderNumber: 'ORD-001',
          items: [item],
          subtotal: 40000,
          totalAmount: 40000,
          amountPaid: 40000,
          paymentStatus: PaymentStatus.paid,
          orderStatus: OrderStatus.completed,
          createdAt: DateTime(2026, 11, 1),
        ));
        await SerialService.sell(isar, [item], orderId: id);
        sale = (await isar.orders.get(id))!;
      });
    });
    await pumpScreen(tester, isar: isar, screen: CreateReturnScreen(originalOrder: sale));

    expect(find.text('2 / 2'), findsOneWidget, reason: 'every serial comes back at first');
    await tester.tap(find.byKey(const ValueKey('returnSerials0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IMEI-1'));
    await tester.pump();
    await tester.tap(find.textContaining('1 selected'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Serials coming back: IMEI-2'), findsOneWidget);

    final submit = find.text('Submit Return Request');
    await tester.scrollUntilVisible(submit, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(submit);
    await settleDb(tester);

    final ret = (await tester.runAsync(() => isar.orders.filter().isReturnEqualTo(true).findFirst()))!;
    expect(ret.items.single.serials, ['IMEI-2']);
    expect(ret.items.single.qty, 1);
    expect(ret.totalAmount, 20000);
  });
}
