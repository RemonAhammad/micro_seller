import 'package:intl/intl.dart';

import 'number_input.dart';

class CurrencyFormatter {
  /// The Kuwaiti Dinar's symbol in the currency picker: the one currency it
  /// offers whose amounts have 3 decimals (1 dinar is 1000 fils).
  static const kuwaitiDinarSymbol = 'د.ك';

  static String _symbol = '\$';

  static final NumberFormat _amountFormat = NumberFormat('#,##0.##');

  /// The Kuwaiti Dinar's amounts: up to 3 decimals, its fils.
  static final NumberFormat _filsFormat = NumberFormat('#,##0.###');

  static String get symbol => _symbol;

  /// Sets the shop's currency, and with it the decimals money fields take
  /// ([NumberInput.moneyDecimals]): 3 for the Kuwaiti Dinar, else 2.
  static void setSymbol(String symbol) {
    _symbol = symbol;
    NumberInput.moneyDecimals = symbol == kuwaitiDinarSymbol ? 3 : 2;
  }

  /// [amount] with the currency's symbol, grouped in thousands with ',' and
  /// with as many decimals as it has, up to the currency's: 2, or the
  /// Kuwaiti Dinar's 3 (a due of 1.125 dinars shows its fils, as the money
  /// fields type them).
  static String format(double amount, {String? symbol}) {
    final sym = symbol ?? _symbol;
    final amounts = sym == kuwaitiDinarSymbol ? _filsFormat : _amountFormat;
    final formatted = amounts.format(amount);
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
