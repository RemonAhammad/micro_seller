import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../../../features/orders/providers/order_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/loading_overlay.dart';
import 'widgets/stat_card.dart';
import 'widgets/sales_chart.dart';
import 'widgets/low_stock_list.dart';
import 'widgets/unpaid_orders_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final unpaidOrdersAsync = ref.watch(unpaidOrdersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardStatsProvider),
        child: CustomScrollView(
          slivers: [
            // Fancy gradient header
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.dashboardGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    AppStrings.appName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  DateFormatter.format(DateTime.now()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Today's revenue quick stat
                          statsAsync.when(
                            data: (stats) => _TodayRevenueBanner(
                              revenue: stats.todayRevenue,
                              ordersCount: stats.totalOrders,
                            ),
                            loading: () => const _TodayRevenueBannerSkeleton(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => _DashboardBody(stats: stats),
                loading: () => const _DashboardSkeleton(),
                error: (error, _) => _ErrorBody(error: error.toString()),
              ),
            ),

            // Unpaid orders section
            SliverToBoxAdapter(
              child: unpaidOrdersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _SectionCard(
                      title: AppStrings.unpaidAmount,
                      icon: Icons.payment_rounded,
                      iconColor: AppColors.paymentUnpaid,
                      action: TextButton(
                        onPressed: () => context.go('/orders'),
                        child: const Text('View All'),
                      ),
                      child: UnpaidOrdersWidget(orders: orders),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }
}

class _TodayRevenueBanner extends StatelessWidget {
  final double revenue;
  final int ordersCount;

  const _TodayRevenueBanner(
      {required this.revenue, required this.ordersCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Revenue",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              CurrencyFormatter.format(revenue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
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
            const Text(
              'Total Orders',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '$ordersCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayRevenueBannerSkeleton extends StatelessWidget {
  const _TodayRevenueBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 120,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardStats stats;

  const _DashboardBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats grid
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              StatCard(
                label: AppStrings.monthRevenue,
                value: CurrencyFormatter.formatCompact(stats.thisMonthRevenue),
                icon: Icons.trending_up_rounded,
                color: AppColors.primary,
              ),
              StatCard(
                label: AppStrings.monthProfit,
                value: CurrencyFormatter.formatCompact(stats.thisMonthProfit),
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF42A5F5),
              ),
              StatCard(
                label: AppStrings.pendingOrders,
                value: '${stats.pendingOrders}',
                icon: Icons.hourglass_top_rounded,
                color: AppColors.statusPending,
              ),
              StatCard(
                label: AppStrings.unpaidAmount,
                value: CurrencyFormatter.formatCompact(stats.unpaidTotal),
                icon: Icons.money_off_rounded,
                color: AppColors.paymentUnpaid,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sales chart
        if (stats.weeklySales.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _SectionCard(
              title: AppStrings.weeklySales,
              icon: Icons.bar_chart_rounded,
              iconColor: AppColors.primary,
              child: SalesChart(weeklySales: stats.weeklySales),
            ),
          ),
        const SizedBox(height: 20),

        // Low stock
        if (stats.lowStockProducts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _SectionCard(
              title: AppStrings.lowStockItems,
              icon: Icons.inventory_2_rounded,
              iconColor: AppColors.statusPending,
              action: TextButton(
                onPressed: () => GoRouter.of(context).go('/products'),
                child: const Text('View All'),
              ),
              child: LowStockList(products: stats.lowStockProducts),
            ),
          )
        else
          const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget? action;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: List.generate(
              4,
              (_) => const LoadingShimmer(height: double.infinity, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load dashboard', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
