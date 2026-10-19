import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/customer.dart';
import '../providers/customer_detail_providers.dart';
import '../providers/customer_provider.dart';
import '../providers/dues_provider.dart';
import 'widgets/due_actions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../settings/providers/trash_provider.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../orders/presentation/widgets/order_card.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    // Live, so collecting a payment from here refreshes the stats below.
    return ref.watch(customerByIdProvider(customerId)).when(
      skipLoadingOnReload: true,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (customer) {
        if (customer == null) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(s.customerNotFound)));
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
                icon: const ThinIcon(tabler.Pencil.new),
                onPressed: () =>
                    context.push('/customers/$customerId/edit'),
              ),
              IconButton(
                icon: const ThinIcon(tabler.Trash.new),
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: s.deleteCustomer,
                    message: '${s.delete} ${customer.name}?',
                    confirmText: s.delete,
                    isDestructive: true,
                    icon: tabler.Trash.new,
                  );
                  if (ok == true && context.mounted) {
                    final trashId = await ref
                        .read(customerProvider.notifier)
                        .deleteCustomer(customer.id);
                    if (!context.mounted) return;
                    context.pop();
                    // Shown after the pop so the snackbar lands on the list
                    // screen rather than a detail screen that's unwinding.
                    if (trashId != null) {
                      context.showUndoSnackBar(
                        '${s.itemDeleted}: ${customer.name}',
                        onUndo: () =>
                            ref.read(trashProvider.notifier).restore(trashId),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          // Slivers, so the purchase history only builds the cards on screen.
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
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
                            // Centred under the avatar when a long name
                            // wraps, too.
                            Text(
                              customer.name,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (customer.phone.isNotEmpty)
                              Text(
                                customer.phone,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
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
                              label: s.orders,
                              value: '${customer.totalOrders}',
                              icon: tabler.Receipt.new,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatChip(
                              label: s.totalSpent,
                              value: CurrencyFormatter.formatCompact(
                                  customer.totalSpent),
                              icon: tabler.Cash.new,
                              color: AppColors.statusCompleted,
                            ),
                          ),
                          if (customer.outstandingBalance > 0) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatChip(
                                label: s.outstanding,
                                value: CurrencyFormatter.formatCompact(
                                    customer.outstandingBalance),
                                icon: tabler.CashOff.new,
                                color: AppColors.paymentUnpaid,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      _DueActions(customer: customer),

                      if (customer.address.isNotEmpty ||
                          customer.notes.isNotEmpty) ...[
                        _InfoCard(children: [
                          if (customer.address.isNotEmpty)
                            _InfoRow(s.address, customer.address),
                          if (customer.notes.isNotEmpty)
                            _InfoRow(s.notes, customer.notes),
                          _InfoRow(s.tr('memberSince'),
                              DateFormatter.format(customer.createdAt)),
                        ]),
                        const SizedBox(height: 16),
                      ],

                      // Purchase History Chart
                      _PurchaseChartSection(customerId: customerId),

                      _PaymentHistory(customerId: customerId),

                      // Customer orders
                      Text(s.purchaseHistory,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: _PurchaseHistoryList(customerId: customerId),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The 6-month purchase chart, hidden until loaded and when the customer has
/// no orders apart from cancelled ones.
class _PurchaseChartSection extends ConsumerWidget {
  const _PurchaseChartSection({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spending =
        ref.watch(customerMonthlySpendingProvider(customerId)).value;
    if (spending == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _PurchaseHistoryChart(monthlySpending: spending),
    );
  }
}

/// The customer's orders, newest first, as a lazily built sliver. Paged:
/// nearing the end of the loaded rows loads the next page, with a spinner
/// row below while more exist.
class _PurchaseHistoryList extends ConsumerStatefulWidget {
  const _PurchaseHistoryList({required this.customerId});

  final int customerId;

  @override
  ConsumerState<_PurchaseHistoryList> createState() =>
      _PurchaseHistoryListState();
}

class _PurchaseHistoryListState extends ConsumerState<_PurchaseHistoryList> {
  /// How close to the last loaded row the next page is requested.
  static const _loadMoreAhead = 20;
  bool _loadMoreScheduled = false;

  // After the frame: the notifier's state can't change during a build.
  void _loadMoreSoon() {
    if (_loadMoreScheduled) return;
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (mounted) {
        ref.read(customerOrdersProvider(widget.customerId).notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    final empty = SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            s.addFirstOrder,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );

    return ref.watch(customerOrdersProvider(widget.customerId)).when(
      skipLoadingOnReload: true,
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => empty,
      data: (page) {
        final orders = page.orders;
        if (orders.isEmpty) return empty;
        return SliverList.builder(
          itemCount: orders.length + (page.hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (page.hasMore && i >= orders.length - _loadMoreAhead) {
              _loadMoreSoon();
            }
            if (i == orders.length) {
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrderCard(order: orders[i]),
            );
          },
        );
      },
    );
  }
}

/// Collect / Remind / Statement. Collect and Remind only when something is
/// actually owed (computed from orders, not the stored counter).
class _DueActions extends ConsumerWidget {
  const _DueActions({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final due = ref
        .watch(duesProvider)
        .value
        ?.where((d) => d.customer.id == customer.id)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (due != null) ...[
            FilledButton.icon(
              onPressed: () =>
                  showCollectPaymentSheet(
                  context, customer, due.orderDues, due.totalDue),
              icon: const ThinIcon(tabler.Cash.new, size: 18),
              label: Text(s.collect),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  sendDueReminder(
                  context, ref, customer, due.orderDues, due.totalDue),
              icon: const ThinIcon(tabler.MessageCircle.new, size: 18),
              label: Text(s.remind),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => shareCustomerStatement(context, ref, customer),
            icon: const ThinIcon(tabler.FileDescription.new, size: 18),
            label: Text(s.statement),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistory extends ConsumerWidget {
  const _PaymentHistory({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final payments = ref.watch(customerPaymentsProvider(customerId)).value;
    if (payments == null || payments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.paymentHistory,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final p in payments.take(10))
            PaymentHistoryTile(
              payment: p,
              onTap: () => context.push('/orders/${p.orderId}'),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final ThinIconBuilder icon;
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
          ThinIcon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          // Three chips share a narrow row: the number shrinks to fit rather
          // than breaking mid-number.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          _WordSafeLabel(
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

/// A label that wraps between words as a [Text] does, except that a single
/// word wider than the room (a narrow chip, large text) shrinks the label to
/// fit on one line instead of breaking mid-word.
class _WordSafeLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _WordSafeLabel(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // The style a Text resolves (ambient style, bold text if asked for).
      var effective = style;
      if (style == null || style!.inherit) {
        effective = DefaultTextStyle.of(context).style.merge(style);
      }
      if (MediaQuery.boldTextOf(context)) {
        effective =
            effective!.merge(const TextStyle(fontWeight: FontWeight.bold));
      }
      final painter = TextPainter(
        text: TextSpan(text: text, style: effective),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      // A paragraph's minimum width is its longest word.
      final longestWord = painter.minIntrinsicWidth;
      painter.dispose();
      if (longestWord <= constraints.maxWidth) return Text(text, style: style);
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: style, maxLines: 1),
      );
    });
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
    final labelText = Text(label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ));
    final valueText = Text(value,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      // The label in a 110 px column beside the value; above it when that
      // leaves the value too narrow a column (about 15 characters), as on
      // a narrow layout or with large text, where an address would run
      // down the card a word-fragment at a time.
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth - 110 <
                    MediaQuery.textScalerOf(context).scale(120)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [labelText, valueText],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 110, child: labelText),
                      Expanded(child: valueText),
                    ],
                  ),
      ),
    );
  }
}

class _PurchaseHistoryChart extends StatelessWidget {
  final Map<DateTime, double> monthlySpending;

  const _PurchaseHistoryChart({required this.monthlySpending});

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = monthlySpending.entries.toList();
    final maxY = entries.fold<double>(
        0, (prev, e) => e.value > prev ? e.value : prev);
    final effectiveMaxY = maxY == 0 ? 100.0 : maxY * 1.2;
    // The axis labels' slots grow with the text size (the coded sizes at
    // 100%), so a larger font doesn't cut the month names off or wrap the
    // amounts mid-number. A month name is an 11 px line (in the ambient line
    // height, which lays out to a whole pixel) under 6 px of padding;
    // fl_chart's default slot is 22 px.
    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeight = DefaultTextStyle.of(context).style.height ?? 1.2;
    final monthTitleHeight = math.max(
        22.0, 6 + (textScaler.scale(11) * lineHeight).ceilToDouble());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ThinIcon(tabler.ChartBar.new,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Purchase History (6 months)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: RepaintBoundary(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: effectiveMaxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = entries[group.x.toInt()].key;
                        return BarTooltipItem(
                          '${_monthNames[month.month - 1]}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: CurrencyFormatter.formatCompact(rod.toY),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: textScaler.scale(46),
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            // Shrunk to fit its slot, never wrapped.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                CurrencyFormatter.formatCompact(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: monthTitleHeight,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final month = entries[idx].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _monthNames[month.month - 1],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: effectiveMaxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.06),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          color: AppColors.primary,
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
