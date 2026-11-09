import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/promotion.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../settings/providers/settings_provider.dart';
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
              onShare: () => _sharePromo(context, ref, promos[i]),
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

  void _sharePromo(BuildContext context, WidgetRef ref, Promotion promo) {
    final settings = ref.read(settingsProvider);
    final shopName = settings['shopName'] as String? ?? 'My Shop';
    final shopPhone = settings['shopPhone'] as String? ?? '';
    final text = _buildShareText(promo, shopName, shopPhone);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SharePreviewSheet(initialText: text),
    );
  }

  static String _buildShareText(
    Promotion promo,
    String shopName,
    String shopPhone,
  ) {
    final buf = StringBuffer();
    final fmt = DateFormat.yMMMd();

    String dateLine() {
      if (promo.startDate == null && promo.endDate == null) return '';
      if (promo.startDate != null && promo.endDate != null) {
        if (promo.startDate!.year == promo.endDate!.year &&
            promo.startDate!.month == promo.endDate!.month &&
            promo.startDate!.day == promo.endDate!.day) {
          return '📅 One day only: ${fmt.format(promo.startDate!)}!';
        }
        return '📅 Offer valid: ${fmt.format(promo.startDate!)} – ${fmt.format(promo.endDate!)}';
      }
      if (promo.startDate != null) {
        return '📅 Starting from ${fmt.format(promo.startDate!)}';
      }
      return '📅 Valid until ${fmt.format(promo.endDate!)}';
    }

    String productSection(String heading) {
      if (promo.productIds.isEmpty) return '';
      final sb = StringBuffer('\n$heading\n');
      for (final name in promo.productNames) {
        sb.writeln('• $name');
      }
      return sb.toString().trimRight();
    }

    switch (promo.type) {
      case 'coupon':
        final discountText = promo.discountPercent > 0
            ? '${promo.discountPercent.toStringAsFixed(0)}% OFF'
            : promo.discountAmount > 0
                ? '${CurrencyFormatter.format(promo.discountAmount)} OFF'
                : 'SPECIAL DISCOUNT';
        buf.writeln('🎁 *EXCLUSIVE COUPON — $discountText!* 🎁');
        buf.writeln();
        buf.writeln('Use code 👉 *${promo.couponCode}* 👈 at $shopName!');
        final products = productSection('🛍️ *Applicable on:*');
        if (products.isNotEmpty) {
          buf.writeln(products);
        } else {
          buf.writeln('\n🛍️ *Applicable on all products!*');
        }
        final date = dateLine();
        if (date.isNotEmpty) buf.writeln('\n$date');
        if (promo.message.isNotEmpty) buf.writeln('\n${promo.message}');
        buf.writeln('\n💡 *Show this message to redeem!*');

      case 'banner':
        buf.writeln('📣 *${promo.title.isNotEmpty ? promo.title : "Special Offer"}* 📣');
        buf.writeln();
        buf.writeln('$shopName brings you something special!');
        if (promo.discountPercent > 0 || promo.discountAmount > 0) {
          buf.writeln();
          buf.writeln('🔥 *${promo.discountLabel}*');
        }
        final products = productSection('🛍️ *Featured products:*');
        if (products.isNotEmpty) {
          buf.writeln(products);
        } else {
          buf.writeln('\n🛍️ *Store-wide offer!*');
        }
        final date = dateLine();
        if (date.isNotEmpty) buf.writeln('\n$date');
        if (promo.message.isNotEmpty) buf.writeln('\n${promo.message}');
        buf.writeln('\n👉 *Visit us today!*');

      default: // discount
        final discountText = promo.discountPercent > 0
            ? '${promo.discountPercent.toStringAsFixed(0)}% OFF'
            : promo.discountAmount > 0
                ? '${CurrencyFormatter.format(promo.discountAmount)} OFF'
                : '';
        buf.writeln('🔥 *MEGA SALE — $discountText!* 🔥');
        buf.writeln();
        buf.writeln('$shopName is offering an exclusive deal you don\'t want to miss!');
        final products = productSection('🛍️ *What\'s on sale:*');
        if (products.isNotEmpty) {
          buf.writeln(products);
        } else {
          buf.writeln('\n🛍️ *Everything in store!*');
        }
        if (promo.discountPercent > 0) {
          buf.writeln('\n💰 Save ${promo.discountPercent.toStringAsFixed(0)}% on your purchase!');
        } else if (promo.discountAmount > 0) {
          buf.writeln('\n💰 Save ${CurrencyFormatter.format(promo.discountAmount)} on your purchase!');
        }
        final date = dateLine();
        if (date.isNotEmpty) buf.writeln('\n$date');
        if (promo.message.isNotEmpty) buf.writeln('\n${promo.message}');
        buf.writeln('\n⏰ *Hurry! Limited time offer!*');
    }

    if (shopPhone.isNotEmpty) buf.writeln('\n📞 $shopPhone');

    return buf.toString().trimRight();
  }
}

class _SharePreviewSheet extends StatefulWidget {
  final String initialText;
  const _SharePreviewSheet({required this.initialText});

  @override
  State<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<_SharePreviewSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _shareWhatsApp() async {
    final text = _ctrl.text;
    final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareGeneric() async {
    await SharePlus.instance.share(ShareParams(text: _ctrl.text));
    if (mounted) Navigator.pop(context);
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _ctrl.text));
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.tr('promoTextCopied')),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.tr('sharePromotion'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _shareWhatsApp,
                  icon: const ThinIcon(tabler.BrandWhatsapp.new, size: 18),
                  label: const Text('WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareGeneric,
                  icon: const ThinIcon(tabler.Share.new, size: 18),
                  label: Text(s.tr('share')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _copyText,
                icon: const ThinIcon(tabler.Copy.new, size: 18),
                tooltip: s.tr('copyPromoText'),
              ),
            ],
          ),
        ],
      ),
    );
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
                    Flexible(
                      child: Text(
                        [
                          if (promo.startDate != null)
                            fmt.format(promo.startDate!),
                          if (promo.endDate != null) fmt.format(promo.endDate!),
                        ].join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
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
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _ActionBtn(
                  icon: tabler.BrandWhatsapp.new,
                  label: s.tr('share'),
                  onTap: onShare,
                ),
                _ActionBtn(
                  icon: tabler.Edit.new,
                  label: s.edit,
                  onTap: onEdit,
                ),
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
