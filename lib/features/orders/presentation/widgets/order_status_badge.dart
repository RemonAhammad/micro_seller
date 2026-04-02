import 'package:flutter/material.dart';
import '../../../../data/models/order.dart';
import '../../../../core/constants/app_colors.dart';

class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      OrderStatus.pending => (AppColors.statusPending, 'Pending', Icons.hourglass_top_rounded),
      OrderStatus.confirmed => (AppColors.statusConfirmed, 'Confirmed', Icons.check_circle_outline_rounded),
      OrderStatus.shipped => (AppColors.statusShipped, 'Shipped', Icons.local_shipping_rounded),
      OrderStatus.completed => (AppColors.statusCompleted, 'Completed', Icons.task_alt_rounded),
      OrderStatus.cancelled => (AppColors.statusCancelled, 'Cancelled', Icons.cancel_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const PaymentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      PaymentStatus.unpaid => (AppColors.paymentUnpaid, 'Unpaid'),
      PaymentStatus.partial => (AppColors.paymentPartial, 'Partial'),
      PaymentStatus.paid => (AppColors.paymentPaid, 'Paid'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
