import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_input.dart';
import '../../../data/models/product.dart';
import '../../../data/models/promotion.dart';
import '../../../data/services/isar_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/promotion_provider.dart';

class PromotionFormScreen extends ConsumerStatefulWidget {
  const PromotionFormScreen({super.key, this.promotionId});
  final int? promotionId;

  @override
  ConsumerState<PromotionFormScreen> createState() =>
      _PromotionFormScreenState();
}

class _PromotionFormScreenState extends ConsumerState<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _discountPercentController = TextEditingController();
  final _discountAmountController = TextEditingController();
  final _couponCodeController = TextEditingController();
  final _messageController = TextEditingController();

  String _type = 'discount';
  bool _usePercent = true;
  DateTime? _startDate;
  DateTime? _endDate;
  List<int> _selectedProductIds = [];
  List<String> _selectedProductNames = [];
  bool _isLoading = false;
  int _editId = Isar.autoIncrement;
  DateTime? _createdAt;

  bool get _isEdit => widget.promotionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadPromotion();
    }
  }

  Future<void> _loadPromotion() async {
    final isar = await ref.read(isarProvider.future);
    final promo = await isar.promotions.get(widget.promotionId!);
    if (promo == null || !mounted) return;
    setState(() {
      _editId = promo.id;
      _createdAt = promo.createdAt;
      _type = promo.type;
      _titleController.text = promo.title;
      if (promo.discountPercent > 0) {
        _usePercent = true;
        _discountPercentController.text =
            promo.discountPercent.toStringAsFixed(2);
      } else if (promo.discountAmount > 0) {
        _usePercent = false;
        _discountAmountController.text =
            promo.discountAmount.toStringAsFixed(2);
      }
      _couponCodeController.text = promo.couponCode;
      _messageController.text = promo.message;
      _startDate = promo.startDate;
      _endDate = promo.endDate;
      _selectedProductIds = List.of(promo.productIds);
      _selectedProductNames = List.of(promo.productNames);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _discountPercentController.dispose();
    _discountAmountController.dispose();
    _couponCodeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat.yMMMd().format(d);

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: now,
    );
    if (range == null || !mounted) return;
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  Future<void> _pickProducts() async {
    final isar = await ref.read(isarProvider.future);
    final products =
        await isar.products.filter().isActiveEqualTo(true).findAll();
    if (!mounted) return;

    final selected = Set<int>.from(_selectedProductIds);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.of(ctx).tr('selectProducts'),
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(AppStrings.of(ctx).tr('done')),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: products.length,
                        itemBuilder: (_, i) {
                          final p = products[i];
                          final isSelected = selected.contains(p.id);
                          return CheckboxListTile(
                            title: Text(p.name),
                            subtitle: p.sku.isNotEmpty ? Text(p.sku) : null,
                            value: isSelected,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  selected.add(p.id);
                                } else {
                                  selected.remove(p.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    if (!mounted) return;
    final names = <String>[];
    for (final id in selected) {
      final p = products.where((p) => p.id == id).firstOrNull;
      if (p != null) names.add(p.name);
    }
    setState(() {
      _selectedProductIds = selected.toList();
      _selectedProductNames = names;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final percent = _usePercent
        ? (NumberInput.parseDecimal(_discountPercentController.text) ?? 0)
        : 0.0;
    final amount = !_usePercent
        ? (NumberInput.parseDecimal(_discountAmountController.text) ?? 0)
        : 0.0;

    final promo = Promotion(
      id: _isEdit ? _editId : Isar.autoIncrement,
      title: _titleController.text.trim(),
      type: _type,
      discountPercent: percent,
      discountAmount: amount,
      couponCode: _couponCodeController.text.trim(),
      productIds: _selectedProductIds,
      productNames: _selectedProductNames,
      message: _messageController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      isActive: true,
      createdAt: _createdAt,
    );

    await ref.read(promotionProvider.notifier).save(promo);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr(_isEdit ? 'editPromotion' : 'createPromotion')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.tr('promotionType'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(s.tr('discount')),
                  selected: _type == 'discount',
                  onSelected: (_) => setState(() => _type = 'discount'),
                ),
                ChoiceChip(
                  label: Text(s.tr('coupon')),
                  selected: _type == 'coupon',
                  onSelected: (_) => setState(() => _type = 'coupon'),
                ),
                ChoiceChip(
                  label: Text(s.tr('banner')),
                  selected: _type == 'banner',
                  onSelected: (_) => setState(() => _type = 'banner'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _titleController,
              label: s.tr('promotionTitle'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.tr('required') : null,
            ),
            const SizedBox(height: 16),
            Text(s.tr('discountType'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(s.tr('percentDiscount')),
                  selected: _usePercent,
                  onSelected: (_) => setState(() => _usePercent = true),
                ),
                ChoiceChip(
                  label: Text(s.tr('flatDiscount')),
                  selected: !_usePercent,
                  onSelected: (_) => setState(() => _usePercent = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_usePercent)
              AppTextField(
                controller: _discountPercentController,
                label: s.tr('discountPercent'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [DecimalInputFormatter.percent()],
              )
            else
              AppTextField(
                controller: _discountAmountController,
                label:
                    '${s.tr('discountAmount')} (${CurrencyFormatter.symbol})',
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [DecimalInputFormatter.money()],
              ),
            if (_type == 'coupon') ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _couponCodeController,
                label: s.tr('couponCode'),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _messageController,
              label: s.tr('promotionMessage'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(s.tr('selectProducts'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(s.tr('storeWide'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickProducts,
              icon: ThinIcon(tabler.ShoppingCart.new, size: 18),
              label: Text(s.tr('selectProducts')),
            ),
            if (_selectedProductNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(_selectedProductNames.length, (i) {
                  return Chip(
                    label: Text(_selectedProductNames[i]),
                    onDeleted: () {
                      setState(() {
                        _selectedProductIds.removeAt(i);
                        _selectedProductNames.removeAt(i);
                      });
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const ThinIcon(tabler.Calendar.new, size: 18),
              label: Text(
                _startDate != null && _endDate != null
                    ? '${_formatDate(_startDate!)} – ${_formatDate(_endDate!)}'
                    : '${s.tr('validFrom')} – ${s.tr('validUntil')}',
              ),
            ),
            if (_startDate != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => setState(() {
                    _startDate = null;
                    _endDate = null;
                  }),
                  child: Text(s.tr('clearSelection')),
                ),
              ),
            const SizedBox(height: 24),
            AppButton(
              label: s.tr(_isEdit ? 'update' : 'save'),
              onPressed: _isLoading ? null : _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

