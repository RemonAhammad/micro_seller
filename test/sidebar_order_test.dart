import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';

void main() {
  test('a new tab is slotted after its default predecessor, not appended', () {
    // A saved order from before the Due Book existed, user-customised.
    final stored = [
      'orders', 'dashboard', 'products', 'returns', 'customers', 'inventory',
      'suppliers', 'expenses', 'cash_register', 'categories', 'reports',
      'scanner', 'settings',
    ];
    final result = reconcileSidebarOrder(stored);
    expect(result.indexOf('dues'), result.indexOf('customers') + 1);
    expect(result.first, 'orders'); // user's customisation preserved
    expect(result.toSet(), defaultSidebarOrder.toSet());
  });

  test('unknown and duplicate keys are dropped', () {
    final result = reconcileSidebarOrder(['gone', 'dashboard', 'dashboard']);
    expect(result.where((k) => k == 'dashboard').length, 1);
    expect(result, isNot(contains('gone')));
    expect(result.length, defaultSidebarOrder.length);
  });

  test('every branch index is unique', () {
    final idx = sidebarItems.map((e) => e.branchIndex).toList();
    expect(idx.toSet().length, idx.length);
  });
}
