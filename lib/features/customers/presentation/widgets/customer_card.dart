import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/customer.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;

  const CustomerCard({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = switch (customer.tag) {
      CustomerTag.newCustomer => AppColors.tagNew,
      CustomerTag.regular => AppColors.tagRegular,
      CustomerTag.vip => AppColors.tagVip,
    };
    final s = AppStrings.of(context);
    final tagLabel = switch (customer.tag) {
      CustomerTag.newCustomer => s.tagNew,
      CustomerTag.regular => s.regular,
      CustomerTag.vip => '${s.vip} ⭐',
    };

    return GestureDetector(
      onTap: () => context.push('/customers/${customer.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tagColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tagLabel,
                          style: TextStyle(
                            color: tagColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (customer.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Stat(
                          label: '${customer.totalOrders} orders',
                          icon: tabler.Receipt.new),
                      const SizedBox(width: 12),
                      _Stat(
                          label: CurrencyFormatter.format(customer.totalSpent),
                          icon: tabler.Cash.new),
                      if (customer.outstandingBalance > 0) ...[
                        const SizedBox(width: 12),
                        _Stat(
                          label: CurrencyFormatter.format(
                              customer.outstandingBalance),
                          icon: tabler.CashOff.new,
                          color: AppColors.paymentUnpaid,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const ThinIcon(tabler.ChevronRight.new, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final ThinIconBuilder icon;
  final Color? color;

  const _Stat({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThinIcon(icon,
            size: 12,
            color: color ?? theme.colorScheme.onSurface.withOpacity(0.4)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color ?? theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
