import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/order_provider.dart';
import '../../../data/models/order.dart';
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
  final _tabs = ['All', 'Pending', 'Active', 'Completed', 'Cancelled'];

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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: ordersAsync.when(
        data: (allOrders) {
          return TabBarView(
            controller: _tabController,
            children: [
              _OrderList(orders: allOrders),
              _OrderList(orders: allOrders
                  .where((o) => o.orderStatus == OrderStatus.pending)
                  .toList()),
              _OrderList(orders: allOrders
                  .where((o) =>
                      o.orderStatus == OrderStatus.confirmed ||
                      o.orderStatus == OrderStatus.shipped)
                  .toList()),
              _OrderList(orders: allOrders
                  .where((o) => o.orderStatus == OrderStatus.completed)
                  .toList()),
              _OrderList(orders: allOrders
                  .where((o) => o.orderStatus == OrderStatus.cancelled)
                  .toList()),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/add'),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addOrder),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;

  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context) {
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
      itemBuilder: (ctx, i) => OrderCard(order: orders[i]),
    );
  }
}
