import 'dart:math' as math;

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

  void _showStatusMenu(BuildContext context, Offset globalPosition) {
    final currentStatus = order.orderStatus;
    // The menu is laid out in the nearest Navigator's overlay (the shell
    // branch's, beside the sidebar and under the status bar, and scaled by
    // the Display size), so the press point has to be in its coordinates.
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(globalPosition);

    showMenu<OrderStatus>(
      context: context,
      position: RelativeRect.fromRect(
        local & Size.zero,
        Offset.zero & overlay.size,
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

        // Status badges, whole: the second one wraps under the first when
        // they don't fit side by side.
        Expanded(
          flex: 3,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              OrderStatusBadge(status: order.orderStatus),
              PaymentStatusBadge(status: order.paymentStatus),
            ],
          ),
        ),

        // Amount: shrunk to fit its column rather than cut off.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              CurrencyFormatter.format(order.totalAmount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme, ColorScheme cs) {
    final muted = cs.onSurface.withValues(alpha: 0.5);
    final numberStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    final nameStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.6),
    );
    final itemsStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.5),
      fontSize: 11,
    );
    final dateStyle = theme.textTheme.bodySmall
        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11);
    final itemsLabel =
        '${order.totalItems} item${order.totalItems != 1 ? 's' : ''}';
    final dateLabel = DateFormatter.format(order.createdAt);
    final hasCustomer = order.customerName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order number, customer, then item count and date at the end. The
        // order number is never cut short: the customer's name gives way,
        // and when even a few letters of it don't fit beside the rest
        // (narrow layout, large text) the count and date go to a line of
        // their own.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final minName = hasCustomer
                ? 8 +
                    13 +
                    3 +
                    math.min(
                      _lineWidth(context, order.customerName, nameStyle),
                      MediaQuery.textScalerOf(context).scale(24),
                    )
                : 0.0;
            final metaWidth = _lineWidth(context, itemsLabel, itemsStyle) +
                8 +
                _lineWidth(context, dateLabel, dateStyle);
            final oneLine =
                _lineWidth(context, order.orderNumber, numberStyle) +
                        minName +
                        8 +
                        metaWidth <=
                    width;

            final lead = Row(
              children: [
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: math.max(0.0, width - minName)),
                  child: Text(
                    order.orderNumber,
                    style: numberStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasCustomer) ...[
                  const SizedBox(width: 8),
                  ThinIcon(tabler.User.new, size: 13, color: muted),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: nameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                if (oneLine) ...[
                  const SizedBox(width: 8),
                  Text(itemsLabel, style: itemsStyle, maxLines: 1),
                  const SizedBox(width: 8),
                  Text(dateLabel, style: dateStyle, maxLines: 1),
                ],
              ],
            );
            if (oneLine) return lead;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(itemsLabel, style: itemsStyle),
                    Text(dateLabel, style: dateStyle),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        // Badges at the start, the amount at the end; the amount goes under
        // the badges when the two don't fit side by side. Neither is cut
        // short: an amount wider than the whole card shrinks to fit.
        OverflowBar(
          spacing: 8,
          overflowSpacing: 6,
          alignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OrderStatusBadge(status: order.orderStatus),
                PaymentStatusBadge(status: order.paymentStatus),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyFormatter.format(order.totalAmount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The width [text] takes on one line in [style] as a [Text] draws it here:
/// over the ambient text style, at the ambient text size, bold if the phone
/// asks for it (the Bold text setting).
double _lineWidth(BuildContext context, String text, TextStyle? style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
