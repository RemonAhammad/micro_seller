import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_input.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sales_target.dart';
import '../../../data/services/isar_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/sales_target_provider.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _revenueCtrl = TextEditingController();
  final _profitCtrl = TextEditingController();
  final _orderCountCtrl = TextEditingController();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _revenueCtrl.dispose();
    _profitCtrl.dispose();
    _orderCountCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(SalesTarget? target) {
    if (_initialized) return;
    _initialized = true;
    if (target == null) return;
    if (target.revenueTarget > 0) {
      _revenueCtrl.text = target.revenueTarget.toStringAsFixed(0);
    }
    if (target.profitTarget > 0) {
      _profitCtrl.text = target.profitTarget.toStringAsFixed(0);
    }
    if (target.orderCountTarget > 0) {
      _orderCountCtrl.text = target.orderCountTarget.toString();
    }
  }

  Future<void> _saveTargets() async {
    setState(() => _isLoading = true);
    try {
      final revenue = NumberInput.parseDecimal(_revenueCtrl.text) ?? 0;
      final profit = NumberInput.parseDecimal(_profitCtrl.text) ?? 0;
      final orderCount = NumberInput.parseInteger(_orderCountCtrl.text) ?? 0;

      final existing =
          ref.read(salesTargetProvider).value;
      final now = DateTime.now();
      final target = (existing ??
              SalesTarget(year: now.year, month: now.month))
          .copyWith(
        revenueTarget: revenue,
        profitTarget: profit,
        orderCountTarget: orderCount,
      );
      await ref
          .read(salesTargetProvider.notifier)
          .saveTarget(target);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.of(context).savedSuccessfully),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addProductTarget() async {
    final isar = await ref.read(isarProvider.future);
    final products = await isar.products
        .filter()
        .isActiveEqualTo(true)
        .findAll();
    if (products.isEmpty || !mounted) return;

    final existing =
        ref.read(salesTargetProvider).value;
    final existingIds =
        existing?.productTargets.map((t) => t.productId).toSet() ?? {};

    final available =
        products.where((p) => !existingIds.contains(p.id)).toList();
    if (available.isEmpty) return;

    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(products: available),
    );
    if (picked == null || !mounted) return;

    final qtyCtrl = TextEditingController();
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final s = AppStrings.of(ctx);
        return AlertDialog(
          title: Text(picked.name),
          content: TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: const [IntegerInputFormatter()],
            decoration: InputDecoration(
              labelText: s.tr('targetQuantity'),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () {
                final v = NumberInput.parseInteger(qtyCtrl.text);
                if (v != null && v > 0) Navigator.pop(ctx, v);
              },
              child: Text(s.tr('add')),
            ),
          ],
        );
      },
    );
    qtyCtrl.dispose();
    if (qty == null) return;

    await ref.read(salesTargetProvider.notifier).addProductTarget(
          ProductTarget(
            productId: picked.id,
            productName: picked.name,
            targetQty: qty,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final targetAsync = ref.watch(salesTargetProvider);

    return targetAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(s.tr('salesTargets'))),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(s.tr('salesTargets'))),
        body: Center(child: Text('$e')),
      ),
      data: (target) {
        _populateControllers(target);
        final cs = Theme.of(context).colorScheme;
        final productTargets = target?.productTargets ?? [];
        return Scaffold(
          appBar: AppBar(title: Text(s.tr('salesTargets'))),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('monthlyTargets'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: '${s.tr('revenueTarget')} (${CurrencyFormatter.symbol})',
                        controller: _revenueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalInputFormatter.money()],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: '${s.tr('profitTarget')} (${CurrencyFormatter.symbol})',
                        controller: _profitCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalInputFormatter.money()],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: s.tr('orderCountTarget'),
                        controller: _orderCountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [IntegerInputFormatter()],
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: s.tr('saveTargets'),
                        onPressed: _saveTargets,
                        isLoading: _isLoading,
                        isFullWidth: true,
                        height: 48,
                        icon: tabler.DeviceFloppy.new,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.tr('productTargets'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          IconButton(
                            icon: ThinIcon(tabler.Plus.new, size: 20),
                            onPressed: _addProductTarget,
                            tooltip: s.tr('addProductTarget'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (productTargets.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        s.tr('noProductTargets'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: productTargets.length,
                    itemBuilder: (context, i) {
                      final pt = productTargets[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            title: Text(pt.productName),
                            subtitle: Text('${s.tr('target')}: ${pt.targetQty}'),
                            trailing: IconButton(
                              icon: ThinIcon(tabler.Trash.new, size: 18, color: Colors.red),
                              onPressed: () => ref
                                  .read(salesTargetProvider.notifier)
                                  .removeProductTarget(pt.productId),
                              tooltip: s.tr('remove'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              s.tr('selectProduct'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: products.length,
              itemBuilder: (ctx, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: p.sku.isNotEmpty ? Text(p.sku) : null,
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
