import 'package:flutter/material.dart';
import '../../../../data/models/order.dart';
import '../../../../core/constants/app_colors.dart';
import 'order_feedback.dart';

class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final label = orderStatusLabel(context, status);
    final color = switch (status) {
      OrderStatus.pending => AppColors.statusPending,
      OrderStatus.confirmed => AppColors.statusConfirmed,
      OrderStatus.shipped => AppColors.statusShipped,
      OrderStatus.completed => AppColors.statusCompleted,
      OrderStatus.cancelled => AppColors.statusCancelled,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
