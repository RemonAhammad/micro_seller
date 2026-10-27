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

/// The sidebar's width: the icon rail on a phone, and with labels in a
/// window at least [kSidebarExpandMinWidth] wide (a tablet, or its wider
/// Split View windows).
const double kSidebarRailWidth = 56;
const double kSidebarExpandedWidth = 200;

/// The narrowest window that gets the sidebar with labels.
const double kSidebarExpandMinWidth = 600;

/// Whether pushed screens are iOS pages: its slide, and its back swipe. Not
/// on the web, where Safari's own edge swipe goes back in the browser.
bool get _iosPages => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// A pushed screen's page (form, detail, edit screens). On iOS a
/// [MaterialPage], which the theme slides in as iOS does, with the back
/// swipe from the page's leading edge; the shell's [ShellEdgeBackSwipe] adds
/// the screen's edge, over the sidebar. Elsewhere the fade ([_fadePage]).
Page<T> _subPage<T>(Widget child, GoRouterState state) => _iosPages
    ? MaterialPage<T>(
        key: state.pageKey, name: state.name ?? state.path, child: child)
    : _fadePage<T>(child, state);

/// Fade-through transition for pushed routes on Android and the web.
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

/// A sidebar tab's branch. Its observer tells the shell's
/// [ShellEdgeBackSwipe] which page is on top.
StatefulShellBranch _branch(List<RouteBase> routes) =>
    StatefulShellBranch(routes: routes, observers: [BranchTopRouteObserver()]);

// First read is MaterialApp.router's build, after main() primed the flag.
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
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
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
                  // From scanner: prefill the qr/sku of the new product.
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
        // Branch 13 — appended, never inserted: branch indices are persisted
        // by `SidebarItem.branchIndex` and must stay stable.
        _branch([
          GoRoute(
            path: '/dues',
            // `?age=60` (from the dashboard's overdue banner) opens the list
            // pre-filtered. Keyed on the URI so a later banner tap re-applies
            // the filter even though the branch keeps its state.
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

// ─── Shell ────────────────────────────────────────────────────────────────────

class _NavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const _NavigationShell({required this.navigationShell});

  @override
  ConsumerState<_NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<_NavigationShell> {
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
    // showcaseview's tooltip uses an unanchored localToGlobal: off when zoomed.
    final zoom = context.getInheritedWidgetOfExactType<AppZoomScope>()?.scale;
    if ((zoom ?? 1.0) != 1.0) {
      // Not a first run (it was resized), and the rating prompt waits for this.
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

    // Watch only the position so the Row swaps live when it changes, without
    // rebuilding the shell on every other settings write.
    final position = ref.watch(settingsProvider.select((s) =>
        s['sidebarPosition'] as String? ?? Settings.sidebarPositionLeft));
    final isRight = position == Settings.sidebarPositionRight;

    final sidebar = _Sidebar(
      expanded: expanded,
      currentIndex: widget.navigationShell.currentIndex,
      onNavigate: _navigate,
      showcaseKeys: {
        9: _categoriesKey,   // Categories
        1: _productsKey,     // Products
        2: _ordersKey,       // Orders
        3: _returnsKey,      // Returns
      },
    );
    final content = Expanded(child: widget.navigationShell);

    return Scaffold(
      // On iOS a pushed screen is swiped back from its leading edge, which
      // starts beside the sidebar when the sidebar is on that side (the
      // Row's first child, so on the right in Arabic and Urdu): the strip
      // over the sidebar starts it from the screen's edge too. With the
      // sidebar on the other side, the page's edge is the screen's.
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

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final bool expanded;

  /// The active branch index in `StatefulShellRoute.indexedStack`.
  final int currentIndex;

  /// Called with the branch index of the tapped item — NOT the visual index.
  /// The shell handles routing to that branch.
  final void Function(int branchIndex) onNavigate;

  /// Showcase keys keyed by branch index (matches the original branch
  /// numbering — survives user reordering since the underlying branch index
  /// of each item never changes).
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
    // Rebuild only when the order or the hidden set changes. Compared by
    // content, since an import writes fresh lists even when nothing changed.
    ref.watch(settingsProvider.select((s) => (
          (s['sidebarOrder'] as List?)?.join(','),
          (s['hiddenSidebarItems'] as List?)?.join(','),
        )));
    final notifier = ref.read(settingsProvider.notifier);
    final order = notifier.sidebarOrder;
    // Items the user has toggled off in Settings → Sidebar Order. Settings
    // tab is force-included regardless (the provider already strips it).
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
    // Each tab keeps its own hue. In dark mode, lift it toward white so the
    // darker ones (brown, blue-grey, grey, deep purple) stay readable.
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

    // Showcase keys are keyed by the original branch index, not visual order.
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
