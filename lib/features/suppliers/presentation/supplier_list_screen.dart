import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supplier_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/screen_guide.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';
import '../../../shared/widgets/section_help.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ScreenGuide(
      id: 'suppliers',
      steps: [
        GuideStep(title: s.guideSuppliersPurchaseTitle, description: s.guideSuppliersPurchaseDesc),
        GuideStep(title: s.guideSuppliersAddTitle, description: s.guideSuppliersAddDesc),
      ],
      builder: (context, guide) => Scaffold(
      appBar: AppBar(
        title: Text(s.suppliers),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.icon(
              onPressed: () => context.push('/suppliers/add'),
              icon: const ThinIcon(tabler.Plus.new, size: 18),
              label: Text(s.addSupplier),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
          IconButton(
            icon: const ThinIcon(tabler.ShoppingBag.new),
            tooltip: s.allPurchases,
            onPressed: () => context.push('/suppliers/purchases'),
          ),
          const SectionHelpButton('suppliers'),
        ],
      ),
      floatingActionButton: guide.wrap(0, FloatingActionButton.extended(
        heroTag: 'newPurchase',
        onPressed: () {
          final suppliers = ref.read(suppliersProvider).value ?? [];
          if (suppliers.isEmpty) {
            showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(s.noSuppliersYet),
                content: Text(s.createSupplierFirst),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(s.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/suppliers/add');
                    },
                    child: Text(s.addSupplier),
                  ),
                ],
              ),
            );
            return;
          }
          context.push('/suppliers/purchases/add');
        },
        icon: const ThinIcon(tabler.ShoppingBag.new),
        label: Text(s.newPurchase),
      )),
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
                  child: LayoutBuilder(builder: (context, box) {
                    final nameStyle = theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600);
                    final lineStyle = theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    );
                    final dueStyle = TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    );
                    final due = s.hasOutstanding
                        ? '${AppStrings.of(context).due}: ${CurrencyFormatter.format(suppliers[i].totalDue)}'
                        : null;

                    final dueBelow = due != null &&
                        box.maxWidth - _avatarSpace -
                                _textWidth(context, due, dueStyle) <
                            [
                              _textWidth(context, s.name, nameStyle,
                                  widestWord: true),
                              if (s.company.isNotEmpty)
                                _textWidth(context, s.company, lineStyle,
                                    widestWord: true),
                              if (s.phone.isNotEmpty)
                                _textWidth(context, s.phone, lineStyle,
                                    widestWord: true),
                            ].reduce(math.max);
                    return Row(
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
                              Text(s.name, style: nameStyle),
                              if (s.company.isNotEmpty)
                                Text(s.company, style: lineStyle),
                              if (s.phone.isNotEmpty)
                                Text(s.phone, style: lineStyle),
                              if (due != null && dueBelow)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(due, style: dueStyle),
                                ),
                            ],
                          ),
                        ),
                        if (due != null && !dueBelow)
                          Text(due, style: dueStyle),
                      ],
                    );
                  }),
                ),
              ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    ),
    );
  }
}

const _avatarSpace = 22.0 * 2 + 12;

double _textWidth(BuildContext context, String text, TextStyle? style,
    {bool widestWord = false}) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = widestWord ? painter.minIntrinsicWidth : painter.width;
  painter.dispose();
  return width;
}
