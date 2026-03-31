import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../providers/customer_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../orders/presentation/widgets/order_card.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarProvider);

    return isarAsync.when(
      data: (isar) => _CustomerDetailBody(customerId: customerId, isar: isar),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

class _CustomerDetailBody extends ConsumerWidget {
  final int customerId;
  final Isar isar;

  const _CustomerDetailBody({required this.customerId, required this.isar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<Customer?>(
      future: isar.customers.get(customerId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final customer = snap.data;
        if (customer == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Customer not found')));
        }

        final tagColor = switch (customer.tag) {
          CustomerTag.newCustomer => AppColors.tagNew,
          CustomerTag.regular => AppColors.tagRegular,
          CustomerTag.vip => AppColors.tagVip,
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(customer.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () =>
                    context.push('/customers/$customerId/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded),
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: 'Delete Customer',
                    message: 'Delete ${customer.name}?',
                    confirmText: 'Delete',
                    isDestructive: true,
                    icon: Icons.delete_rounded,
                  );
                  if (ok == true && context.mounted) {
                    await ref
                        .read(customerNotifierProvider.notifier)
                        .deleteCustomer(customer.id);
                    context.pop();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar and info header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            customer.name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: tagColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        customer.name,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (customer.phone.isNotEmpty)
                        Text(
                          customer.phone,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: 'Orders',
                        value: '${customer.totalOrders}',
                        icon: Icons.receipt_long_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        label: 'Total Spent',
                        value:
                            CurrencyFormatter.formatCompact(customer.totalSpent),
                        icon: Icons.payments_rounded,
                        color: AppColors.statusCompleted,
                      ),
                    ),
                    if (customer.outstandingBalance > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatChip(
                          label: 'Outstanding',
                          value: CurrencyFormatter.formatCompact(
                              customer.outstandingBalance),
                          icon: Icons.money_off_rounded,
                          color: AppColors.paymentUnpaid,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                if (customer.address.isNotEmpty ||
                    customer.notes.isNotEmpty) ...[
                  _InfoCard(children: [
                    if (customer.address.isNotEmpty)
                      _InfoRow('Address', customer.address),
                    if (customer.notes.isNotEmpty)
                      _InfoRow('Notes', customer.notes),
                    _InfoRow('Member since',
                        DateFormatter.format(customer.createdAt)),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Customer orders
                Text('Order History',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FutureBuilder<List<Order>>(
                  future: isar.orders
                      .filter()
                      .customerIdEqualTo(customerId)
                      .sortByCreatedAtDesc()
                      .findAll(),
                  builder: (ctx, snap) {
                    final orders = snap.data ?? [];
                    if (orders.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No orders yet',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.4),
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: orders
                          .map((o) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OrderCard(order: o),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                )),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
