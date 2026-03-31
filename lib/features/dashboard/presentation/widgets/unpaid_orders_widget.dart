import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/order.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/constants/app_colors.dart';

class UnpaidOrdersWidget extends StatelessWidget {
  final List<Order> orders;

  const UnpaidOrdersWidget({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: orders
          .take(5)
          .map((order) => _UnpaidOrderItem(order: order))
          .toList(),
    );
  }
}

class _UnpaidOrderItem extends StatelessWidget {
  final Order order;

  const _UnpaidOrderItem({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPartial = order.paymentStatus == PaymentStatus.partial;
    final color = isPartial ? AppColors.paymentPartial : AppColors.paymentUnpaid;

    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.payment_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    order.customerName.isNotEmpty
                        ? '${order.customerName} · ${DateFormatter.format(order.createdAt)}'
                        : DateFormatter.format(order.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(order.balanceDue),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  isPartial ? 'Partial' : 'Unpaid',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
