import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';
import '../../../shared/widgets/empty_state.dart';

class ExpiryListScreen extends ConsumerStatefulWidget {
  const ExpiryListScreen({super.key});

  @override
  ConsumerState<ExpiryListScreen> createState() => _ExpiryListScreenState();
}

class _ExpiryListScreenState extends ConsumerState<ExpiryListScreen> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isar = await ref.read(isarProvider.future);
    final all = await isar.products
        .filter()
        .isActiveEqualTo(true)
        .expiryDateIsNotNull()
        .findAll();
    final filtered = all.where((p) => p.isNearExpiry || p.isExpired).toList();
    filtered.sort((a, b) {
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
    if (mounted) setState(() { _products = filtered; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('nearExpiryProducts'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: AppIcons.expiry,
                    title: s.tr('noExpiryDate'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final product = _products[i];
                    final isExp = product.isExpired;
                    final color = isExp
                        ? AppColors.statusCancelled
                        : AppColors.statusPending;
                    final daysLeft = product.expiryDate != null
                        ? product.expiryDate!.difference(DateTime.now()).inDays
                        : 0;

                    return InkWell(
                      onTap: () => context.push('/products/${product.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ThinIcon(
                                isExp
                                    ? tabler.AlertOctagon.new
                                    : tabler.Clock.new,
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    product.expiryDate != null
                                        ? (isExp
                                            ? '${s.tr('expiredOn')} ${DateFormat.yMMMd().format(product.expiryDate!)}'
                                            : '${s.tr('expiresOn')} ${DateFormat.yMMMd().format(product.expiryDate!)}')
                                        : '',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isExp
                                    ? s.tr('expired')
                                    : '$daysLeft ${daysLeft == 1 ? "day" : "days"}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
