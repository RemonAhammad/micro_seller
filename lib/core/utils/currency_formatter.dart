import 'package:intl/intl.dart';

import 'number_input.dart';

class CurrencyFormatter {

  static const kuwaitiDinarSymbol = 'د.ك';

  static String _symbol = '\$';

  static final NumberFormat _amountFormat = NumberFormat('#,##0.##');

  static final NumberFormat _filsFormat = NumberFormat('#,##0.###');

  static String get symbol => _symbol;

  static void setSymbol(String symbol) {
    _symbol = symbol;
    NumberInput.moneyDecimals = symbol == kuwaitiDinarSymbol ? 3 : 2;
  }

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
