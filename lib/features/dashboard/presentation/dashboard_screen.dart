import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../../features/orders/providers/order_provider.dart';
import '../../../features/expenses/providers/expense_provider.dart';
import '../../../data/models/order.dart';
import '../../../data/models/expense.dart';
import '../../../data/services/update_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/tutorial_service.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../shared/widgets/rate_app_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/loading_overlay.dart';
import 'widgets/stat_card.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'widgets/sales_chart.dart';
import 'widgets/low_stock_list.dart';
import 'widgets/due_summary_card.dart';
import '../../customers/providers/dues_provider.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate();
      _maybeAskForReview();
    });
  }

  /// Ported from the Fuel Cost app: ask happy, regular sellers for a Play
  /// rating. See [ReviewService] for the eligibility and back-off rules.
  Future<void> _maybeAskForReview() async {
    // The showcase tour runs on first launch — a dialog on top of its
    // spotlight overlay would trap the user, so let the tour finish first.
    if (!await TutorialService.isTourCompleted()) return;
    if (!mounted) return;
    final isar = await ref.read(isarProvider.future);
    if (!await ReviewService.isEligible(isar)) return;
    // Never ask and then do nothing (non-Play installs, iOS, desktop).
    if (!await ReviewService.canPrompt()) return;
    if (!mounted) return;

    // Let the entrance animations settle before interrupting.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final choice = await showDialog<RateAppChoice>(
      context: context,
      builder: (_) => const RateAppDialog(),
    );

    switch (choice) {
      case RateAppChoice.rate:
        await ReviewService.requestReview();
        await ReviewService.markRated();
      case RateAppChoice.decline:
        await ReviewService.markDeclined();
        if (mounted) {
          context.showSnackBar(AppStrings.of(context).thanksFeedback);
        }
      // "Later", or dismissed by tapping outside — ask again after a cooldown.
      case RateAppChoice.later:
      case null:
        await ReviewService.markSnoozed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final statsAsync = ref.watch(dashboardStatsProvider);
    // Due info comes from the Due Book's own providers, so the dashboard and
    // the Due Book can never disagree.
    final dues = ref.watch(duesProvider).value ?? const <CustomerDue>[];
    final dueSummary = ref.watch(dueSummaryProvider) ?? const DueSummary();
    final collectedThisMonth =
        ref.watch(duesCollectedThisMonthProvider).value ?? 0;
    final ordersAsync = ref.watch(ordersProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardStatsProvider),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            return CustomScrollView(
              slivers: [
                // ── Header ──
                _buildHeader(statsAsync, theme),

                // ── Date Range Filter ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _DateRangeBar(),
                  ),
                ),

                // ── 60+ days overdue alert ──
                if (dueSummary.over60Count > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _OverdueBanner(summary: dueSummary),
                    ),
                  ),

                // ── Body ──
                SliverToBoxAdapter(
                  // Keep showing the last numbers while stats recompute
                  // after an order change, instead of flashing a skeleton.
                  child: statsAsync.when(
                    skipLoadingOnReload: true,
                    data: (stats) {
                      // Compute order status counts
                      final statusCounts = <String, int>{};
                      final allOrders =
                          ordersAsync.value ?? <Order>[];
                      for (final o in allOrders) {
                        final label = o.orderStatus.name[0].toUpperCase() +
                            o.orderStatus.name.substring(1);
                        statusCounts[label] =
                            (statusCounts[label] ?? 0) + 1;
                      }

                      // Compute daily expenses for last 7 days
                      final allExpenses =
                          expensesAsync.value ?? <Expense>[];
                      final dailyExpenses = <int, double>{};
                      for (int i = 0; i < stats.weeklySales.length; i++) {
                        final day = stats.weeklySales[i].date;
                        final dayEnd = day.add(const Duration(days: 1));
                        double total = 0;
                        for (final e in allExpenses) {
                          if (e.date != null &&
                              !e.date!.isBefore(day) &&
                              e.date!.isBefore(dayEnd)) {
                            total += e.amount;
                          }
                        }
                        dailyExpenses[i] = total;
                      }

                      final dateRange = ref.watch(dashboardDateRangeProvider);
                      final totalExpensesThisMonth = _rangeExpenses(
                        allExpenses,
                        dateRange.start,
                        dateRange.end,
                      );

                      return _DashboardBody(
                        stats: stats,
                        statusCounts: statusCounts,
                        dailyExpenses: dailyExpenses,
                        monthExpenses: totalExpensesThisMonth,
                        receivable: dueSummary.total,
                        collectedThisMonth: collectedThisMonth,
                        isWide: isWide,
                      );
                    },
                    loading: () => _DashboardSkeleton(isWide: isWide),
                    error: (error, _) =>
                        _ErrorBody(error: error.toString()),
                  ),
                ),

                // ── Bottom sections ──
                SliverToBoxAdapter(
                  child: statsAsync.whenOrNull(
                        skipLoadingOnReload: true,
                        data: (stats) {
                          final hasDues = dues.isNotEmpty;
                          if (stats.lowStockProducts.isEmpty && !hasDues) {
                            return const SizedBox(height: 24);
                          }

                          if (isWide) {
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (stats.lowStockProducts.isNotEmpty)
                                    Expanded(
                                      child: _SectionCard(
                                        title: s.lowStockItems,
                                        icon: tabler.Package.new,
                                        iconColor: AppColors.statusPending,
                                        action: TextButton(
                                          onPressed: () =>
                                              context.go('/inventory'),
                                          child: Text(s.viewAll),
                                        ),
                                        child: LowStockList(
                                            products:
                                                stats.lowStockProducts),
                                      ),
                                    ),
                                  if (stats.lowStockProducts.isNotEmpty &&
                                      hasDues)
                                    const SizedBox(width: 12),
                                  if (hasDues)
                                    Expanded(
                                      child: _dueSection(
                                          context, dueSummary, dues),
                                    ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: [
                              if (stats.lowStockProducts.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 12),
                                  child: _SectionCard(
                                    title: s.lowStockItems,
                                    icon: tabler.Package.new,
                                    iconColor: AppColors.statusPending,
                                    action: TextButton(
                                      onPressed: () =>
                                          context.go('/inventory'),
                                      child: Text(s.viewAll),
                                    ),
                                    child: LowStockList(
                                        products: stats.lowStockProducts),
                                  ),
                                ),
                              if (hasDues)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 24),
                                  child: _dueSection(
                                      context, dueSummary, dues),
                                ),
                            ],
                          );
                        },
                      ) ??
                      const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dueSection(
      BuildContext context, DueSummary summary, List<CustomerDue> dues) {
    final s = AppStrings.of(context);
    return _SectionCard(
      title: s.dueBook,
      icon: tabler.Notebook.new,
      iconBuilder: AppIcons.dueBook,
      iconColor: AppColors.paymentPartial,
      action: TextButton(
        onPressed: () => context.go('/dues'),
        child: Text(s.viewAll),
      ),
      child: DueSummaryCard(summary: summary, dues: dues),
    );
  }

  double _rangeExpenses(List<Expense> expenses, DateTime start, DateTime end) {
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    double total = 0;
    for (final e in expenses) {
      if (e.date != null &&
          !e.date!.isBefore(start) &&
          e.date!.isBefore(endOfDay)) {
        total += e.amount;
      }
    }
    return total;
  }

  SliverAppBar _buildHeader(
      AsyncValue<DashboardStats> statsAsync, ThemeData theme) {
    final s = AppStrings.of(context);
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      centerTitle: false,
      title: Builder(
        builder: (_) {
          // Watch the settings map so a shop-name change rebuilds this title.
          ref.watch(settingsProvider);
          final shopName = ref.read(settingsProvider.notifier).shopName;
          return Text(
            shopName.isNotEmpty ? shopName : AppStrings.appName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.dashboardGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          DateFormatter.format(DateTime.now()),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  statsAsync.when(
                    skipLoadingOnReload: true,
                    data: (stats) => Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.todayRevenue,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                            Text(
                              CurrencyFormatter.format(stats.todayRevenue),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(s.totalOrders,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                            Text(
                              '${stats.totalOrders}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    loading: () => Container(
                      width: 100,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final s = AppStrings.of(context);
    final hour = DateTime.now().hour;
    if (hour < 12) return s.goodMorning;
    if (hour < 17) return s.goodAfternoon;
    return s.goodEvening;
  }
}

// ─── Dashboard Body ─────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final DashboardStats stats;
  final Map<String, int> statusCounts;
  final Map<int, double> dailyExpenses;
  final double monthExpenses;
  final double receivable;
  final double collectedThisMonth;
  final bool isWide;

  const _DashboardBody({
    required this.stats,
    required this.statusCounts,
    required this.dailyExpenses,
    required this.monthExpenses,
    required this.receivable,
    required this.collectedThisMonth,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // ── Stat cards ──
          _buildStatCards(context),
          const SizedBox(height: 14),

          // ── Charts ──
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stats.weeklySales.isNotEmpty)
                  Expanded(
                    flex: 3,
                    child: _SectionCard(
                      title: s.weeklySales,
                      icon: tabler.ChartBar.new,
                      iconColor: AppColors.primary,
                      child: SalesChart(weeklySales: stats.weeklySales),
                    ),
                  ),
                if (stats.weeklySales.isNotEmpty &&
                    statusCounts.isNotEmpty)
                  const SizedBox(width: 12),
                if (statusCounts.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: _SectionCard(
                      title: s.orderStatus,
                      icon: tabler.ChartDonut.new,
                      iconColor: AppColors.statusConfirmed,
                      child:
                          OrderStatusChart(statusCounts: statusCounts),
                    ),
                  ),
              ],
            )
          else ...[
            if (stats.weeklySales.isNotEmpty)
              _SectionCard(
                title: s.weeklySales,
                icon: tabler.ChartBar.new,
                iconColor: AppColors.primary,
                child: SalesChart(weeklySales: stats.weeklySales),
              ),
            if (stats.weeklySales.isNotEmpty) const SizedBox(height: 14),
            if (statusCounts.isNotEmpty)
              _SectionCard(
                title: s.orderStatus,
                icon: tabler.ChartDonut.new,
                iconColor: AppColors.statusConfirmed,
                child: OrderStatusChart(statusCounts: statusCounts),
              ),
            if (statusCounts.isNotEmpty) const SizedBox(height: 14),
          ],

          // Revenue vs Expenses
          if (stats.weeklySales.isNotEmpty) ...[
            if (!isWide) ...[
              _SectionCard(
                title: s.revenueVsExpenses,
                icon: tabler.ArrowsLeftRight.new,
                iconColor: AppColors.chartProfit,
                child: RevenueExpenseChart(
                  weeklySales: stats.weeklySales,
                  dailyExpenses: dailyExpenses,
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              _SectionCard(
                title: s.revenueVsExpenses7d,
                icon: tabler.ArrowsLeftRight.new,
                iconColor: AppColors.chartProfit,
                child: RevenueExpenseChart(
                  weeklySales: stats.weeklySales,
                  dailyExpenses: dailyExpenses,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final s = AppStrings.of(context);
    // `route` makes a card tappable (null = not tappable).
    final items = <({String label, String value, ThinIconBuilder icon, Color color, String? route})>[
      (
        label: s.monthRevenue,
        value: CurrencyFormatter.formatCompact(stats.thisMonthRevenue),
        icon: AppIcons.revenue,
        color: AppColors.primary,
        route: null,
      ),
      (
        label: s.monthProfit,
        value: CurrencyFormatter.formatCompact(stats.thisMonthProfit),
        icon: AppIcons.profit,
        color: const Color(0xFF42A5F5),
        route: null,
      ),
      (
        label: s.monthExpenses,
        value: CurrencyFormatter.formatCompact(monthExpenses),
        icon: AppIcons.expenses,
        color: AppColors.statusCancelled,
        route: '/expenses',
      ),
      (
        label: s.pendingOrders,
        value: '${stats.pendingOrders}',
        icon: AppIcons.pending,
        color: AppColors.statusPending,
        route: '/orders',
      ),
      (
        label: s.totalReceivable,
        value: CurrencyFormatter.formatCompact(receivable),
        icon: AppIcons.dueBook,
        color: AppColors.paymentUnpaid,
        route: '/dues',
      ),
      (
        label: s.duesCollectedThisMonth,
        value: CurrencyFormatter.formatCompact(collectedThisMonth),
        icon: AppIcons.collected,
        color: AppColors.paymentPaid,
        route: '/dues',
      ),
      (
        label: s.lowStockItems,
        value: '${stats.lowStockProducts.length}',
        icon: AppIcons.lowStock,
        color: AppColors.statusPending,
        route: '/inventory',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Each card wants ~160px min, grows to fill
        final availableWidth = constraints.maxWidth;
        final cols = (availableWidth / 170).floor().clamp(2, 6);
        const spacing = 10.0;
        final cardWidth =
            (availableWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(items.length, (i) {
            final item = items[i];
            return AnimatedEntrance(
              index: i,
              child: SizedBox(
                width: cardWidth,
                height: 110,
                child: StatCard(
                  label: item.label,
                  value: item.value,
                  iconBuilder: item.icon,
                  color: item.color,
                  onTap: item.route == null
                      ? null
                      : () => context.go(item.route!),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── 60+ days overdue banner ───────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.summary});

  final DueSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    const color = AppColors.paymentPartial;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Opens the Due Book pre-filtered to the 60+ days bucket.
        onTap: () => context.go('/dues?age=60'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              const ThinIcon(AppIcons.alert, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.overdue60Banner(summary.over60Count,
                      CurrencyFormatter.format(summary.over60)),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/dues?age=60'),
                child: Text(s.open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final ThinIconBuilder icon;

  /// Thin Tabler icon; when set it's drawn instead of [icon].
  final ThinIconBuilder? iconBuilder;
  final Color iconColor;
  final Widget? action;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconBuilder,
    required this.iconColor,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: iconBuilder != null
                      ? ThinIcon(iconBuilder!, color: iconColor, size: 16)
                      : ThinIcon(icon, color: iconColor, size: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Date Range Bar ────────────────────────────────────────────────────────

class _DateRangeBar extends ConsumerWidget {
  static final _chipDateFormat = DateFormat('dd MMM');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final dateRange = ref.watch(dashboardDateRangeProvider);
    final notifier = ref.read(dashboardDateRangeProvider.notifier);
    final theme = Theme.of(context);
    final activePreset = dateRange.preset;

    final rangeLabel =
        '${_chipDateFormat.format(dateRange.start)} - ${_chipDateFormat.format(dateRange.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildChip(
              context,
              label: s.today,
              isActive: activePreset == DateRangePreset.today,
              onTap: () => notifier.setToday(),
            ),
            const SizedBox(width: 8),
            _buildChip(
              context,
              label: s.thisWeek,
              isActive: activePreset == DateRangePreset.thisWeek,
              onTap: () => notifier.setThisWeek(),
            ),
            const SizedBox(width: 8),
            _buildChip(
              context,
              label: s.thisMonth,
              isActive: activePreset == DateRangePreset.thisMonth,
              onTap: () => notifier.setThisMonth(),
            ),
            const Spacer(),
            IconButton(
              icon: ThinIcon(
                tabler.CalendarEvent.new,
                size: 20,
                color: activePreset == DateRangePreset.custom
                    ? AppColors.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: s.customRange,
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(
                    start: dateRange.start,
                    end: dateRange.end,
                  ),
                  builder: (context, child) {
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: AppColors.primary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  notifier.setRange(picked.start, picked.end);
                }
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            rangeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton ───────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  final bool isWide;
  const _DashboardSkeleton({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = (constraints.maxWidth / 170).floor().clamp(2, 6);
          const spacing = 10.0;
          final cardWidth =
              (constraints.maxWidth - spacing * (cols - 1)) / cols;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(
              6,
              (_) => SizedBox(
                width: cardWidth,
                height: 110,
                child: const LoadingShimmer(
                    height: double.infinity, borderRadius: 14),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Error ──────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const ThinIcon(tabler.AlertCircle.new, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(AppStrings.of(context).errorOccurred,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(error,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
