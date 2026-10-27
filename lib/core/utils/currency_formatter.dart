import 'package:intl/intl.dart';

import 'number_input.dart';

class CurrencyFormatter {
  /// The Kuwaiti Dinar's symbol in the currency picker: the one currency it
  /// offers whose amounts have 3 decimals (1 dinar is 1000 fils).
  static const kuwaitiDinarSymbol = 'د.ك';

  static String _symbol = '\$';

  static final NumberFormat _amountFormat = NumberFormat('#,##0.##');

  static String get symbol => _symbol;

  /// Sets the shop's currency, and with it the decimals money fields take
  /// ([NumberInput.moneyDecimals]): 3 for the Kuwaiti Dinar, else 2.
  static void setSymbol(String symbol) {
    _symbol = symbol;
    NumberInput.moneyDecimals = symbol == kuwaitiDinarSymbol ? 3 : 2;
  }

  static String format(double amount, {String? symbol}) {
    final sym = symbol ?? _symbol;
    final formatted = _amountFormat.format(amount);
    return '$sym$formatted';
  }

  static String formatCompact(double amount, {String? symbol}) {
    final sym = symbol ?? _symbol;
    if (amount >= 1000000) {
      return '$sym${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$sym${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, symbol: sym);
  }
}
