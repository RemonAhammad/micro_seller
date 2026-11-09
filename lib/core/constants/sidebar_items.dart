import 'package:flutter/material.dart';
import 'app_icons.dart';
import 'app_strings.dart';

class SidebarItem {
  final String key;

  final int branchIndex;

  final ThinIconBuilder icon;

  final Color color;

  const SidebarItem({required this.key, required this.branchIndex, required this.icon, required this.color});

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
      'goals' => s.tr('salesTargets'),
      'expiry' => s.tr('nearExpiryProducts'),
      'scanner' => s.scanner,

      'settings' => s.settings,
      _ => key,
    };
  }
}

const sidebarItems = <SidebarItem>[
  SidebarItem(key: 'dashboard', branchIndex: 0, icon: AppIcons.dashboard, color: Color(0xFF00897B)),
  SidebarItem(key: 'products', branchIndex: 1, icon: AppIcons.products, color: Color(0xFF3F51B5)),
  SidebarItem(key: 'orders', branchIndex: 2, icon: AppIcons.orders, color: Color(0xFF1E88E5)),
  SidebarItem(key: 'returns', branchIndex: 3, icon: AppIcons.returns, color: Color(0xFFF4511E)),
  SidebarItem(key: 'customers', branchIndex: 4, icon: AppIcons.customers, color: Color(0xFF8E24AA)),
  SidebarItem(key: 'dues', branchIndex: 13, icon: AppIcons.dueBook, color: Color(0xFFFB8C00)),
  SidebarItem(key: 'inventory', branchIndex: 5, icon: AppIcons.inventory, color: Color(0xFF6D4C41)),
  SidebarItem(key: 'suppliers', branchIndex: 6, icon: AppIcons.suppliers, color: Color(0xFF00ACC1)),
  SidebarItem(key: 'expenses', branchIndex: 7, icon: AppIcons.expenses, color: Color(0xFFE53935)),
  SidebarItem(key: 'cash_register', branchIndex: 8, icon: AppIcons.cashRegister, color: Color(0xFF43A047)),
  SidebarItem(key: 'categories', branchIndex: 9, icon: AppIcons.categories, color: Color(0xFFD81B60)),
  SidebarItem(key: 'reports', branchIndex: 10, icon: AppIcons.reports, color: Color(0xFF5E35B1)),
  SidebarItem(key: 'goals', branchIndex: 14, icon: AppIcons.goals, color: Color(0xFFEF6C00)),
  SidebarItem(key: 'expiry', branchIndex: 15, icon: AppIcons.expiry, color: Color(0xFFE65100)),
  SidebarItem(key: 'scanner', branchIndex: 12, icon: AppIcons.scanner, color: Color(0xFF546E7A)),
  SidebarItem(key: 'settings', branchIndex: 11, icon: AppIcons.settings, color: Color(0xFF757575)),
];

final defaultSidebarOrder = List<String>.unmodifiable(sidebarItems.map((e) => e.key));

SidebarItem sidebarItemByKey(String key) =>
    sidebarItems.firstWhere((e) => e.key == key, orElse: () => sidebarItems.first);

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
