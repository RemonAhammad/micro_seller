import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import 'shell_back_swipe.dart';
import '../../data/services/tutorial_service.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/settings/presentation/sidebar_order_screen.dart';
import '../../features/settings/presentation/recycle_bin_screen.dart';
import '../../features/settings/presentation/color_theme_screen.dart';
import '../constants/app_icons.dart';
import '../constants/sidebar_items.dart';
import '../../shared/widgets/app_zoom.dart';
import '../../features/categories/presentation/category_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/products/presentation/catalog_share_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/orders/presentation/order_list_screen.dart';
import '../../features/orders/presentation/order_form_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/customers/presentation/due_book_screen.dart';
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
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

const double kSidebarRailWidth = 56;
const double kSidebarExpandedWidth = 200;

const double kSidebarExpandMinWidth = 600;

bool get _iosPages => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

Page<T> _subPage<T>(Widget child, GoRouterState state) => _iosPages
    ? MaterialPage<T>(
        key: state.pageKey, name: state.name ?? state.path, child: child)
    : _fadePage<T>(child, state);

CustomTransitionPage<T> _fadePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {

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

StatefulShellBranch _branch(List<RouteBase> routes) =>
    StatefulShellBranch(routes: routes, observers: [BranchTopRouteObserver()]);

final appRouter = GoRouter(
  initialLocation: TutorialService.splashShown ? '/' : '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _NavigationShell(navigationShell: navigationShell),
      branches: [
        _branch([
          GoRoute(
            path: '/',
            builder: (_, __) => const DashboardScreen(),
            routes: [
              GoRoute(
                path: 'goals',
                pageBuilder: (context, state) =>
                    _subPage(const GoalsScreen(), state),
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductListScreen(),
            routes: [
              GoRoute(
                path: 'catalog',
                pageBuilder: (_, s) =>
                    _subPage(const CatalogShareScreen(), s),
              ),
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) {

                  final extra = s.extra;
                  final prefill = extra is ScannerPrefill ? extra : null;
                  return _subPage(
                    ProductFormScreen(
                      product: null,
                      initialQrCode: prefill?.qrCode,
                      initialSku: prefill?.sku,
                    ),
                    s,
                  );
                },
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _subPage(
                    ProductDetailScreen(
                        productId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _subPage(
                        ProductFormScreen(
                            productId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrderListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) => _subPage(const OrderFormScreen(), s),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _subPage(
                    OrderDetailScreen(
                        orderId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _subPage(
                        OrderFormScreen(
                            orderId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(path: '/returns', builder: (_, __) => const ReturnsScreen()),
        ]),
        _branch([
          GoRoute(
            path: '/customers',
            builder: (_, __) => const CustomerListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) =>
                    _subPage(const CustomerFormScreen(customer: null), s),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _subPage(
                    CustomerDetailScreen(
                        customerId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _subPage(
                        CustomerFormScreen(
                            customerId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
            routes: [
              GoRoute(
                path: 'adjust/:id',
                pageBuilder: (_, s) => _subPage(
                    StockAdjustmentScreen(
                        productId: int.parse(s.pathParameters['id']!)),
                    s),
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(
            path: '/suppliers',
            builder: (_, __) => const SupplierListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) =>
                    _subPage(const SupplierFormScreen(), s),
              ),
              GoRoute(
                path: 'purchases',
                pageBuilder: (_, s) =>
                    _subPage(const PurchaseListScreen(), s),
                routes: [
                  GoRoute(
                    path: 'add',
                    pageBuilder: (_, s) =>
                        _subPage(const PurchaseFormScreen(), s),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, s) => _subPage(
                        PurchaseDetailScreen(
                            purchaseId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _subPage(
                    SupplierDetailScreen(
                        supplierId: int.parse(s.pathParameters['id']!)),
                    s),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (_, s) => _subPage(
                        SupplierFormScreen(
                            supplierId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                  GoRoute(
                    path: 'purchase/add',
                    pageBuilder: (_, s) => _subPage(
                        PurchaseFormScreen(
                            supplierId: int.parse(s.pathParameters['id']!)),
                        s),
                  ),
                ],
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpenseListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, s) =>
                    _subPage(const ExpenseFormScreen(expense: null), s),
              ),
              GoRoute(
                path: ':id/edit',
                pageBuilder: (_, s) => _subPage(
                    ExpenseFormScreen(
                        expenseId: int.parse(s.pathParameters['id']!)),
                    s),
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(path: '/cash-register', builder: (_, __) => const CashRegisterScreen()),
        ]),
        _branch([
          GoRoute(path: '/categories', builder: (_, __) => const CategoryScreen()),
        ]),
        _branch([
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        ]),
        _branch([
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'sidebar-order',
                pageBuilder: (_, s) =>
                    _subPage(const SidebarOrderScreen(), s),
              ),
              GoRoute(
                path: 'recycle-bin',
                pageBuilder: (_, s) =>
                    _subPage(const RecycleBinScreen(), s),
              ),
              GoRoute(
                path: 'color-theme',
                pageBuilder: (_, s) =>
                    _subPage(const ColorThemeScreen(), s),
              ),
            ],
          ),
        ]),
        _branch([
          GoRoute(path: '/scanner', builder: (_, __) => const ScannerScreen()),
        ]),

        _branch([
          GoRoute(
            path: '/dues',

            builder: (_, state) => DueBookScreen(
              key: ValueKey(state.uri.toString()),
              initialOver60: state.uri.queryParameters['age'] == '60',
            ),
          ),
        ]),
      ],
    ),
  ],
);

class _NavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const _NavigationShell({required this.navigationShell});

  @override
  ConsumerState<_NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<_NavigationShell> {

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

    final zoom = context.getInheritedWidgetOfExactType<AppZoomScope>()?.scale;
    if ((zoom ?? 1.0) != 1.0) {

      await TutorialService.setTourCompleted();
      return;
    }

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
    final expanded = width >= kSidebarExpandMinWidth;

    final position = ref.watch(settingsProvider.select((s) =>
        s['sidebarPosition'] as String? ?? Settings.sidebarPositionLeft));
    final isRight = position == Settings.sidebarPositionRight;
    final isBottom = position == Settings.sidebarPositionBottom;

    final showcaseKeys = <int, GlobalKey>{
      9: _categoriesKey,
      1: _productsKey,
      2: _ordersKey,
      3: _returnsKey,
    };

    if (isBottom) {
      return Scaffold(
        body: ShellEdgeBackSwipe(
          enabled: _iosPages,
          shell: widget.navigationShell,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(child: widget.navigationShell),
                _BottomNavBar(
                  currentIndex: widget.navigationShell.currentIndex,
                  onNavigate: _navigate,
                  showcaseKeys: showcaseKeys,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sidebar = _Sidebar(
      expanded: expanded,
      currentIndex: widget.navigationShell.currentIndex,
      onNavigate: _navigate,
      showcaseKeys: showcaseKeys,
    );
    final content = Expanded(child: widget.navigationShell);

    return Scaffold(

      body: ShellEdgeBackSwipe(
        enabled: _iosPages && !isRight,
        shell: widget.navigationShell,
        child: SafeArea(
          child: Row(
            children:
                isRight ? [content, sidebar] : [sidebar, content],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final bool expanded;

  final int currentIndex;

  final void Function(int branchIndex) onNavigate;

  final Map<int, GlobalKey> showcaseKeys;

  const _Sidebar({
    required this.expanded,
    required this.currentIndex,
    required this.onNavigate,
    this.showcaseKeys = const {},
  });

  static const _showcaseDescriptions = <int, ({String title, String desc})>{
    9: (title: 'Categories', desc: 'Start here! Create product categories like Clothing, Electronics, Food, etc.'),
    1: (title: 'Products', desc: 'Add your products with prices, stock, variants (sizes/colors), and images.'),
    2: (title: 'Orders', desc: 'Create and manage customer orders. Track payment, delivery, and order status.'),
    3: (title: 'Returns', desc: 'Handle product returns and refunds with a simple 3-step flow.'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    ref.watch(settingsProvider.select((s) => (
          (s['sidebarOrder'] as List?)?.join(','),
          (s['hiddenSidebarItems'] as List?)?.join(','),
        )));
    final notifier = ref.read(settingsProvider.notifier);
    final order = notifier.sidebarOrder;

    final hidden = notifier.hiddenSidebarItems.toSet();
    final visibleOrder = order.where((k) => !hidden.contains(k)).toList();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    return Container(
      width: expanded ? kSidebarExpandedWidth : kSidebarRailWidth,
      color: bgColor,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final key in visibleOrder)
                    _tile(
                      context,
                      sidebarItemByKey(key),
                      selectedColor,
                      unselectedColor,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    SidebarItem item,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final selected = currentIndex == item.branchIndex;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint =
        isDark ? Color.lerp(item.color, Colors.white, 0.25)! : item.color;
    final icon = ThinIcon(
      item.icon,
      size: 22,
      color: selected ? tint : tint.withValues(alpha: 0.75),
      strokeWidth: selected ? kIconStrokeSelected : kIconStroke,
    );
    final bg = selected ? tint.withValues(alpha: 0.14) : Colors.transparent;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final label = item.label(context);

    Widget tile;

    if (expanded) {
      tile = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: bg,
          shape: shape,
          child: InkWell(
            onTap: () => onNavigate(item.branchIndex),
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
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? tint : unselectedColor,
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
          message: label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 400),
          child: IconButton(
            onPressed: () => onNavigate(item.branchIndex),
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

    final key = showcaseKeys[item.branchIndex];
    if (key != null) {
      final info = _showcaseDescriptions[item.branchIndex];
      return Showcase(
        key: key,
        title: info?.title ?? label,
        description: info?.desc ?? '',
        child: tile,
      );
    }

    return tile;
  }
}

class _BottomNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final void Function(int branchIndex) onNavigate;
  final Map<int, GlobalKey> showcaseKeys;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onNavigate,
    this.showcaseKeys = const {},
  });

  @override
  ConsumerState<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends ConsumerState<_BottomNavBar> {
  final _scrollCtrl = ScrollController();
  final _tileKeys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(_BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (!_scrollCtrl.hasClients) return;
    final notifier = ref.read(settingsProvider.notifier);
    final order = notifier.sidebarOrder;
    final hidden = notifier.hiddenSidebarItems.toSet();
    final visibleOrder = order.where((k) => !hidden.contains(k)).toList();

    final selectedKey = visibleOrder.cast<String?>().firstWhere(
      (k) => k != null && sidebarItemByKey(k).branchIndex == widget.currentIndex,
      orElse: () => null,
    );
    if (selectedKey == null) return;

    final tileKey = _tileKeys[selectedKey];
    if (tileKey == null) return;
    final ctx = tileKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // Find the scroll viewport's RenderBox via the scroll controller
    final scrollRenderObj = _scrollCtrl.position.context.notificationContext
        ?.findRenderObject() as RenderBox?;
    if (scrollRenderObj == null) return;

    final tileOffset = box.localToGlobal(Offset.zero, ancestor: scrollRenderObj);
    final tileWidth = box.size.width;
    final viewportWidth = _scrollCtrl.position.viewportDimension;
    final currentOffset = _scrollCtrl.offset;

    final targetOffset = currentOffset + tileOffset.dx - (viewportWidth - tileWidth) / 2;
    final clampedOffset = targetOffset.clamp(
      _scrollCtrl.position.minScrollExtent,
      _scrollCtrl.position.maxScrollExtent,
    );

    _scrollCtrl.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider.select((s) => (
          (s['sidebarOrder'] as List?)?.join(','),
          (s['hiddenSidebarItems'] as List?)?.join(','),
        )));
    final notifier = ref.read(settingsProvider.notifier);
    final order = notifier.sidebarOrder;
    final hidden = notifier.hiddenSidebarItems.toSet();
    final visibleOrder = order.where((k) => !hidden.contains(k)).toList();

    // Ensure a GlobalKey exists for each visible tile
    for (final key in visibleOrder) {
      _tileKeys.putIfAbsent(key, () => GlobalKey());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: colorScheme.outlineVariant),
            SizedBox(
              height: 56,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final key in visibleOrder)
                      KeyedSubtree(
                        key: _tileKeys[key],
                        child: _BottomNavTile(
                          item: sidebarItemByKey(key),
                          selected: widget.currentIndex == sidebarItemByKey(key).branchIndex,
                          isDark: isDark,
                          onTap: () => widget.onNavigate(sidebarItemByKey(key).branchIndex),
                          showcaseKey: widget.showcaseKeys[sidebarItemByKey(key).branchIndex],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavTile extends StatelessWidget {
  final SidebarItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final GlobalKey? showcaseKey;

  const _BottomNavTile({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.showcaseKey,
  });

  static const _showcaseDescriptions = _Sidebar._showcaseDescriptions;

  @override
  Widget build(BuildContext context) {
    final tint =
        isDark ? Color.lerp(item.color, Colors.white, 0.25)! : item.color;
    final bg = selected ? tint.withValues(alpha: 0.14) : Colors.transparent;
    final label = item.label(context);

    final icon = ThinIcon(
      item.icon,
      size: 20,
      color: selected ? tint : tint.withValues(alpha: 0.75),
      strokeWidth: selected ? kIconStrokeSelected : kIconStroke,
    );

    final tile = Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: bg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? tint : tint.withValues(alpha: 0.75),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );

    if (showcaseKey != null) {
      final info = _showcaseDescriptions[item.branchIndex];
      return Showcase(
        key: showcaseKey!,
        title: info?.title ?? label,
        description: info?.desc ?? '',
        child: tile,
      );
    }
    return tile;
  }
}
