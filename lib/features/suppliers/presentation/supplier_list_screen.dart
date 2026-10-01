import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supplier_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.suppliers),
        actions: [
          IconButton(
            icon: const ThinIcon(tabler.ShoppingBag.new),
            tooltip: s.allPurchases,
            onPressed: () => context.push('/suppliers/purchases'),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'newPurchase',
            onPressed: () => context.push('/suppliers/purchases/add'),
            icon: const ThinIcon(tabler.ShoppingBag.new),
            label: Text(s.newPurchase),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addSupplier',
            onPressed: () => context.push('/suppliers/add'),
            tooltip: s.addSupplier,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const ThinIcon(tabler.Plus.new),
          ),
        ],
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return EmptyState(
              icon: tabler.TruckDelivery.new,
              title: s.noSuppliersYet,
              subtitle: s.tr('addSuppliersFromMenu'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = suppliers[i];
              return AnimatedEntrance(
                index: i,
                child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6),
                  ],
                ),
                child: InkWell(
                  onTap: () => context.push('/suppliers/${s.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primary.withValues(alpha: 0.1),
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            if (s.company.isNotEmpty)
                              Text(s.company,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  )),
                            if (s.phone.isNotEmpty)
                              Text(s.phone,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  )),
                          ],
                        ),
                      ),
                      if (s.hasOutstanding)
                        Text(
                          '${AppStrings.of(context).due}: ${CurrencyFormatter.format(suppliers[i].totalDue)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
