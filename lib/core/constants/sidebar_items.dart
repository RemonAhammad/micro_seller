import 'package:flutter/material.dart';
import 'app_strings.dart';

/// One sidebar tab. The `key` is a stable string used to persist the user's
/// preferred order — never change a key once shipped (would orphan saved
/// orders). `branchIndex` matches the original `StatefulShellRoute` branch
/// index in [appRouter] and never changes for a given key.
class SidebarItem {
  /// Stable, persisted key (e.g. "dashboard"). Don't rename after release.
  final String key;

  /// Index of the matching branch in `StatefulShellRoute.indexedStack`.
  /// Used by `_Sidebar` to translate visual position → branch index.
  final int branchIndex;

  final IconData icon;
  final IconData selectedIcon;

  const SidebarItem({
    required this.key,
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
  });

  /// Localized label. Reads from [_L10nStrings] so the sidebar follows the
  /// active locale.
  String label(BuildContext context) {
    final s = AppStrings.of(context);
    return switch (key) {
      'dashboard' => s.dashboard,
      'products' => s.products,
      'orders' => s.orders,
      'returns' => s.returns,
      'customers' => s.customers,
      'inventory' => s.inventory,
      'suppliers' => s.suppliers,
      'expenses' => s.expenses,
      'cash_register' => s.cashRegister,
      'categories' => s.categories,
      'reports' => s.reports,
      'settings' => s.settings,
      _ => key,
    };
  }
}

/// All sidebar items in their canonical order. The `branchIndex` of each
/// matches the original branch index in [appRouter] — DO NOT reorder this
/// list (the routing depends on the indices). User reordering is purely a
/// display concern, persisted as a list of `key`s.
const sidebarItems = <SidebarItem>[
  SidebarItem(
    key: 'dashboard',
    branchIndex: 0,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  SidebarItem(
    key: 'products',
    branchIndex: 1,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  SidebarItem(
    key: 'orders',
    branchIndex: 2,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  SidebarItem(
    key: 'returns',
    branchIndex: 3,
    icon: Icons.assignment_return_outlined,
    selectedIcon: Icons.assignment_return,
  ),
  SidebarItem(
    key: 'customers',
    branchIndex: 4,
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  SidebarItem(
    key: 'inventory',
    branchIndex: 5,
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
  ),
  SidebarItem(
    key: 'suppliers',
    branchIndex: 6,
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
  SidebarItem(
    key: 'expenses',
    branchIndex: 7,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  SidebarItem(
    key: 'cash_register',
    branchIndex: 8,
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  ),
  SidebarItem(
    key: 'categories',
    branchIndex: 9,
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
  ),
  SidebarItem(
    key: 'reports',
    branchIndex: 10,
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics,
  ),
  SidebarItem(
    key: 'settings',
    branchIndex: 11,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

/// The default order — just the canonical list of keys. Used as a fallback
/// when the user hasn't customized and as the target of "Reset to default".
final defaultSidebarOrder =
    List<String>.unmodifiable(sidebarItems.map((e) => e.key));

SidebarItem sidebarItemByKey(String key) =>
    sidebarItems.firstWhere((e) => e.key == key,
        orElse: () => sidebarItems.first);

/// Reconcile a stored order against the current `sidebarItems`:
/// drop unknown keys, append any missing keys at the end. Lets us evolve the
/// app (add a new tab) without invalidating users' saved order.
List<String> reconcileSidebarOrder(List<String> stored) {
  final knownKeys = sidebarItems.map((e) => e.key).toSet();
  final result = stored.where(knownKeys.contains).toList();
  for (final key in defaultSidebarOrder) {
    if (!result.contains(key)) result.add(key);
  }
  return result;
}
