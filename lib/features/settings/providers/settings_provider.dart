import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  static const _keyShopName = 'shopName';
  static const _keyCurrency = 'currencySymbol';
  static const _keyThreshold = 'lowStockThreshold';
  static const _keyLastBackup = 'lastBackupTime';

  @override
  Map<String, dynamic> build() {
    _loadFromDisk();
    return {
      'shopName': 'My Shop',
      'currencySymbol': '৳',
      'lowStockThreshold': 10,
      'lastBackupTime': null,
    };
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      'shopName': prefs.getString(_keyShopName) ?? 'My Shop',
      'currencySymbol': prefs.getString(_keyCurrency) ?? '৳',
      'lowStockThreshold': prefs.getInt(_keyThreshold) ?? 10,
      'lastBackupTime': prefs.getString(_keyLastBackup) != null
          ? DateTime.tryParse(prefs.getString(_keyLastBackup)!)
          : null,
    };
  }

  Future<void> updateShopName(String name) async {
    state = {...state, 'shopName': name};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopName, name);
  }

  Future<void> updateCurrencySymbol(String symbol) async {
    state = {...state, 'currencySymbol': symbol};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, symbol);
  }

  Future<void> updateLowStockThreshold(int threshold) async {
    state = {...state, 'lowStockThreshold': threshold};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThreshold, threshold);
  }

  Future<void> updateLastBackupTime(DateTime time) async {
    state = {...state, 'lastBackupTime': time};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackup, time.toIso8601String());
  }

  String get shopName => state['shopName'] as String? ?? 'My Shop';
  String get currencySymbol => state['currencySymbol'] as String? ?? '৳';
  int get lowStockThreshold => state['lowStockThreshold'] as int? ?? 10;
  DateTime? get lastBackupTime => state['lastBackupTime'] as DateTime?;
}
