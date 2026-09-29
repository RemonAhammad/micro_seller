import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/order.dart';

String paymentMethodLabel(BuildContext context, PaymentMethod method) {
  final s = AppStrings.of(context);
  return switch (method) {
    PaymentMethod.cash => s.cash,
    PaymentMethod.card => s.card,
    PaymentMethod.mfs => s.mfs,
    PaymentMethod.bank => s.bank,
    PaymentMethod.other => s.other,
  };
}

/// Single-select payment method chips (Cash / Card / MFS / Bank / Other).
class PaymentMethodChips extends StatelessWidget {
  const PaymentMethodChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: PaymentMethod.values
          .map((m) => ChoiceChip(
                label: Text(paymentMethodLabel(context, m)),
                selected: selected == m,
                onSelected: (_) => onChanged(m),
              ))
          .toList(),
    );
  }
}
