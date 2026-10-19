import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../orders/providers/order_provider.dart';
import '../../../data/models/order.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabCount = 5;

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

  List<String> _tabLabels(BuildContext context) {
    final s = AppStrings.of(context);
    return [s.all, s.tr('requested'), s.tr('received'), s.tr('refunded'), s.tr('rejected')];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // Only the return orders, newest first — not every order filtered here.
    final returnsAsync = ref.watch(returnOrdersProvider);
    final tabs = _tabLabels(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.returnsAndRefunds),
        bottom: returnsAsync.whenOrNull(
              data: (returns) {
                final counts = _getCounts(returns);
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    for (int i = 0; i < tabs.length; i++)
                      Tab(child: _TabLabel(label: tabs[i], count: counts[i])),
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
      body: returnsAsync.when(
        data: (returns) {
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
        error: (e, _) =>
            Center(child: Text('${AppStrings.of(context).error}: $e')),
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
      final s = AppStrings.of(context);
      return EmptyState(
        icon: tabler.ArrowBackUp.new,
        title: s.noReturns,
        subtitle: s.returnOrdersAppearHere,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => AnimatedEntrance(
        index: i,
        child: _ReturnCard(order: orders[i]),
      ),
    );
  }
}

// ─── Return card ─────────────────────────────────────────────────────────────

/// The width [text] takes on one line as a [Text] with [style] draws it here:
/// in the ambient text style and text size, bold if the phone asks for it.
double _textWidth(BuildContext context, String text, TextStyle? style) {
  var effective = style;
  if (style == null || style.inherit) {
    effective = DefaultTextStyle.of(context).style.merge(style);
  }
  if (MediaQuery.boldTextOf(context)) {
    effective = effective!.merge(const TextStyle(fontWeight: FontWeight.bold));
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

class _ReturnCard extends StatelessWidget {
  final Order order;
  const _ReturnCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);

    final numberStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    final orderNumber = Text(
      order.orderNumber,
      style: numberStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final original = 'ORD-${order.originalOrderId.toString().padLeft(3, '0')}';
    final originalStyle = theme.textTheme.bodySmall?.copyWith(color: muted);
    final link = [
      const SizedBox(width: 8),
      ThinIcon(tabler.Link.new, size: 13, color: muted),
      const SizedBox(width: 3),
    ];
    final date = DateFormatter.format(order.createdAt);
    final dateStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.4),
      fontSize: 11,
    );
    final nameStyle = theme.textTheme.bodySmall
        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6));
    final customer = [
      ThinIcon(tabler.User.new, size: 13, color: muted),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          order.customerName,
          style: nameStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];
    final (reason, reasonColor) = _reasonLabel(context, order.returnReason);
    final (status, statusColor) = _statusLabel(context, order.returnStatus);

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
        // Each row keeps to one line, its text truncated only for want of
        // room, with the date and the status at the far end. Where a row's
        // fixed parts don't fit side by side (a narrow layout, large text,
        // long numbers), it breaks onto two lines instead of overflowing.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Everything in row 1 whole, the date at least 8 px away.
            final linkWidth = order.originalOrderId > 0
                ? 24 + _textWidth(context, original, originalStyle)
                : 0.0;
            final row1Fits =
                _textWidth(context, order.orderNumber, numberStyle) +
                        linkWidth +
                        8 +
                        _textWidth(context, date, dateStyle) <=
                    width;
            // Both pills whole, and room for at least the first few letters
            // of the customer.
            final nameWidth = order.customerName.isEmpty
                ? 0.0
                : 24 +
                    math.min(
                      _textWidth(context, order.customerName, nameStyle),
                      MediaQuery.textScalerOf(context).scale(48),
                    );
            final row2Fits = nameWidth +
                    _Pill.widthOf(context, reason) +
                    8 +
                    _Pill.widthOf(context, status) <=
                width;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: order numbers + date
                if (row1Fits)
                  Row(
                    children: [
                      orderNumber,
                      if (order.originalOrderId > 0) ...[
                        ...link,
                        Text(original, style: originalStyle),
                      ],
                      const Spacer(),
                      Text(date, style: dateStyle),
                    ],
                  )
                else ...[
                  // The numbers shrink to fit rather than ending in an
                  // ellipsis, which would hide the digits that tell them
                  // apart.
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(order.orderNumber, style: numberStyle),
                        ),
                      ),
                      if (order.originalOrderId > 0) ...[
                        ...link,
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(original, style: originalStyle),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: dateStyle),
                ],
                const SizedBox(height: 8),
                // Row 2: customer + reason chip + status badge
                if (row2Fits)
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (order.customerName.isNotEmpty) ...[
                              ...customer,
                              const SizedBox(width: 8),
                            ],
                            _Pill(label: reason, color: reasonColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Pill(label: status, color: statusColor, vertical: 3),
                    ],
                  )
                else ...[
                  if (order.customerName.isNotEmpty) ...[
                    Row(children: customer),
                    const SizedBox(height: 4),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _Pill(label: reason, color: reasonColor),
                      _Pill(label: status, color: statusColor, vertical: 3),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Row 3: items count + refund amount, which shrinks to fit
                // rather than overflowing.
                Row(
                  children: [
                    Text(
                      '${order.totalItems} item${order.totalItems != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(order.refundAmount),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Reason chip and status badge ────────────────────────────────────────────

(String, Color) _reasonLabel(BuildContext context, ReturnReason reason) {
  final s = AppStrings.of(context);
  return switch (reason) {
    ReturnReason.defective => (s.defective, Colors.red),
    ReturnReason.wrongItem => (s.wrongItem, Colors.orange),
    ReturnReason.damaged => (s.tr('damaged'), Colors.red),
    ReturnReason.changedMind => (s.changedMind, Colors.blue),
    ReturnReason.other => (s.other, Colors.grey),
  };
}

(String, Color) _statusLabel(BuildContext context, ReturnStatus status) {
  final s = AppStrings.of(context);
  return switch (status) {
    ReturnStatus.none => (s.tr('none'), Colors.grey),
    ReturnStatus.requested => (s.tr('requested'), Colors.orange),
    ReturnStatus.approved ||
    ReturnStatus.received =>
      (s.tr('received'), Colors.blue),
    ReturnStatus.refunded => (s.tr('refunded'), Colors.green),
    ReturnStatus.rejected => (s.tr('rejected'), Colors.red),
  };
}

/// A coloured label pill: the reason chip, or the status badge (with 3 px of
/// vertical padding rather than 2).
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final double vertical;
  const _Pill({required this.label, required this.color, this.vertical = 2});

  static const _style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

  /// The width the pill takes on one line.
  static double widthOf(BuildContext context, String label) =>
      _textWidth(context, label, _style) + 16;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: vertical),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      // Stays one line when the card is too narrow for it.
      child: Text(
        label,
        style: _style.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
