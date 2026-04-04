import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../orders/providers/order_provider.dart';
import '../../../data/models/order.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/empty_state.dart';

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['All', 'Requested', 'Received', 'Refunded', 'Rejected'];

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

  List<Order> _filterReturns(List<Order> allOrders) =>
      allOrders.where((o) => o.isReturn).toList();

  List<int> _getCounts(List<Order> returns) {
    int requested = 0, received = 0, refunded = 0, rejected = 0;
    for (final o in returns) {
      switch (o.returnStatus) {
        case ReturnStatus.requested || ReturnStatus.approved:
          requested++;
        case ReturnStatus.received:
          received++;
        case ReturnStatus.refunded:
          refunded++;
        case ReturnStatus.rejected:
          rejected++;
        case ReturnStatus.none:
          break;
      }
    }
    return [returns.length, requested, received, refunded, rejected];
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns & Refunds'),
        bottom: ordersAsync.whenOrNull(
              data: (allOrders) {
                final returns = _filterReturns(allOrders);
                final counts = _getCounts(returns);
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    for (int i = 0; i < _tabs.length; i++)
                      Tab(child: _TabLabel(label: _tabs[i], count: counts[i])),
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
          final returns = _filterReturns(allOrders);
          final requested = returns
              .where((o) =>
                  o.returnStatus == ReturnStatus.requested ||
                  o.returnStatus == ReturnStatus.approved)
              .toList();
          final received = returns
              .where((o) => o.returnStatus == ReturnStatus.received)
              .toList();
          final refunded = returns
              .where((o) => o.returnStatus == ReturnStatus.refunded)
              .toList();
          final rejected = returns
              .where((o) => o.returnStatus == ReturnStatus.rejected)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _ReturnList(orders: returns),
              _ReturnList(orders: requested),
              _ReturnList(orders: received),
              _ReturnList(orders: refunded),
              _ReturnList(orders: rejected),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─── Tab label with count badge ──────────────────────────────────────────────

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
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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

// ─── Return list ─────────────────────────────────────────────────────────────

class _ReturnList extends StatelessWidget {
  final List<Order> orders;
  const _ReturnList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_return_rounded,
        title: 'No returns',
        subtitle: 'Return orders will appear here',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ReturnCard(order: orders[i]),
    );
  }
}

// ─── Return card ─────────────────────────────────────────────────────────────

class _ReturnCard extends StatelessWidget {
  final Order order;
  const _ReturnCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: order numbers + date
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
                if (order.originalOrderId > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.link_rounded, size: 13, color: muted),
                  const SizedBox(width: 3),
                  Text(
                    'ORD-${order.originalOrderId.toString().padLeft(3, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                const Spacer(),
                Text(
                  DateFormatter.format(order.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: customer + reason chip + status badge
            Row(
              children: [
                if (order.customerName.isNotEmpty) ...[
                  Icon(Icons.person_outline_rounded, size: 13, color: muted),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      order.customerName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _ReasonChip(reason: order.returnReason),
                const Spacer(),
                _ReturnStatusBadge(status: order.returnStatus),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: items count + refund amount
            Row(
              children: [
                Text(
                  '${order.totalItems} item${order.totalItems != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(order.refundAmount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reason chip ─────────────────────────────────────────────────────────────

class _ReasonChip extends StatelessWidget {
  final ReturnReason reason;
  const _ReasonChip({required this.reason});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (reason) {
      ReturnReason.defective => ('Defective', Colors.red),
      ReturnReason.wrongItem => ('Wrong Item', Colors.orange),
      ReturnReason.damaged => ('Damaged', Colors.red),
      ReturnReason.changedMind => ('Changed Mind', Colors.blue),
      ReturnReason.other => ('Other', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── Return status badge ─────────────────────────────────────────────────────

class _ReturnStatusBadge extends StatelessWidget {
  final ReturnStatus status;
  const _ReturnStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReturnStatus.none => ('None', Colors.grey),
      ReturnStatus.requested => ('Requested', Colors.orange),
      ReturnStatus.approved || ReturnStatus.received => ('Received', Colors.blue),
      ReturnStatus.refunded => ('Refunded', Colors.green),
      ReturnStatus.rejected => ('Rejected', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
