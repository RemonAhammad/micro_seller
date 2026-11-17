import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:micro_seller/core/utils/date_formatter.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/services/pdf_service.dart';

/// The invoice carries each line's warranty: the receipt page that Download
/// and Share both capture, and the WhatsApp text. Read from the order line
/// (frozen at sale), counted from the order's date.
void main() {
  final saleDate = DateTime(2026, 11, 17, 10);

  Order orderWith(List<OrderItem> items) {
    final total = items.fold(0.0, (s, i) => s + i.totalPrice);
    return Order(
      orderNumber: 'ORD-001',
      items: items,
      subtotal: total,
      totalAmount: total,
      amountPaid: total,
      paymentStatus: PaymentStatus.paid,
      createdAt: saleDate,
    );
  }

  final phone = OrderItem(
    productName: 'Phone X',
    qty: 1,
    unitPrice: 20000,
    totalPrice: 20000,
    serials: ['IMEI-1'],
    warrantyMonths: 12,
  );
  final soap = OrderItem(productName: 'Soap', qty: 2, unitPrice: 40, totalPrice: 80);
  final until = DateFormatter.format(DateTime(2027, 11, 17));

  Future<void> pumpReceipt(WidgetTester tester, Order order) async {
    tester.view.physicalSize = const Size(794, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(
        child: PdfService.receiptPage(order, shopName: 'Shop', sym: '৳', taxRate: 0),
      ),
    ));
    await tester.pump();
  }

  testWidgets('the receipt page: warranty and serial under their line only', (tester) async {
    await pumpReceipt(tester, orderWith([phone, soap]));
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    expect(find.text('Warranty: 12 months (until $until)'), findsOneWidget);
    expect(find.text('S/N: IMEI-1'), findsOneWidget);
    expect(find.textContaining('Warranty:'), findsOneWidget, reason: 'Soap has none');
  });

  testWidgets('the receipt reads the warranty frozen on the line', (tester) async {
    // The line was sold with 6 months; whatever the product says today, the
    // receipt (it never reads the product) keeps 6.
    await pumpReceipt(tester, orderWith([phone.copyWith(warrantyMonths: 6, serials: const [])]));
    expect(find.text('Warranty: 6 months (until ${DateFormatter.format(DateTime(2027, 5, 17))})'), findsOneWidget);
    expect(find.textContaining('S/N:'), findsNothing);
  });

  test('the WhatsApp text: the warranty under its own line, none under the other', () {
    final text = PdfService().generateWhatsAppText(orderWith([phone, soap]), currencySymbol: '৳');
    final lines = text.split('\n');
    final phoneAt = lines.indexWhere((l) => l.startsWith('• Phone X'));
    final soapAt = lines.indexWhere((l) => l.startsWith('• Soap'));
    expect(lines.sublist(phoneAt + 1, soapAt), ['   S/N: IMEI-1', '   Warranty: 12 months (until $until)']);
    expect(lines[soapAt + 1], isNot(startsWith('   ')), reason: 'nothing under Soap');
    expect('Warranty:'.allMatches(text).length, 1);
  });
}
