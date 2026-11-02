import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/action_feedback.dart';
import '../../../../data/models/order.dart';
import '../../providers/order_provider.dart';

String orderStatusLabel(BuildContext context, OrderStatus status) {
  final s = AppStrings.of(context);
  return switch (status) {
    OrderStatus.pending => s.pending,
    OrderStatus.confirmed => s.confirmed,
    OrderStatus.shipped => s.shipped,
    OrderStatus.completed => s.completed,
    OrderStatus.cancelled => s.cancelled,
  };
}

Future<void> changeOrderStatus(
  BuildContext context,
  WidgetRef ref,
  Order order,
  OrderStatus status,
) async {
  final s = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final done = s.orderStatusNow(order.orderNumber, orderStatusLabel(context, status));
  await ref.read(orderProvider.notifier).updateStatus(order.id, status);
  final failed = ref.read(orderProvider).hasError;
  showOutcome(messenger, failed ? s.errorOccurred : done, failed: failed);
}
