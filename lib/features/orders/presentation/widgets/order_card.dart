import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/order.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import 'order_status_badge.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final void Function(OrderStatus status)? onStatusChange;

  const OrderCard({super.key, required this.order, this.onStatusChange});

  void _showStatusMenu(BuildContext context, Offset position) {
    final currentStatus = order.orderStatus;

    showMenu<OrderStatus>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: OrderStatus.values.map((status) {
        final selected = status == currentStatus;
        final (color, label, icon) = switch (status) {
          OrderStatus.pending => (
              AppColors.statusPending,
              'Pending',
              Icons.hourglass_top_rounded
            ),
          OrderStatus.confirmed => (
              AppColors.statusConfirmed,
              'Confirmed',
              Icons.check_circle_outline_rounded
            ),
          OrderStatus.shipped => (
              AppColors.statusShipped,
              'Shipped',
              Icons.local_shipping_rounded
            ),
          OrderStatus.completed => (
              AppColors.statusCompleted,
              'Completed',
              Icons.task_alt_rounded
            ),
          OrderStatus.cancelled => (
              AppColors.statusCancelled,
              'Cancelled',
              Icons.cancel_rounded
            ),
        };

        return PopupMenuItem<OrderStatus>(
          value: status,
          enabled: !selected,
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? color.withValues(alpha: 0.4) : color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                      : null,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: color),
              ],
            ],
          ),
        );
      }).toList(),
    ).then((status) {
      if (status != null && status != currentStatus) {
        onStatusChange?.call(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      onLongPressStart: onStatusChange != null
          ? (details) => _showStatusMenu(context, details.globalPosition)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.orderNumber,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                OrderStatusBadge(status: order.orderStatus),
              ],
            ),
            const SizedBox(height: 8),
            if (order.customerName.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.customerName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.totalItems} item${order.totalItems != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormatter.format(order.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PaymentStatusBadge(status: order.paymentStatus),
                Text(
                  CurrencyFormatter.format(order.totalAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
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
