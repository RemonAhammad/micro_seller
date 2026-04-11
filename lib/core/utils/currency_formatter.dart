import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String _symbol = '\$';

  static String get symbol => _symbol;

  static void setSymbol(String symbol) {
    _symbol = symbol;
  }

  static String format(double amount, {String? symbol}) {
    final sym = symbol ?? _symbol;
    final formatted = NumberFormat('#,##0.##').format(amount);
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

  static double parse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}
