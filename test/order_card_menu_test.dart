import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/features/orders/presentation/widgets/order_card.dart';

// The long-press status menu opens where the finger is. The order list lives
// in a shell branch's Navigator, beside the sidebar rail and under the status
// bar, so that Navigator's overlay doesn't start at the window's corner; the
// Display size setting also scales the whole app.

const _rail = 56.0;
const _statusBar = 24.0;

/// An order list as the app shows it: a branch Navigator beside a rail and
/// under a status-bar inset, the whole app scaled by [zoom] from its top
/// left (as a Display size zoom draws it).
Widget _shell(Order order, {double zoom = 1, ValueChanged<OrderStatus>? onPick}) {
  return MaterialApp(
    builder: (context, child) => zoom == 1
        ? child!
        : Transform.scale(
            scale: zoom,
            alignment: Alignment.topLeft,
            child: child,
          ),
    home: Row(
      children: [
        const SizedBox(width: _rail),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: _statusBar),
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: OrderCard(
                        order: order,
                        onStatusChange: onPick ?? (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  final order = Order(
    orderNumber: 'ORD-001',
    customerName: 'Rahim',
    totalAmount: 1250,
    createdAt: DateTime(2026, 10, 1),
  );

  for (final zoom in [1.0, 0.85, 1.25]) {
    testWidgets('the status menu opens at the press point at ${zoom}x zoom',
        (tester) async {
      await tester.pumpWidget(_shell(order, zoom: zoom));

      // A point on the card's left half, so the menu grows rightwards from
      // it (its top-left corner at the press point).
      final card = tester.getRect(find.byType(OrderCard));
      final press = card.topLeft + Offset(40 * zoom, card.height / 2);
      await tester.longPressAt(press);
      await tester.pumpAndSettle();

      final menu = tester.getRect(find.byType(PopupMenuItem<OrderStatus>).first);
      // The first item starts 8 dp (the menu's top padding) under the press.
      expect(menu.left, closeTo(press.dx, 1));
      expect(menu.top, closeTo(press.dy + 8 * zoom, 1));
    });
  }

  testWidgets('picking a status from the menu reports it', (tester) async {
    OrderStatus? picked;
    await tester.pumpWidget(_shell(order, onPick: (s) => picked = s));
    await tester.longPress(find.byType(OrderCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shipped'));
    await tester.pumpAndSettle();
    expect(picked, OrderStatus.shipped);
  });
}
