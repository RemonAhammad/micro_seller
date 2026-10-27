import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/supplier.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_input.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

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
  String _selectedCombinationKey = '';
  Supplier? _selectedSupplier;
  bool _supplierAutoLoaded = false;
  Stream<Product?>? _productStream;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoLoadProductSupplier(Product product) async {
    if (_supplierAutoLoaded) return;
    _supplierAutoLoaded = true;
    if (product.supplierId <= 0) return;
    try {
      final isar = await ref.read(isarProvider.future);
      final supplier = await isar.suppliers.get(product.supplierId);
      if (supplier != null && mounted) {
        setState(() => _selectedSupplier = supplier);
      }
    } catch (_) {}
  }

  Future<void> _pickSupplier() async {
    final isar = await ref.read(isarProvider.future);
    final List<Supplier> suppliers =
        await isar.suppliers.where().sortByName().findAll();
    if (!mounted) return;

    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).noSuppliersYet)),
      );
      return;
    }

    final result = await showModalBottomSheet<Supplier?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StockSupplierPickerSheet(suppliers: suppliers),
    );

    if (result != null) {
      setState(() => _selectedSupplier = result);
    }
  }

  Future<void> _submit() async {
    final qty = NumberInput.parseInteger(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).pleaseEnterValidQty)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final delta = _type == StockMovementType.sale ||
              _type == StockMovementType.damage
          ? -qty
          : qty;

      await ref.read(productProvider.notifier).adjustStock(
            widget.productId,
            delta,
            _reasonCtrl.text.trim(),
            _type,
            combinationKey: _selectedCombinationKey,
            supplierName: _type == StockMovementType.restock
                ? (_selectedSupplier?.name ?? '')
                : '',
            supplierId: _type == StockMovementType.restock
                ? (_selectedSupplier?.id ?? 0)
                : 0,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).stockAdjustedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppStrings.of(context).error}: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isarAsync = ref.watch(isarProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.stockAdjustment)),
      body: isarAsync.when(
        data: (isar) => StreamBuilder<Product?>(
          stream: _productStream ??= isar.products
              .watchObject(widget.productId, fireImmediately: true),
          builder: (ctx, snap) {
            final product = snap.data;
            if (product != null && !_supplierAutoLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _autoLoadProductSupplier(product);
              });
            }
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
                      // The stock column keeps its size while it fits in
                      // 40% of the card; past that (narrow layout, large
                      // text) the number shrinks and its caption wraps, so
                      // the name keeps room.
                      child: LayoutBuilder(
                        builder: (context, constraints) => Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ThinIcon(tabler.Package.new,
                                  color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  Text(
                                      '${AppStrings.of(context).sku}: ${product.sku}',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text('${product.totalStock}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                        ),
                                        maxLines: 1),
                                  ),
                                  Text(s.tr('totalStock'),
                                      style: const TextStyle(fontSize: 11),
                                      textAlign: TextAlign.end),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Combination selector
                    if (product.hasVariants) ...[
                      const SizedBox(height: 16),
                      Text(s.selectCombination,
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
                          ChoiceChip(
                            label: Text('${s.baseStock} (${product.stockQty})'),
                            selected: _selectedCombinationKey.isEmpty,
                            onSelected: (_) =>
                                setState(() => _selectedCombinationKey = ''),
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _selectedCombinationKey.isEmpty
                                  ? cs.primary
                                  : cs.onSurface,
                              fontWeight: _selectedCombinationKey.isEmpty
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          ...product.variantCombinations
                              .where((c) => c.isActive)
                              .map((c) {
                            final selected =
                                _selectedCombinationKey == c.combinationKey;
                            return ChoiceChip(
                              // A label too long for the chip ellipsizes
                              // before its stock count, which stays visible.
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(c.displayLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(' (${c.stockQty})'),
                                ],
                              ),
                              selected: selected,
                              onSelected: (_) => setState(() =>
                                  _selectedCombinationKey = c.combinationKey),
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

                  Text(s.adjustmentType,
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
                            tabler.ShoppingCartPlus.new,
                            s.restock,
                            Colors.green
                          ),
                        StockMovementType.adjustment => (
                            tabler.AdjustmentsHorizontal.new,
                            s.adjust,
                            Colors.blue
                          ),
                        StockMovementType.sale => (
                            tabler.Tag.new,
                            s.sale,
                            Colors.orange
                          ),
                        StockMovementType.damage => (
                            tabler.PhotoOff.new,
                            s.damage,
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
                              ThinIcon(icon,
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

                  // Supplier picker (only for Restock)
                  if (_type == StockMovementType.restock) ...[
                    InkWell(
                      onTap: _pickSupplier,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            ThinIcon(tabler.TruckDelivery.new,
                                color: cs.onSurface.withValues(alpha: 0.5),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectedSupplier != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.suppliers,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.5))),
                                        Text(_selectedSupplier!.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                      ],
                                    )
                                  : Text(s.supplierOptional,
                                      style: TextStyle(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 14)),
                            ),
                            if (_selectedSupplier != null)
                              GestureDetector(
                                onTap: () => setState(
                                    () => _selectedSupplier = null),
                                child: ThinIcon(tabler.X.new,
                                    size: 18,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5)),
                              )
                            else
                              ThinIcon(tabler.ChevronRight.new,
                                  size: 14,
                                  color:
                                      cs.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  AppTextField(
                    label: s.adjustQty,
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [IntegerInputFormatter()],
                    prefixIcon: const ThinIcon(tabler.Number.new),
                    helperText: _type == StockMovementType.sale ||
                            _type == StockMovementType.damage
                        ? s.willDeductFromStock
                        : s.willAddToStock,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: s.reason,
                    controller: _reasonCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  AppButton(
                    label: s.applyAdjustment,
                    onPressed: _submit,
                    isLoading: _isLoading,
                    isFullWidth: true,
                    height: 52,
                    icon: tabler.Check.new,
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

// ─── Supplier Picker Sheet ──────────────────────────────────────────────────

class _StockSupplierPickerSheet extends StatefulWidget {
  final List<Supplier> suppliers;

  const _StockSupplierPickerSheet({required this.suppliers});

  @override
  State<_StockSupplierPickerSheet> createState() =>
      _StockSupplierPickerSheetState();
}

class _StockSupplierPickerSheetState extends State<_StockSupplierPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _query.isEmpty
        ? widget.suppliers
        : widget.suppliers
            .where((s) =>
                s.name.toLowerCase().contains(_query) ||
                s.company.toLowerCase().contains(_query) ||
                s.phone.contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(AppStrings.of(context).tr('selectSupplier'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: '${AppStrings.of(context).search}...',
                prefixIcon: const ThinIcon(tabler.Search.new, size: 20),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(AppStrings.of(context).tr('noSuppliersFound'),
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4))))
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outline.withValues(alpha: 0.1)),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(ctx, s),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.1),
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                                fontSize: 14),
                          ),
                        ),
                        title: Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        subtitle: s.company.isNotEmpty
                            ? Text(s.company,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5)))
                            : null,
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
