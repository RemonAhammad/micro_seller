import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/order.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import 'order_status_badge.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';

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
              tabler.HourglassHigh.new
            ),
          OrderStatus.confirmed => (
              AppColors.statusConfirmed,
              'Confirmed',
              tabler.CircleCheck.new
            ),
          OrderStatus.shipped => (
              AppColors.statusShipped,
              'Shipped',
              tabler.TruckDelivery.new
            ),
          OrderStatus.completed => (
              AppColors.statusCompleted,
              'Completed',
              tabler.CircleCheck.new
            ),
          OrderStatus.cancelled => (
              AppColors.statusCancelled,
              'Cancelled',
              tabler.CircleX.new
            ),
        };

        return PopupMenuItem<OrderStatus>(
          value: status,
          enabled: !selected,
          child: Row(
            children: [
              ThinIcon(icon, size: 18, color: selected ? color.withValues(alpha: 0.4) : color),
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
                ThinIcon(tabler.Check.new, size: 16, color: color),
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      onLongPressStart: onStatusChange != null
          ? (details) => _showStatusMenu(context, details.globalPosition)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: isWide ? _buildWideLayout(theme, cs) : _buildCompactLayout(theme, cs),
      ),
    );
  }

  Widget _buildWideLayout(ThemeData theme, ColorScheme cs) {
    final muted = cs.onSurface.withValues(alpha: 0.5);
    return Row(
      children: [
        // Order number + customer
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderNumber,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (order.customerName.isNotEmpty)
                Text(
                  order.customerName,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Items + date
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.totalItems} item${order.totalItems != 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormatter.format(order.createdAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Status badges
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: OrderStatusBadge(status: order.orderStatus)),
              const SizedBox(width: 6),
              Flexible(child: PaymentStatusBadge(status: order.paymentStatus)),
            ],
          ),
        ),

        // Amount
        Flexible(
          child: Text(
            CurrencyFormatter.format(order.totalAmount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme, ColorScheme cs) {
    final muted = cs.onSurface.withValues(alpha: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                order.orderNumber,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (order.customerName.isNotEmpty) ...[
              const SizedBox(width: 8),
              ThinIcon(tabler.User.new, size: 13, color: muted),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  order.customerName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const Spacer(),
            Text(
              '${order.totalItems} item${order.totalItems != 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormatter.format(order.createdAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Flexible(child: OrderStatusBadge(status: order.orderStatus)),
            const SizedBox(width: 6),
            Flexible(child: PaymentStatusBadge(status: order.paymentStatus)),
            const Spacer(),
            Text(
              CurrencyFormatter.format(order.totalAmount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}
