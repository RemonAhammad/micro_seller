import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/order_provider.dart';
import '../../../data/models/order.dart';
import '../../../data/services/csv_export_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/empty_state.dart';
import 'widgets/order_card.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = [
    'All',
    'Pending',
    'Active',
    'Completed',
    'Cancelled',
  ];

  List<int> _getCounts(List<Order> orders) {
    final regular = orders.where((o) => !o.isReturn).toList();
    int pending = 0, active = 0, completed = 0, cancelled = 0;
    for (final o in regular) {
      switch (o.orderStatus) {
        case OrderStatus.pending:
          pending++;
        case OrderStatus.confirmed || OrderStatus.shipped:
          active++;
        case OrderStatus.completed:
          completed++;
        case OrderStatus.cancelled:
          cancelled++;
      }
    }
    return [regular.length, pending, active, completed, cancelled];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.orders),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () async {
              final orders = ref.read(ordersProvider).valueOrNull ?? [];
              if (orders.isEmpty) return;
              await CsvExportService().exportOrders(orders);
            },
          ),
        ],
        bottom: ordersAsync.whenOrNull(
              data: (allOrders) {
                final counts = _getCounts(allOrders);
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    for (int i = 0; i < _tabs.length; i++)
                      Tab(
                          child: _TabLabel(
                              label: _tabs[i], count: counts[i])),
                  ],
                );
              },
            ) ??
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
      ),
      body: ordersAsync.when(
        data: (allOrders) {
          final regular = allOrders.where((o) => !o.isReturn).toList();

          final pending = regular
              .where((o) => o.orderStatus == OrderStatus.pending)
              .toList();
          final active = regular
              .where((o) =>
                  o.orderStatus == OrderStatus.confirmed ||
                  o.orderStatus == OrderStatus.shipped)
              .toList();
          final completed = regular
              .where((o) => o.orderStatus == OrderStatus.completed)
              .toList();
          final cancelled = regular
              .where((o) => o.orderStatus == OrderStatus.cancelled)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _OrderList(orders: regular),
              _OrderList(orders: pending),
              _OrderList(orders: active),
              _OrderList(orders: completed),
              _OrderList(orders: cancelled),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/add'),
        tooltip: AppStrings.addOrder,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderList extends ConsumerWidget {
  final List<Order> orders;

  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_rounded,
        title: AppStrings.noDataFound,
        subtitle: AppStrings.addFirstOrder,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final order = orders[i];
        return OrderCard(
          order: order,
          onStatusChange: (status) {
            ref
                .read(orderNotifierProvider.notifier)
                .updateStatus(order.id, status);
          },
        );
      },
    );
  }
}
