import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/sidebar_items.dart';
import 'bottom_sheet_handle.dart';

class SectionHelp {
  const SectionHelp({
    required this.what,
    required this.when,
    this.related = const [],
  });

  final String what;
  final String when;
  final List<(String, String)> related;
}

const kSectionRoutes = {
  'dashboard': '/',
  'products': '/products',
  'orders': '/orders',
  'returns': '/returns',
  'customers': '/customers',
  'dues': '/dues',
  'inventory': '/inventory',
  'suppliers': '/suppliers',
  'expenses': '/expenses',
  'cash_register': '/cash-register',
  'categories': '/categories',
  'reports': '/reports',
  'scanner': '/scanner',
  'settings': '/settings',
};

const kSectionHelp = {
  'dashboard': SectionHelp(
    what: 'helpDashboardWhat',
    when: 'helpDashboardWhen',
    related: [
      ('orders', 'helpDashboardOrders'),
      ('dues', 'helpDashboardDues'),
      ('inventory', 'helpDashboardInventory'),
      ('reports', 'helpDashboardReports'),
    ],
  ),
  'products': SectionHelp(
    what: 'helpProductsWhat',
    when: 'helpProductsWhen',
    related: [
      ('categories', 'helpProductsCategories'),
      ('orders', 'helpProductsOrders'),
      ('inventory', 'helpProductsInventory'),
      ('suppliers', 'helpProductsSuppliers'),
    ],
  ),
  'orders': SectionHelp(
    what: 'helpOrdersWhat',
    when: 'helpOrdersWhen',
    related: [
      ('customers', 'helpOrdersCustomers'),
      ('products', 'helpOrdersProducts'),
      ('inventory', 'helpOrdersInventory'),
      ('dues', 'helpOrdersDues'),
      ('returns', 'helpOrdersReturns'),
    ],
  ),
  'returns': SectionHelp(
    what: 'helpReturnsWhat',
    when: 'helpReturnsWhen',
    related: [
      ('orders', 'helpReturnsOrders'),
      ('inventory', 'helpReturnsInventory'),
      ('dues', 'helpReturnsDues'),
    ],
  ),
  'customers': SectionHelp(
    what: 'helpCustomersWhat',
    when: 'helpCustomersWhen',
    related: [
      ('orders', 'helpCustomersOrders'),
      ('dues', 'helpCustomersDues'),
    ],
  ),
  'dues': SectionHelp(
    what: 'helpDuesWhat',
    when: 'helpDuesWhen',
    related: [
      ('orders', 'helpDuesOrders'),
      ('customers', 'helpDuesCustomers'),
      ('cash_register', 'helpDuesCashRegister'),
    ],
  ),
  'inventory': SectionHelp(
    what: 'helpInventoryWhat',
    when: 'helpInventoryWhen',
    related: [
      ('products', 'helpInventoryProducts'),
      ('orders', 'helpInventoryOrders'),
      ('suppliers', 'helpInventorySuppliers'),
    ],
  ),
  'suppliers': SectionHelp(
    what: 'helpSuppliersWhat',
    when: 'helpSuppliersWhen',
    related: [
      ('inventory', 'helpSuppliersInventory'),
      ('products', 'helpSuppliersProducts'),
      ('expenses', 'helpSuppliersExpenses'),
    ],
  ),
  'expenses': SectionHelp(
    what: 'helpExpensesWhat',
    when: 'helpExpensesWhen',
    related: [
      ('reports', 'helpExpensesReports'),
      ('dashboard', 'helpExpensesDashboard'),
    ],
  ),
  'cash_register': SectionHelp(
    what: 'helpCashRegisterWhat',
    when: 'helpCashRegisterWhen',
    related: [
      ('dues', 'helpCashRegisterDues'),
      ('expenses', 'helpCashRegisterExpenses'),
    ],
  ),
  'categories': SectionHelp(
    what: 'helpCategoriesWhat',
    when: 'helpCategoriesWhen',
    related: [
      ('products', 'helpCategoriesProducts'),
      ('reports', 'helpCategoriesReports'),
    ],
  ),
  'reports': SectionHelp(
    what: 'helpReportsWhat',
    when: 'helpReportsWhen',
    related: [
      ('orders', 'helpReportsOrders'),
      ('expenses', 'helpReportsExpenses'),
      ('dues', 'helpReportsDues'),
      ('suppliers', 'helpReportsSuppliers'),
    ],
  ),
  'scanner': SectionHelp(
    what: 'helpScannerWhat',
    when: 'helpScannerWhen',
    related: [('products', 'helpScannerProducts')],
  ),
  'settings': SectionHelp(
    what: 'helpSettingsWhat',
    when: 'helpSettingsWhen',
  ),
};

SidebarItem _item(String key) => sidebarItems.firstWhere((i) => i.key == key);

Future<void> showSectionHelp(BuildContext context, String section) {
  final help = kSectionHelp[section]!;
  return AppBottomSheet.show<void>(
    context,
    title: _item(section).label(context),
    child: _SectionHelpBody(help: help),
  );
}

class SectionHelpButton extends StatelessWidget {
  const SectionHelpButton(this.section, {super.key, this.color});

  final String section;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.of(context).helpAboutScreen,
      onPressed: () => showSectionHelp(context, section),
      icon: ThinIcon(tabler.HelpCircle.new, color: color),
    );
  }
}

class _SectionHelpBody extends StatelessWidget {
  const _SectionHelpBody({required this.help});

  final SectionHelp help;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.tr(help.what), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        Text(s.helpWhenToUse, style: heading),
        const SizedBox(height: 4),
        Text(s.tr(help.when)),
        if (help.related.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(s.helpWorksWith, style: heading),
          const SizedBox(height: 4),
          for (final (key, text) in help.related) _RelatedSection(section: key, text: s.tr(text)),
        ],
      ],
    );
  }
}

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({required this.section, required this.text});

  final String section;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _item(section);
    final color = theme.brightness == Brightness.dark
        ? Color.lerp(item.color, Colors.white, 0.25)!
        : item.color;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.go(kSectionRoutes[section]!);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThinIcon(item.icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label(context),
                      style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                  Text(text, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ThinIcon(tabler.ChevronRight.new, size: 18, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
