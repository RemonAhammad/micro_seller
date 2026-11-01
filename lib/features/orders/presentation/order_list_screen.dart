import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/order_pages_provider.dart';
import '../providers/order_provider.dart';
import '../../../data/models/order.dart';
import '../../../data/services/csv_export_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/share_origin.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bottom_sheet_handle.dart';
import 'widgets/order_card.dart';
import 'widgets/order_status_badge.dart';
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

  OrderTab get _currentTab => OrderTab.values[_tabController.index];

  Future<void> _exportCsv(Rect? origin) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    List<Order> tabOrders = [];
    try {
      final isar = await ref.read(isarProvider.future);
      tabOrders = await loadAllOrdersNewestFirst(isar, _currentTab);
      if (tabOrders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).tr('nothingToExport'))),
          );
        }
        return;
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }

    if (!mounted || tabOrders.isEmpty) return;

    final selected = await showModalBottomSheet<List<Order>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _OrderSelectionSheet(orders: tabOrders),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    setState(() => _exporting = true);
    try {
      await CsvExportService().exportOrders(selected, shareOrigin: origin);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final countsAsync = ref.watch(orderTabCountsProvider);
    final tabs = _tabLabels(context);
    final currentTabOrdersCount =
        countsAsync.value?[_tabController.index] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.orders),
        actions: [
          Builder(
            builder: (button) => IconButton(
              icon: const ThinIcon(tabler.FileDownload.new),
              tooltip: currentTabOrdersCount == 0 ? s.tr('nothingToExport') : s.exportCsv,
              onPressed: (_exporting || currentTabOrdersCount == 0)
                  ? null
                  : () => _exportCsv(shareOriginOf(button)),
            ),
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

class _OrderList extends ConsumerStatefulWidget {
  final OrderTab tab;

  const _OrderList({required this.tab});

  @override
  ConsumerState<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends ConsumerState<_OrderList> {

  static const _loadMoreAhead = 20;
  bool _loadMoreScheduled = false;

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

class _OrderSelectionSheet extends StatefulWidget {
  final List<Order> orders;

  const _OrderSelectionSheet({required this.orders});

  @override
  State<_OrderSelectionSheet> createState() => _OrderSelectionSheetState();
}

class _OrderSelectionSheetState extends State<_OrderSelectionSheet> {
  late final Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.orders.map((o) => o.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final allSelected = _selectedIds.length == widget.orders.length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.tr('selectOrdersToShare'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(widget.orders.map((o) => o.id));
                        }
                      });
                    },
                    child: Text(allSelected ? s.clearSelection : s.selectAll),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                s.tr('selectedCount').replaceAll('{count}', '${_selectedIds.length}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                itemBuilder: (context, index) {
                  final order = widget.orders[index];
                  final isChecked = _selectedIds.contains(order.id);

                  return CheckboxListTile(
                    value: isChecked,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(order.id);
                        } else {
                          _selectedIds.remove(order.id);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        OrderStatusBadge(status: order.orderStatus),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(order.totalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.customerName.isEmpty ? s.tr('walkIn') : order.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (order.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              DateFormatter.format(order.createdAt!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const ThinIcon(tabler.Share.new, size: 18),
                      label: Text(
                        _selectedIds.isEmpty
                            ? s.share
                            : s.tr('shareCount').replaceAll('{count}', '${_selectedIds.length}'),
                      ),
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () {
                              final result = widget.orders
                                  .where((o) => _selectedIds.contains(o.id))
                                  .toList();
                              Navigator.of(context).pop(result);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
