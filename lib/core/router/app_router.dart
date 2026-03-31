import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/categories/presentation/category_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/orders/presentation/order_list_screen.dart';
import '../../features/orders/presentation/order_form_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/customers/presentation/customer_form_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/stock_adjustment_screen.dart';
import '../../features/expenses/presentation/expense_list_screen.dart';
import '../../features/expenses/presentation/expense_form_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../shared/widgets/drawer_menu_button.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _NavigationShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const ProductFormScreen(product: null),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) => ProductDetailScreen(
                    productId: int.parse(s.pathParameters['id']!)),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, s) => ProductFormScreen(
                        productId: int.parse(s.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrderListScreen(),
            routes: [
              GoRoute(
                  path: 'add', builder: (_, __) => const OrderFormScreen()),
              GoRoute(
                path: ':id',
                builder: (_, s) => OrderDetailScreen(
                    orderId: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/customers',
            builder: (_, __) => const CustomerListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) =>
                    const CustomerFormScreen(customer: null),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) => CustomerDetailScreen(
                    customerId: int.parse(s.pathParameters['id']!)),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, s) => CustomerFormScreen(
                        customerId: int.parse(s.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
            routes: [
              GoRoute(
                path: 'adjust/:id',
                builder: (_, s) => StockAdjustmentScreen(
                    productId: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/categories',
      builder: (_, __) => const CategoryScreen(),
    ),
    GoRoute(
      path: '/expenses',
      builder: (_, __) => const ExpenseListScreen(),
      routes: [
        GoRoute(
            path: 'add',
            builder: (_, __) => const ExpenseFormScreen(expense: null)),
        GoRoute(
          path: ':id/edit',
          builder: (_, s) => ExpenseFormScreen(
              expenseId: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
    ),
  ],
);

// ─── Shell ───────────────────────────────────────────────────────────────────

class _NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _NavigationShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: shellScaffoldKey,
      drawer: _AppDrawer(navigationShell: navigationShell),
      body: navigationShell,
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _AppDrawer({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = navigationShell.currentIndex;

    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.dashboardGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.store_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 14),
                const Text('SellerBook',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Text('Inventory Manager',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          // ── Nav items ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: AppStrings.navDashboard,
                  selected: idx == 0,
                  onTap: () => _go(context, 0),
                ),
                // Products (expandable)
                _ExpandableNavItem(
                  icon: Icons.inventory_2_rounded,
                  label: AppStrings.navProducts,
                  initiallyExpanded: idx == 1,
                  children: [
                    _SubNavItem(
                      icon: Icons.list_alt_rounded,
                      label: 'All Products',
                      onTap: () => _go(context, 1),
                    ),
                    _SubNavItem(
                      icon: Icons.category_rounded,
                      label: 'Categories',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/categories');
                      },
                    ),
                  ],
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: AppStrings.navOrders,
                  selected: idx == 2,
                  onTap: () => _go(context, 2),
                ),
                _NavItem(
                  icon: Icons.people_rounded,
                  label: AppStrings.navCustomers,
                  selected: idx == 3,
                  onTap: () => _go(context, 3),
                ),
                Divider(
                    indent: 16,
                    endIndent: 16,
                    color: theme.dividerColor),
                // More (expandable)
                _ExpandableNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'More',
                  initiallyExpanded: idx == 4,
                  children: [
                    _SubNavItem(
                      icon: Icons.warehouse_rounded,
                      label: AppStrings.navInventory,
                      onTap: () => _go(context, 4),
                    ),
                    _SubNavItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: AppStrings.navExpenses,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/expenses');
                      },
                    ),
                    _SubNavItem(
                      icon: Icons.settings_rounded,
                      label: AppStrings.navSettings,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/settings');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, int branch) {
    Navigator.pop(context);
    navigationShell.goBranch(branch,
        initialLocation: branch == navigationShell.currentIndex);
  }
}

// ─── Drawer item widgets ──────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

class _ExpandableNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _ExpandableNavItem({
    required this.icon,
    required this.label,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Icon(icon,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 16),
      shape: const Border(),
      collapsedShape: const Border(),
      children: children,
    );
  }
}

class _SubNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SubNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
    );
  }
}
