import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  /// Material icon — or pass [iconBuilder] for a thin Tabler icon instead.
  final ThinIconBuilder? icon;
  final ThinIconBuilder? iconBuilder;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconBuilder,
    required this.color,
    this.onTap,
  }) : assert(icon != null || iconBuilder != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: ThinIcon(iconBuilder ?? icon!, color: color, size: 18),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.5,
                fontSize: 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
