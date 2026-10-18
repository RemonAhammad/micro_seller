import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/order_pages_provider.dart';
import '../providers/order_provider.dart';
import '../../../data/services/csv_export_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'widgets/order_card.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabCount = 5;
  bool _exporting = false;

  List<String> _tabLabels(BuildContext context) {
    final s = AppStrings.of(context);
    return [s.all, s.pending, s.tr('active'), s.completed, s.cancelled];
  }

  /// Exports every order, not just the loaded pages.
  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final isar = await ref.read(isarProvider.future);
      final orders = await loadAllOrdersNewestFirst(isar);
      if (orders.isEmpty) return;
      await CsvExportService().exportOrders(orders);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final countsAsync = ref.watch(orderTabCountsProvider);
    final tabs = _tabLabels(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.orders),
        actions: [
          IconButton(
            icon: const ThinIcon(tabler.FileDownload.new),
            tooltip: s.exportCsv,
            onPressed: _exporting ? null : _exportCsv,
          ),
        ],
        bottom: countsAsync.whenOrNull(
              data: (counts) {
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    for (int i = 0; i < tabs.length; i++)
                      Tab(
                          child: _TabLabel(
                              label: tabs[i], count: counts[i])),
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
              tabs: tabs.map((t) => Tab(text: t)).toList(),
            ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in OrderTab.values) _OrderList(tab: tab),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/add'),
        tooltip: s.addOrder,
        child: const ThinIcon(tabler.Plus.new),
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

/// One tab's orders, paged: nearing the end of the loaded rows loads the next
/// page, with a spinner row below while more exist.
class _OrderList extends ConsumerStatefulWidget {
  final OrderTab tab;

  const _OrderList({required this.tab});

  @override
  ConsumerState<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends ConsumerState<_OrderList> {
  /// How close to the last loaded row the next page is requested.
  static const _loadMoreAhead = 20;
  bool _loadMoreScheduled = false;

  // After the frame: the notifier's state can't change during a build.
  void _loadMoreSoon() {
    if (_loadMoreScheduled) return;
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (mounted) ref.read(orderPagesProvider(widget.tab).notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ref.watch(orderPagesProvider(widget.tab)).when(
          data: (page) {
            final orders = page.orders;
            if (orders.isEmpty) {
              return EmptyState(
                icon: tabler.Receipt.new,
                title: s.noDataFound,
                subtitle: s.addFirstOrder,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length + (page.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                if (page.hasMore && i >= orders.length - _loadMoreAhead) {
                  _loadMoreSoon();
                }
                if (i == orders.length) return const _LoadingMoreRow();
                final order = orders[i];
                return AnimatedEntrance(
                  index: i,
                  child: OrderCard(
                    order: order,
                    onStatusChange: (status) {
                      ref
                          .read(orderProvider.notifier)
                          .updateStatus(order.id, status);
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${s.error}: $e')),
        );
  }
}

class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
