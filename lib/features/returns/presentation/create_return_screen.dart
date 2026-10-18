import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_item.dart';
import '../../orders/providers/order_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class CreateReturnScreen extends ConsumerStatefulWidget {
  final Order originalOrder;
  const CreateReturnScreen({super.key, required this.originalOrder});
  @override
  ConsumerState<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends ConsumerState<CreateReturnScreen> {
  late List<int> _returnQtys;
  ReturnReason _reason = ReturnReason.defective;
  final _notesCtrl = TextEditingController();
  final _refundCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _returnQtys = widget.originalOrder.items.map((i) => i.qty).toList();
    _updateRefundAmount();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  List<OrderItem> get _returnItems => [
        for (int i = 0; i < widget.originalOrder.items.length; i++)
          if (_returnQtys[i] > 0)
            widget.originalOrder.items[i].copyWith(
              qty: _returnQtys[i],
              totalPrice: widget.originalOrder.items[i].unitPrice * _returnQtys[i],
            ),
      ];

  /// What the selected goods cost the customer (after their share of the
  /// discount, with their share of the tax) — the same value the return
  /// order stores, so the suggested refund matches the Due Book credit.
  double get _returnTotal =>
      returnValueFor(widget.originalOrder, _returnItems).total;

  double get _maxRefundable => widget.originalOrder.amountPaid;

  void _updateRefundAmount() {
    final capped = _returnTotal.clamp(0.0, _maxRefundable);
    _refundCtrl.text = capped.toStringAsFixed(2);
  }

  Future<void> _submit() async {
    if (!_returnQtys.any((q) => q > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).tr('selectAtLeastOneItem'))),
      );
      return;
    }
    final refund = double.tryParse(_refundCtrl.text) ?? 0;
    if (refund < 0 || refund > _maxRefundable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(context)
            .refundRange(CurrencyFormatter.format(_maxRefundable))),
      ));
      return;
    }
    final returnItems = _returnItems;
    setState(() => _isLoading = true);
    try {
      await ref.read(orderProvider.notifier).createReturnOrder(
            originalOrder: widget.originalOrder,
            returnItems: returnItems,
            reason: _reason,
            refundAmount: refund,
            returnNotes: _notesCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).tr('returnRequestSubmitted'))),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).tr('failedToCreateReturn'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TextStyle _sectionLabel(ColorScheme cs) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final order = widget.originalOrder;

    Map<ReturnReason, String> reasonLabels = {
      ReturnReason.defective: s.defective,
      ReturnReason.wrongItem: s.wrongItem,
      ReturnReason.damaged: s.tr('damaged'),
      ReturnReason.changedMind: s.changedMind,
      ReturnReason.other: s.other,
    };

    return Scaffold(
      appBar: AppBar(title: Text(s.createReturnTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(children: [
              ThinIcon(tabler.Receipt.new, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(order.customerName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          Text(s.selectItems, style: _sectionLabel(cs)),
          const SizedBox(height: 8),
          ...List.generate(order.items.length, (i) {
            final item = order.items[i];
            final rQty = _returnQtys[i];
            final dimmed = rQty == 0;
            return AnimatedOpacity(
              opacity: dimmed ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dimmed
                        ? cs.outlineVariant
                        : cs.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.displayName,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${item.productSku}  ·  Ordered: ${item.qty}  ·  ${CurrencyFormatter.format(item.unitPrice)}/ea',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  _buildQtyControl(i, rQty, item.qty, cs),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),

          Text(s.returnReason, style: _sectionLabel(cs)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: ReturnReason.values.map((r) {
              final selected = _reason == r;
              return ChoiceChip(
                label: Text(reasonLabels[r] ?? r.name),
                selected: selected,
                onSelected: (_) => setState(() => _reason = r),
                selectedColor: cs.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? cs.primary : cs.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Text(s.refundAmount, style: _sectionLabel(cs)),
          const SizedBox(height: 8),
          AppTextField(
            label: s.tr('refund'),
            controller: _refundCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            prefixIcon: const ThinIcon(tabler.Cash.new),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.tr("maxRefundable")}: ${CurrencyFormatter.format(_maxRefundable)} (${s.tr("amountPaidOnOriginal")})',
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          Text(s.notes, style: _sectionLabel(cs)),
          const SizedBox(height: 8),
          AppTextField(
            label: s.tr('returnNotesOptional'),
            controller: _notesCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),

          AppButton(
            label: s.submitReturnRequest,
            icon: tabler.ArrowBackUp.new,
            isLoading: _isLoading,
            isFullWidth: true,
            height: 48,
            onPressed: _isLoading ? null : _submit,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQtyControl(int idx, int value, int max, ColorScheme cs) {
    Widget btn(ThinIconBuilder icon, bool enabled, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: enabled ? cs.outline : cs.outlineVariant),
            ),
            child: ThinIcon(icon,
                size: 16, color: enabled ? cs.primary : cs.outlineVariant),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(tabler.Minus.new, value > 0, () {
        setState(() => _returnQtys[idx] = value - 1);
        _updateRefundAmount();
      }),
      SizedBox(
        width: 32,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: value > 0 ? cs.onSurface : cs.onSurfaceVariant,
            )),
      ),
      btn(tabler.Plus.new, value < max, () {
        setState(() => _returnQtys[idx] = value + 1);
        _updateRefundAmount();
      }),
    ]);
  }
}
