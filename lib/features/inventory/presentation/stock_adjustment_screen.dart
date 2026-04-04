import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/product.dart';
import '../../../data/models/product_variant.dart';
import '../../../data/models/stock_movement.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final int productId;

  const StockAdjustmentScreen({super.key, required this.productId});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState
    extends ConsumerState<StockAdjustmentScreen> {
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  StockMovementType _type = StockMovementType.restock;
  bool _isLoading = false;
  ProductVariant? _selectedVariant;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final delta = _type == StockMovementType.sale ||
              _type == StockMovementType.damage
          ? -qty
          : qty;

      await ref.read(productNotifierProvider.notifier).adjustStock(
            widget.productId,
            delta,
            _reasonCtrl.text.trim(),
            _type,
            variantName: _selectedVariant?.name ?? '',
            variantValue: _selectedVariant?.value ?? '',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock adjusted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isarAsync = ref.watch(isarProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.stockAdjustment)),
      body: isarAsync.when(
        data: (isar) => StreamBuilder<Product?>(
          stream: isar.products
              .watchObject(widget.productId, fireImmediately: true),
          builder: (ctx, snap) {
            final product = snap.data;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product != null) ...[
                    // Product header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.inventory_2_rounded,
                                color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                Text('SKU: ${product.sku}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${product.stockQty}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  )),
                              const Text('in stock',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Variant selector
                    if (product.hasVariants) ...[
                      const SizedBox(height: 16),
                      Text('Select Variant',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          )),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // "All / Base" option
                          ChoiceChip(
                            label: Text('Base stock (${product.stockQty})'),
                            selected: _selectedVariant == null,
                            onSelected: (_) =>
                                setState(() => _selectedVariant = null),
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _selectedVariant == null
                                  ? cs.primary
                                  : cs.onSurface,
                              fontWeight: _selectedVariant == null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          ...product.variants.map((v) {
                            final selected = _selectedVariant?.name == v.name &&
                                _selectedVariant?.value == v.value;
                            return ChoiceChip(
                              label:
                                  Text('${v.name}: ${v.value} (${v.stockQty})'),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedVariant = v),
                              selectedColor:
                                  cs.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: selected ? cs.primary : cs.onSurface,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          }),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],

                  Text('Adjustment Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      )),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: StockMovementType.values.map((type) {
                      final (icon, label, color) = switch (type) {
                        StockMovementType.restock => (
                            Icons.add_shopping_cart_rounded,
                            'Restock',
                            Colors.green
                          ),
                        StockMovementType.adjustment => (
                            Icons.tune_rounded,
                            'Adjust',
                            Colors.blue
                          ),
                        StockMovementType.sale => (
                            Icons.sell_rounded,
                            'Sale',
                            Colors.orange
                          ),
                        StockMovementType.damage => (
                            Icons.broken_image_rounded,
                            'Damage',
                            Colors.red
                          ),
                      };
                      final isSelected = _type == type;

                      return GestureDetector(
                        onTap: () => setState(() => _type = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : cs.outline.withValues(alpha: 0.25),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon,
                                  color: isSelected
                                      ? color
                                      : cs.onSurface.withValues(alpha: 0.5),
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? color
                                        : cs.onSurface.withValues(alpha: 0.6),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  AppTextField(
                    label: AppStrings.adjustQty,
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    helperText: _type == StockMovementType.sale ||
                            _type == StockMovementType.damage
                        ? 'This will deduct from stock'
                        : 'This will add to stock',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: AppStrings.reason,
                    controller: _reasonCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  AppButton(
                    label: 'Apply Adjustment',
                    onPressed: _submit,
                    isLoading: _isLoading,
                    isFullWidth: true,
                    height: 52,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
