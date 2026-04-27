import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/supplier_provider.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final int? supplierId;

  const PurchaseFormScreen({super.key, this.supplierId});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _amountPaidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Supplier? _selectedSupplier;
  final List<PurchaseItem> _items = [];
  PurchasePaymentMethod _paymentMethod = PurchasePaymentMethod.cash;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) {
      _loadSupplier();
    }
  }

  Future<void> _loadSupplier() async {
    final isar = await ref.read(isarProvider.future);
    final s = await isar.suppliers.get(widget.supplierId!);
    if (s != null && mounted) {
      setState(() => _selectedSupplier = s);
    }
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _notesCtrl.dispose();
    _refCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      _items.fold(0.0, (s, i) => s + i.totalCost);

  double get _amountPaid => double.tryParse(_amountPaidCtrl.text) ?? 0;

  double get _balanceDue =>
      (_totalAmount - _amountPaid).clamp(0, double.infinity);

  Future<void> _pickSupplier() async {
    final isar = await ref.read(isarProvider.future);
    final suppliers = await isar.suppliers.where().sortByName().findAll();
    if (!mounted) return;

    final result = await showModalBottomSheet<Supplier?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SupplierPickerSheet(suppliers: suppliers, isar: isar),
    );

    if (result != null) {
      setState(() => _selectedSupplier = result);
    }
  }

  Future<void> _pickProducts() async {
    final isar = await ref.read(isarProvider.future);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ProductPickerSheet(
        isar: isar,
        currentItems: _items,
        supplierId: _selectedSupplier?.id ?? 0,
        supplierName: _selectedSupplier?.name ?? '',
        onChanged: (updated) => setState(() {
          _items
            ..clear()
            ..addAll(updated);
        }),
      ),
    );
  }

  void _updateItemCost(int index, String value) {
    final cost = double.tryParse(value) ?? 0;
    setState(() {
      _items[index] = _items[index].copyWith(
        unitCost: cost,
        totalCost: cost * _items[index].qty,
      );
    });
  }

  void _updateItemQty(int index, int delta) {
    final newQty = _items[index].qty + delta;
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
      return;
    }
    setState(() {
      _items[index] = _items[index].copyWith(
        qty: newQty,
        totalCost: _items[index].unitCost * newQty,
      );
    });
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).addAtLeastOneItem)),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final purchase = Purchase(
        supplierId: _selectedSupplier?.id ?? 0,
        supplierName: _selectedSupplier?.name ?? '',
        items: _items,
        totalAmount: _totalAmount,
        amountPaid: _amountPaid,
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.trim(),
        referenceNumber: _refCtrl.text.trim(),
      );

      await ref
          .read(supplierProvider.notifier)
          .createPurchase(purchase);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).purchaseRecorded),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).failedToSavePurchase),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.newPurchase)),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Supplier picker (optional) ─────────────────────────────
            Text(s.supplierOptional,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                )),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickSupplier,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        color: cs.onSurface.withValues(alpha: 0.5), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedSupplier != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedSupplier!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                if (_selectedSupplier!.company.isNotEmpty)
                                  Text(_selectedSupplier!.company,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5))),
                              ],
                            )
                          : Text(s.tapToSelectSupplier,
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  fontSize: 13)),
                    ),
                    if (_selectedSupplier != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedSupplier = null),
                        child: Icon(Icons.close,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      )
                    else
                      Icon(Icons.arrow_forward_ios,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Items ──────────────────────────────────────────────────
            Row(
              children: [
                Text(s.items,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    )),
                if (_items.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_items.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickProducts,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(s.add, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: _pickProducts,
                    child: Column(
                      children: [
                        Icon(Icons.add_shopping_cart_rounded,
                            size: 32, color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(s.tr('tapToAddProducts'),
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _items.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                            color: cs.outline.withValues(alpha: 0.1)),
                      _buildItemTile(i, theme, cs),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── Payment ────────────────────────────────────────────────
            Text(s.payment,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                )),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: s.amountPaid,
                    controller: _amountPaidCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: _totalAmount > 0
                        ? () => setState(() => _amountPaidCtrl.text =
                            _totalAmount.toStringAsFixed(
                                _totalAmount == _totalAmount.roundToDouble()
                                    ? 0
                                    : 2))
                        : null,
                    child: Text(s.payFull),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment method chips
            Wrap(
              spacing: 6,
              children: PurchasePaymentMethod.values.map((m) {
                final selected = _paymentMethod == m;
                return ChoiceChip(
                  label: Text(_methodLabel(m)),
                  selected: selected,
                  onSelected: (_) => setState(() => _paymentMethod = m),
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected ? cs.primary : null,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            AppTextField(
              label: s.referenceReceipt,
              controller: _refCtrl,
            ),
            const SizedBox(height: 12),

            AppTextField(
              label: s.notesOptional,
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 20),

            // ── Summary ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _summaryRow(theme, s.total,
                      CurrencyFormatter.format(_totalAmount), isBold: true),
                  _summaryRow(theme, s.paid,
                      CurrencyFormatter.format(_amountPaid)),
                  if (_balanceDue > 0)
                    _summaryRow(
                      theme,
                      s.due,
                      CurrencyFormatter.format(_balanceDue),
                      valueColor: Colors.red,
                      isBold: true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            AppButton(
              label: s.savePurchase,
              icon: Icons.check_rounded,
              onPressed: _submit,
              isLoading: _isLoading,
              isFullWidth: true,
              height: 52,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(int index, ThemeData theme, ColorScheme cs) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => setState(() => _items.removeAt(index)),
                child: Icon(Icons.close,
                    size: 16, color: cs.error.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Qty controls
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: cs.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _updateItemQty(index, -1),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.remove, size: 14, color: cs.primary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('${item.qty}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    InkWell(
                      onTap: () => _updateItemQty(index, 1),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 14, color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Unit cost field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context).unitCost,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                    ],
                    controller: TextEditingController(
                        text: item.unitCost > 0 ? item.unitCost.toString() : '')
                      ..selection = TextSelection.collapsed(
                          offset: item.unitCost > 0
                              ? item.unitCost.toString().length
                              : 0),
                    onChanged: (val) => _updateItemCost(index, val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Total
              SizedBox(
                width: 70,
                child: Text(
                  CurrencyFormatter.format(item.totalCost),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: cs.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              )),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor,
              )),
        ],
      ),
    );
  }

  String _methodLabel(PurchasePaymentMethod m) {
    final s = AppStrings.of(context);
    return switch (m) {
      PurchasePaymentMethod.cash => s.cash,
      PurchasePaymentMethod.card => s.card,
      PurchasePaymentMethod.bkash => s.bkash,
      PurchasePaymentMethod.nagad => s.nagad,
      PurchasePaymentMethod.bank => s.bank,
      PurchasePaymentMethod.other => s.other,
    };
  }
}

// ─── Supplier Picker Sheet ─────────────────────────────────────────────────

class _SupplierPickerSheet extends StatefulWidget {
  final List<Supplier> suppliers;
  final Isar isar;

  const _SupplierPickerSheet({required this.suppliers, required this.isar});

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
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
                prefixIcon: const Icon(Icons.search, size: 20),
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
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
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
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5)))
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

// ─── Product Picker Sheet (with cost field) ────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final Isar isar;
  final List<PurchaseItem> currentItems;
  final int supplierId;
  final String supplierName;
  final ValueChanged<List<PurchaseItem>> onChanged;

  const _ProductPickerSheet({
    required this.isar,
    required this.currentItems,
    required this.supplierId,
    required this.supplierName,
    required this.onChanged,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late final List<PurchaseItem> _items;
  final _searchCtrl = TextEditingController();
  String _query = '';
  late bool _onlySupplierProducts;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.currentItems);
    _onlySupplierProducts = widget.supplierId > 0;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _qtyOf(int productId) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    return idx >= 0 ? _items[idx].qty : 0;
  }

  void _setQty(Product product, int qty) {
    setState(() {
      final idx = _items.indexWhere((i) => i.productId == product.id);
      if (qty <= 0) {
        if (idx >= 0) _items.removeAt(idx);
      } else if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(
          qty: qty,
          totalCost: _items[idx].unitCost * qty,
        );
      } else {
        _items.add(PurchaseItem(
          productId: product.id,
          productName: product.name,
          qty: qty,
          unitCost: product.costPrice,
          totalCost: product.costPrice * qty,
        ));
      }
    });
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<List<Product>>(
      stream: widget.isar.products
          .where()
          .filter()
          .isActiveEqualTo(true)
          .sortByName()
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        var filtered = all;
        // Apply supplier filter
        if (_onlySupplierProducts && widget.supplierId > 0) {
          filtered = filtered
              .where((p) => p.supplierId == widget.supplierId)
              .toList();
        }
        // Apply search filter
        if (_query.isNotEmpty) {
          filtered = filtered
              .where((p) =>
                  p.name.toLowerCase().contains(_query) ||
                  p.sku.toLowerCase().contains(_query))
              .toList();
        }

        final totalItems = _items.fold<int>(0, (s, i) => s + i.qty);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
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
                child: Row(
                  children: [
                    Text(AppStrings.of(context).addItems,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (totalItems > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$totalItems item${totalItems == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                      ),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppStrings.of(context).done),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: '${AppStrings.of(context).search}...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                ),
              ),
              if (widget.supplierId > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(
                          _onlySupplierProducts
                              ? '${widget.supplierName} only'
                              : 'All products',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _onlySupplierProducts,
                        onSelected: (v) =>
                            setState(() => _onlySupplierProducts = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(AppStrings.of(context).noProductsFound,
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
                          final p = filtered[i];
                          final qty = _qtyOf(p.id);

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      Text(
                                        '${AppStrings.of(context).stock}: ${p.stockQty}  ·  ${AppStrings.of(context).costPrice}: ${CurrencyFormatter.format(p.costPrice)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (qty > 0)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: cs.primary
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _setQty(p, qty - 1),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(Icons.remove,
                                                size: 16,
                                                color: cs.primary),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          child: Text('$qty',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.primary)),
                                        ),
                                        InkWell(
                                          onTap: () => _setQty(p, qty + 1),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(Icons.add,
                                                size: 16,
                                                color: cs.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 34,
                                    child: FilledButton.tonal(
                                      onPressed: () => _setQty(p, 1),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                      ),
                                      child: Text(AppStrings.of(context).add),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
