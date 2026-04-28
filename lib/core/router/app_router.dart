import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../data/services/tutorial_service.dart';
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
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/returns/presentation/returns_screen.dart';
import '../../features/suppliers/presentation/supplier_list_screen.dart';
import '../../features/suppliers/presentation/supplier_form_screen.dart';
import '../../features/suppliers/presentation/supplier_detail_screen.dart';
import '../../features/suppliers/presentation/purchase_list_screen.dart';
import '../../features/suppliers/presentation/purchase_form_screen.dart';
import '../../features/suppliers/presentation/purchase_detail_screen.dart';
import '../../features/cash_register/presentation/cash_register_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../constants/app_strings.dart';

/// Fade-through transition for pushed routes (form, detail, edit screens).
/// Branch root routes use the shell's built-in indexed-stack switch, so they
/// don't go through this helper.
CustomTransitionPage<T> _fadePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Fade combined with a subtle slide — feels like Material 3 "shared axis Y".
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _NavigationShell(navigationShell: navigationShell),
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
                pageBuilder: (_, s) =>
                    _fadePage(const ProductFormScreen(product: null), s),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _fadePage(
                    ProductDetailScreen(
                        productId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _fadePage(
                        ProductFormScreen(
                            productId: int.parse(s.pathParameters['id']!)),
                        s),
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
                path: 'add',
                pageBuilder: (_, s) => _fadePage(const OrderFormScreen(), s),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _fadePage(
                    OrderDetailScreen(
                        orderId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _fadePage(
                        OrderFormScreen(
                            orderId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/returns', builder: (_, __) => const ReturnsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/customers',
            builder: (_, __) => const CustomerListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) =>
                    _fadePage(const CustomerFormScreen(customer: null), s),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _fadePage(
                    CustomerDetailScreen(
                        customerId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _fadePage(
                        CustomerFormScreen(
                            customerId: int.parse(s.pathParameters['id']!)),
                        s),
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
                pageBuilder: (_, s) => _fadePage(
                    StockAdjustmentScreen(
                        productId: int.parse(s.pathParameters['id']!)),
                    s),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/suppliers',
            builder: (_, __) => const SupplierListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) =>
                    _fadePage(const SupplierFormScreen(), s),
              ),
              GoRoute(
                path: 'purchases',
                pageBuilder: (_, s) =>
                    _fadePage(const PurchaseListScreen(), s),
                routes: [
                  GoRoute(
                    path: 'add',
                    pageBuilder: (_, s) =>
                        _fadePage(const PurchaseFormScreen(), s),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, s) => _fadePage(
                        PurchaseDetailScreen(
                            purchaseId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _fadePage(
                    SupplierDetailScreen(
                        supplierId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _fadePage(
                        SupplierFormScreen(
                            supplierId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                  GoRoute(
                    path: 'purchase/add',
                    pageBuilder: (_, s) => _fadePage(
                        PurchaseFormScreen(
                            supplierId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpenseListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) =>
                    _fadePage(const ExpenseFormScreen(expense: null), s),
              ),
              GoRoute(
                path: ':id/edit',
                pageBuilder: (_, s) => _fadePage(
                    ExpenseFormScreen(
                        expenseId: int.parse(s.pathParameters['id']!)),
                    s),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cash-register', builder: (_, __) => const CashRegisterScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/categories', builder: (_, __) => const CategoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

// ─── Shell ────────────────────────────────────────────────────────────────────

class _NavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const _NavigationShell({required this.navigationShell});

  @override
  State<_NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<_NavigationShell> {
  // Showcase keys for sidebar items
  final GlobalKey _categoriesKey = GlobalKey();
  final GlobalKey _productsKey = GlobalKey();
  final GlobalKey _ordersKey = GlobalKey();
  final GlobalKey _returnsKey = GlobalKey();
  int _tourStepsCount = 0;

  @override
  void initState() {
    super.initState();

    ShowcaseView.register(
      onComplete: (index, key) {
        if (_tourStepsCount > 0 && index == _tourStepsCount - 1) {
          TutorialService.setTourCompleted();
        }
      },
      onDismiss: (key) {
        TutorialService.setTourCompleted();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartTour();
    });
  }

  @override
  void dispose() {
    ShowcaseView.get().unregister();
    super.dispose();
  }

  Future<void> _maybeStartTour() async {
    final done = await TutorialService.isTourCompleted();
    if (done || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final keys = <GlobalKey>[
      _categoriesKey,
      _productsKey,
      _ordersKey,
      _returnsKey,
    ];
    _tourStepsCount = keys.length;
    ShowcaseView.get().startShowCase(keys);
  }

  void _navigate(int branch) {
    widget.navigationShell.goBranch(
      branch,
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final expanded = width >= 600;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              expanded: expanded,
              currentIndex: widget.navigationShell.currentIndex,
              onNavigate: _navigate,
              showcaseKeys: {
                9: _categoriesKey,   // Categories
                1: _productsKey,     // Products
                2: _ordersKey,       // Orders
                3: _returnsKey,      // Returns
              },
            ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final bool expanded;
  final int currentIndex;
  final void Function(int) onNavigate;
  final Map<int, GlobalKey> showcaseKeys;

  const _Sidebar({
    required this.expanded,
    required this.currentIndex,
    required this.onNavigate,
    this.showcaseKeys = const {},
  });

  static const _items = <({IconData icon, IconData selectedIcon, String label})>[
    (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: AppStrings.navDashboard),
    (icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: AppStrings.navProducts),
    (icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: AppStrings.navOrders),
    (icon: Icons.assignment_return_outlined, selectedIcon: Icons.assignment_return, label: 'Returns'),
    (icon: Icons.people_outline, selectedIcon: Icons.people, label: AppStrings.navCustomers),
    (icon: Icons.warehouse_outlined, selectedIcon: Icons.warehouse, label: AppStrings.navInventory),
    (icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping, label: 'Suppliers'),
    (icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, label: AppStrings.navExpenses),
    (icon: Icons.point_of_sale_outlined, selectedIcon: Icons.point_of_sale, label: 'Cash Register'),
    (icon: Icons.category_outlined, selectedIcon: Icons.category, label: 'Categories'),
    (icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Reports'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: AppStrings.navSettings),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    return Container(
      width: expanded ? 200 : 56,
      color: bgColor,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < 7; i++)
                    _tile(i, _items[i], selectedColor, unselectedColor),
                  Divider(
                    indent: 12,
                    endIndent: 12,
                    height: 16,
                    color: unselectedColor.withValues(alpha: 0.2),
                  ),
                  for (int i = 7; i < 11; i++)
                    _tile(i, _items[i], selectedColor, unselectedColor),
                ],
              ),
            ),
          ),
          Divider(
            indent: 12,
            endIndent: 12,
            height: 1,
            color: unselectedColor.withValues(alpha: 0.15),
          ),
          _tile(11, _items[11], selectedColor, unselectedColor),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static const _showcaseDescriptions = <int, ({String title, String desc})>{
    9: (title: 'Categories', desc: 'Start here! Create product categories like Clothing, Electronics, Food, etc.'),
    1: (title: 'Products', desc: 'Add your products with prices, stock, variants (sizes/colors), and images.'),
    2: (title: 'Orders', desc: 'Create and manage customer orders. Track payment, delivery, and order status.'),
    3: (title: 'Returns', desc: 'Handle product returns and refunds with a simple 3-step flow.'),
  };

  Widget _tile(
    int index,
    ({IconData icon, IconData selectedIcon, String label}) item,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final selected = currentIndex == index;
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 22,
      color: selected ? selectedColor : unselectedColor,
    );
    final bg = selected ? selectedColor.withValues(alpha: 0.12) : Colors.transparent;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    Widget tile;

    if (expanded) {
      tile = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: bg,
          shape: shape,
          child: InkWell(
            onTap: () => onNavigate(index),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? selectedColor : unselectedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      tile = Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: item.label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 400),
          child: IconButton(
            onPressed: () => onNavigate(index),
            icon: icon,
            style: IconButton.styleFrom(
              backgroundColor: bg,
              shape: shape,
              fixedSize: const Size(44, 44),
            ),
          ),
        ),
      );
    }

    // Wrap with Showcase if this tile has a showcase key
    final key = showcaseKeys[index];
    if (key != null) {
      final info = _showcaseDescriptions[index];
      return Showcase(
        key: key,
        title: info?.title ?? item.label,
        description: info?.desc ?? '',
        child: tile,
      );
    }

    return tile;
  }
}
