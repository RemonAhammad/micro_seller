import 'package:flutter/material.dart';
import '../../../../data/models/product.dart';
import '../../../../core/constants/app_colors.dart';

class StockBadge extends StatelessWidget {
  final Product product;

  const StockBadge({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (product.isOutOfStock) {
      color = AppColors.statusCancelled;
      label = 'Out of Stock';
    } else if (product.isLowStock) {
      color = AppColors.statusPending;
      label = 'Low Stock';
    } else {
      color = AppColors.statusCompleted;
      label = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
