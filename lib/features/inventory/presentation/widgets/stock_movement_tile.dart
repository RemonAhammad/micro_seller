import 'package:flutter/material.dart';
import '../../../../data/models/stock_movement.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';

class StockMovementTile extends StatelessWidget {
  final StockMovement movement;

  const StockMovementTile({super.key, required this.movement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = movement.qty > 0;

    final (color, icon, typeLabel) = switch (movement.type) {
      StockMovementType.sale => (AppColors.statusCancelled, tabler.Tag.new, 'Sale'),
      StockMovementType.restock => (AppColors.statusCompleted, tabler.ShoppingCartPlus.new, 'Restock'),
      StockMovementType.adjustment => (AppColors.statusConfirmed, tabler.AdjustmentsHorizontal.new, 'Adjustment'),
      StockMovementType.damage => (AppColors.statusPending, tabler.PhotoOff.new, 'Damage'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ThinIcon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.productName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$typeLabel · ${movement.reason.isNotEmpty ? movement.reason : "—"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormatter.formatWithTime(movement.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : ''}${movement.qty}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isIn ? AppColors.statusCompleted : AppColors.statusCancelled,
            ),
          ),
        ],
      ),
    );
  }
}
