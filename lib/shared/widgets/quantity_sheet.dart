import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/number_input.dart';
import '../../core/utils/quantity.dart';
import '../../core/utils/quantity_input.dart';
import '../../data/models/order.dart' show roundMoney;
import '../../data/models/quantity_unit.dart';
import 'app_button.dart';
import 'bottom_sheet_handle.dart';

/// "How much?" for a weighed or measured product (1.25 kg of fish, 2.5 m of
/// cloth): a quantity, or the money the customer wants to spend ("৳200 of
/// fish" → 0.333 kg), with quick chips and the line total.
///
/// Returns the quantity, rounded to 3 decimals, or null when dismissed.
/// [available] caps it (the stock left for this line); pass null for no cap
/// (a purchase adds stock). [unitPrice] is per one [unit]; at 0 the
/// "By amount" mode is off.
///
/// [allowZero] lets the sheet confirm 0 (an empty field counts as 0), so a
/// caller that offers "remove this line" — e.g. the Create Return screen —
/// can set a weighed item back to 0. Off by default, so adding a sale or
/// purchase line still requires a positive quantity.
Future<double?> showQuantitySheet(
  BuildContext context, {
  required String productName,
  required QuantityUnit unit,
  required double unitPrice,
  double? available,
  double? initial,
  bool allowZero = false,
}) {
  return AppBottomSheet.show<double>(
    context,
    title: productName,
    child: QuantitySheet(
      unit: unit,
      unitPrice: unitPrice,
      available: available,
      initial: initial,
      allowZero: allowZero,
    ),
  );
}

class QuantitySheet extends StatefulWidget {
  const QuantitySheet({
    super.key,
    required this.unit,
    required this.unitPrice,
    this.available,
    this.initial,
    this.allowZero = false,
  });

  final QuantityUnit unit;
  final double unitPrice;
  final double? available;
  final double? initial;

  /// When true, 0 is a valid result (an empty field counts as 0), so the line
  /// can be removed. See [showQuantitySheet].
  final bool allowZero;

  /// Quick picks, in the product's unit: ¼ kg, ½ kg, 1, 2, 5.
  static const quickQuantities = [0.25, 0.5, 1.0, 2.0, 5.0];

  @override
  State<QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<QuantitySheet> {
  late final TextEditingController _ctrl;
  bool _byAmount = false;

  bool get _canPriceIt => widget.unitPrice > 0;

  @override
  void initState() {
    super.initState();
    final start = widget.initial;
    _ctrl = TextEditingController(
      text: start != null && start > 0 ? qtyFieldText(start) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// The quantity the field stands for: typed, or worked out from an amount.
  double? get _qty {
    if (_byAmount) {
      final amount = NumberInput.parseDecimal(_ctrl.text);
      if (amount == null || !_canPriceIt) return null;
      return roundQty(amount / widget.unitPrice);
    }
    return parseQty(_ctrl.text, widget.unit);
  }

  /// The value the confirm button would return. With [QuantitySheet.allowZero],
  /// an empty field counts as 0 (remove the line); otherwise 0/empty is invalid.
  double? get _effectiveQty => widget.allowZero ? (_qty ?? 0) : _qty;

  /// Whether the current field can be confirmed.
  bool get _canConfirm {
    final qty = _effectiveQty;
    if (qty == null || _tooMuch(qty)) return false;
    return widget.allowZero ? qty >= 0 : qty > 0;
  }

  bool _tooMuch(double qty) {
    final cap = widget.available;
    return cap != null && qtyExceeds(qty, cap);
  }

  void _setMode(bool byAmount) {
    if (byAmount == _byAmount) return;
    // Carry the value over, so switching shows the same sale the other way.
    final qty = _qty;
    setState(() {
      _byAmount = byAmount;
      if (qty == null || qty <= 0) {
        _ctrl.clear();
      } else if (byAmount) {
        _ctrl.text = roundMoney(qty * widget.unitPrice)
            .toStringAsFixed(NumberInput.moneyDecimals);
      } else {
        _ctrl.text = qtyFieldText(qty);
      }
    });
  }

  void _pick(double qty) {
    setState(() {
      _byAmount = false;
      _ctrl.text = qtyFieldText(qty);
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(_effectiveQty);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = s.unitSymbol(widget.unit);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.pricePer(CurrencyFormatter.format(widget.unitPrice), widget.unit),
          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 12),
        if (_canPriceIt) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(s.byQuantity),
                selected: !_byAmount,
                onSelected: (_) => _setMode(false),
              ),
              ChoiceChip(
                label: Text(s.byAmount),
                selected: _byAmount,
                onSelected: (_) => _setMode(true),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: ValueKey(_byAmount),
          controller: _ctrl,
          autofocus: true,
          keyboardType: _byAmount
              ? const TextInputType.numberWithOptions(decimal: true)
              : qtyKeyboard(widget.unit),
          inputFormatters:
              _byAmount ? const [DecimalInputFormatter.money()] : qtyFormatters(widget.unit),
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _confirm(),
          decoration: InputDecoration(
            labelText: _byAmount ? s.amountToSell : s.quantity,
            prefixText: _byAmount ? '${CurrencyFormatter.symbol} ' : null,
            suffixText: _byAmount || symbol.isEmpty ? null : symbol,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final q in QuantitySheet.quickQuantities)
              if (widget.unit.allowsDecimal || isWholeQty(q))
                ActionChip(
                  label: Text(_quickLabel(q, symbol)),
                  onPressed: () => _pick(q),
                ),
          ],
        ),
        const SizedBox(height: 14),
        _Summary(
          qty: _qty,
          unit: widget.unit,
          unitPrice: widget.unitPrice,
          available: widget.available,
          tooMuch: _tooMuch,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: widget.allowZero && (_effectiveQty ?? 0) <= 0
              ? s.remove
              : widget.initial != null && widget.initial! > 0
                  ? s.updateQty
                  : s.addQty,
          icon: tabler.Check.new,
          isFullWidth: true,
          height: 50,
          onPressed: _canConfirm ? _confirm : null,
        ),
      ],
    );
  }

  /// "¼ kg", "½ kg", "2 kg": a fraction reads faster than 0.25 at a counter.
  static String _quickLabel(double q, String symbol) {
    final number = switch (q) {
      0.25 => '¼',
      0.5 => '½',
      _ => formatQtyNumber(q),
    };
    return symbol.isEmpty ? number : '$number $symbol';
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.qty,
    required this.unit,
    required this.unitPrice,
    required this.available,
    required this.tooMuch,
  });

  final double? qty;
  final QuantityUnit unit;
  final double unitPrice;
  final double? available;
  final bool Function(double) tooMuch;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = qty;
    final cap = available;

    if (q != null && q > 0 && tooMuch(q)) {
      return _line(
        tabler.AlertCircle.new,
        s.stockLeftAfter(s.qty(cap ?? 0, unit)),
        cs.error,
        theme,
      );
    }
    if (q == null || q <= 0) {
      return _line(
        tabler.InfoCircle.new,
        cap != null ? s.stockLeftAfter(s.qty(cap, unit)) : s.enterQuantity,
        cs.onSurface.withValues(alpha: 0.6),
        theme,
      );
    }
    final total = CurrencyFormatter.format(roundMoney(q * unitPrice));
    final left = cap != null ? ' · ${s.stockLeftAfter(s.qty(roundQty(cap - q), unit))}' : '';
    return _line(
      tabler.ShoppingCart.new,
      '${s.qty(q, unit)} = $total$left',
      cs.primary,
      theme,
    );
  }

  Widget _line(ThinIconBuilder icon, String text, Color color, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThinIcon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
