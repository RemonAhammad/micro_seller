import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  Map<String, dynamic> build() {
    return {
      'shopName': 'My Shop',
      'currencySymbol': '৳',
      'lowStockThreshold': 10,
      'lastBackupTime': null,
    };
  }

  void updateShopName(String name) {
    state = {...state, 'shopName': name};
  }

  void updateCurrencySymbol(String symbol) {
    state = {...state, 'currencySymbol': symbol};
  }

  void updateLowStockThreshold(int threshold) {
    state = {...state, 'lowStockThreshold': threshold};
  }

  void updateLastBackupTime(DateTime time) {
    state = {...state, 'lastBackupTime': time};
  }

  String get shopName => state['shopName'] as String? ?? 'My Shop';
  String get currencySymbol => state['currencySymbol'] as String? ?? '৳';
  int get lowStockThreshold => state['lowStockThreshold'] as int? ?? 10;
  DateTime? get lastBackupTime => state['lastBackupTime'] as DateTime?;
}
