import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/promotion.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/promotion_provider.dart';

class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final promosAsync = ref.watch(promotionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('sellPromotion'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/promotions/add'),
        tooltip: s.tr('createPromotion'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const ThinIcon(tabler.Plus.new, size: 24),
      ),
      body: promosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (promos) {
          if (promos.isEmpty) {
            return Center(
              child: EmptyState(
                icon: AppIcons.promotions,
                title: s.tr('noPromotions'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: promos.length,
            itemBuilder: (context, i) => _PromotionCard(
              promo: promos[i],
              onEdit: () => context.push('/promotions/${promos[i].id}/edit'),
              onDelete: () => _confirmDelete(context, ref, promos[i]),
              onShare: () => _sharePromo(context, promos[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Promotion promo,
  ) async {
    final s = AppStrings.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: s.delete,
      message: '${s.tr("deleteConfirm")} "${promo.title}"?',
      isDestructive: true,
    );
    if (confirmed == true) {
      await ref.read(promotionProvider.notifier).delete(promo.id);
    }
  }

  Future<void> _sharePromo(
    BuildContext context,
    Promotion promo,
  ) async {
    final s = AppStrings.of(context);
    final text = _buildShareText(promo, s);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  String _buildShareText(Promotion promo, dynamic s) {
    final buf = StringBuffer();
    if (promo.title.isNotEmpty) {
      buf.writeln('🎉 ${promo.title}');
      buf.writeln();
    }
    if (promo.discountPercent > 0) {
      buf.writeln('🔥 ${promo.discountPercent.toStringAsFixed(0)}% OFF');
    } else if (promo.discountAmount > 0) {
      buf.writeln(
          '🔥 ${CurrencyFormatter.format(promo.discountAmount)} OFF');
    }
    if (promo.couponCode.isNotEmpty) {
      buf.writeln('🎫 ${s.tr("couponCode")}: ${promo.couponCode}');
    }
    if (promo.productNames.isNotEmpty) {
      buf.writeln();
      for (final name in promo.productNames) {
        buf.writeln('• $name');
      }
    }
    if (promo.message.isNotEmpty) {
      buf.writeln();
      buf.writeln(promo.message);
    }
    if (promo.startDate != null || promo.endDate != null) {
      buf.writeln();
      final fmt = DateFormat.yMMMd();
      if (promo.startDate != null && promo.endDate != null) {
        buf.writeln(
            '📅 ${fmt.format(promo.startDate!)} - ${fmt.format(promo.endDate!)}');
      } else if (promo.endDate != null) {
        buf.writeln('📅 ${s.tr("validUntil")} ${fmt.format(promo.endDate!)}');
      }
    }
    return buf.toString().trimRight();
  }
}

class _PromotionCard extends StatelessWidget {
  final Promotion promo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _PromotionCard({
    required this.promo,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = AppStrings.of(context);
    final isExp = promo.isExpired;
    final fmt = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    promo.title.isNotEmpty ? promo.title : s.tr('sellPromotion'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _TypeBadge(type: promo.type),
              ],
            ),
            const SizedBox(height: 8),
            if (promo.discountPercent > 0 || promo.discountAmount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  promo.discountPercent > 0
                      ? '${promo.discountPercent.toStringAsFixed(0)}% OFF'
                      : '${CurrencyFormatter.format(promo.discountAmount)} OFF',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            if (promo.couponCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: cs.primary, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        promo.couponCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: promo.couponCode));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(s.tr('copiedToClipboard')),
                          duration: const Duration(seconds: 1),
                        ));
                      },
                      child: ThinIcon(tabler.Copy.new,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            if (promo.productNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  promo.isStoreWide
                      ? s.tr('storeWide')
                      : promo.productNames.join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (promo.startDate != null || promo.endDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    ThinIcon(tabler.Calendar.new,
                        size: 14, color: cs.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      [
                        if (promo.startDate != null)
                          fmt.format(promo.startDate!),
                        if (promo.endDate != null) fmt.format(promo.endDate!),
                      ].join(' - '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isExp
                                ? AppColors.statusCancelled
                                : AppColors.statusCompleted)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isExp
                            ? s.tr('promotionExpired')
                            : s.tr('promotionActive'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isExp
                              ? AppColors.statusCancelled
                              : AppColors.statusCompleted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            Row(
              children: [
                _ActionBtn(
                  icon: tabler.BrandWhatsapp.new,
                  label: s.tr('share'),
                  onTap: onShare,
                ),
                const SizedBox(width: 12),
                _ActionBtn(
                  icon: tabler.Edit.new,
                  label: s.edit,
                  onTap: onEdit,
                ),
                const Spacer(),
                _ActionBtn(
                  icon: tabler.Trash.new,
                  label: s.delete,
                  onTap: onDelete,
                  color: AppColors.statusCancelled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final label = switch (type) {
      'coupon' => s.tr('coupon'),
      'banner' => s.tr('banner'),
      _ => s.tr('discount'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final ThinIconBuilder icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThinIcon(icon, size: 16, color: c),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: c)),
          ],
        ),
      ),
    );
  }
}
