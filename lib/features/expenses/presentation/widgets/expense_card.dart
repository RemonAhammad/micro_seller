import 'package:flutter/material.dart';
import '../../../../data/models/expense.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (expense.category) {
      ExpenseCategory.logistics => (const Color(0xFF42A5F5), tabler.TruckDelivery.new),
      ExpenseCategory.packaging => (const Color(0xFF66BB6A), tabler.Packages.new),
      ExpenseCategory.marketing => (const Color(0xFFAB47BC), tabler.Speakerphone.new),
      ExpenseCategory.supplies => (const Color(0xFFFF7043), tabler.ShoppingCart.new),
      ExpenseCategory.other => (const Color(0xFF78909C), tabler.Receipt.new),
    };

    final categoryLabel = switch (expense.category) {
      ExpenseCategory.logistics => 'Logistics',
      ExpenseCategory.packaging => 'Packaging',
      ExpenseCategory.marketing => 'Marketing',
      ExpenseCategory.supplies => 'Supplies',
      ExpenseCategory.other => 'Other',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03), blurRadius: 6)
          ],
        ),
        // The amount keeps its size while it fits in 40% of the card; a
        // wider one (narrow layout, large text) shrinks, so the title column
        // keeps room.
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ThinIcon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    // Category and date side by side when they fit, the
                    // date on its own line when they don't.
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(categoryLabel,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          DateFormatter.format(expense.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    if (expense.notes.isNotEmpty)
                      Text(
                        expense.notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        CurrencyFormatter.format(expense.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.red[700],
                        ),
                        maxLines: 1,
                      ),
                    ),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: ThinIcon(tabler.Trash.new,
                            size: 18,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
