import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  /// Lucide icon at the default stroke, shown when the tab isn't selected.
  final IconData icon;

  /// The same Lucide glyph at the bold 600 stroke, shown when selected.
  /// (Both are `const` so `--tree-shake-icons` keeps working.)
  final IconData selectedIcon;

  /// The tab's own accent color — tints its icon, and its label and
  /// background when selected. Each tab has a distinct hue so the rail is
  /// scannable at a glance.
  final Color color;

  const SidebarItem({
    required this.key,
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.color,
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
      'dues' => s.dueBook,
      'inventory' => s.inventory,
      'suppliers' => s.suppliers,
      'expenses' => s.expenses,
      'cash_register' => s.cashRegister,
      'categories' => s.categories,
      'reports' => s.reports,
      'scanner' => s.scanner,
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
    icon: LucideIcons.layoutDashboard,
    selectedIcon: LucideIcons.layoutDashboard600,
    color: Color(0xFF00897B), // Brand teal
  ),
  SidebarItem(
    key: 'products',
    branchIndex: 1,
    icon: LucideIcons.package,
    selectedIcon: LucideIcons.package600,
    color: Color(0xFF3F51B5), // Indigo
  ),
  SidebarItem(
    key: 'orders',
    branchIndex: 2,
    icon: LucideIcons.receipt,
    selectedIcon: LucideIcons.receipt600,
    color: Color(0xFF1E88E5), // Blue
  ),
  SidebarItem(
    key: 'returns',
    branchIndex: 3,
    icon: LucideIcons.undo2,
    selectedIcon: LucideIcons.undo2600,
    color: Color(0xFFF4511E), // Deep orange
  ),
  SidebarItem(
    key: 'customers',
    branchIndex: 4,
    icon: LucideIcons.usersRound,
    selectedIcon: LucideIcons.usersRound600,
    color: Color(0xFF8E24AA), // Purple
  ),
  SidebarItem(
    key: 'dues',
    branchIndex: 13,
    icon: LucideIcons.notebookPen,
    selectedIcon: LucideIcons.notebookPen600,
    color: Color(0xFFFB8C00), // Amber-orange — money owed
  ),
  SidebarItem(
    key: 'inventory',
    branchIndex: 5,
    icon: LucideIcons.warehouse,
    selectedIcon: LucideIcons.warehouse600,
    color: Color(0xFF6D4C41), // Brown
  ),
  SidebarItem(
    key: 'suppliers',
    branchIndex: 6,
    icon: LucideIcons.truck,
    selectedIcon: LucideIcons.truck600,
    color: Color(0xFF00ACC1), // Cyan
  ),
  SidebarItem(
    key: 'expenses',
    branchIndex: 7,
    icon: LucideIcons.wallet,
    selectedIcon: LucideIcons.wallet600,
    color: Color(0xFFE53935), // Red — money out
  ),
  SidebarItem(
    key: 'cash_register',
    branchIndex: 8,
    icon: LucideIcons.banknote,
    selectedIcon: LucideIcons.banknote600,
    color: Color(0xFF43A047), // Green — money in
  ),
  SidebarItem(
    key: 'categories',
    branchIndex: 9,
    icon: LucideIcons.tag,
    selectedIcon: LucideIcons.tag600,
    color: Color(0xFFD81B60), // Pink
  ),
  SidebarItem(
    key: 'reports',
    branchIndex: 10,
    icon: LucideIcons.chartLine,
    selectedIcon: LucideIcons.chartLine600,
    color: Color(0xFF5E35B1), // Deep purple
  ),
  SidebarItem(
    key: 'scanner',
    branchIndex: 12,
    icon: LucideIcons.scanBarcode,
    selectedIcon: LucideIcons.scanBarcode600,
    color: Color(0xFF546E7A), // Blue-grey
  ),
  SidebarItem(
    key: 'settings',
    branchIndex: 11,
    icon: LucideIcons.settings,
    selectedIcon: LucideIcons.settings600,
    color: Color(0xFF757575), // Grey
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
/// drop unknown keys, and slot each missing key in right after its
/// predecessor in [defaultSidebarOrder] (so a new tab like "dues" lands next
/// to "customers" for existing users, not below Settings). Lets us evolve
/// the app without invalidating users' saved order.
List<String> reconcileSidebarOrder(List<String> stored) {
  final knownKeys = sidebarItems.map((e) => e.key).toSet();
  final result = stored.where(knownKeys.contains).toSet().toList();
  for (var i = 0; i < defaultSidebarOrder.length; i++) {
    final key = defaultSidebarOrder[i];
    if (result.contains(key)) continue;
    final prev = i == 0 ? null : defaultSidebarOrder[i - 1];
    final at = prev == null ? 0 : result.indexOf(prev) + 1;
    result.insert(at.clamp(0, result.length), key);
  }
  return result;
}
