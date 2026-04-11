import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/currency_formatter.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  static const _keyShopName = 'shopName';
  static const _keyCurrency = 'currencySymbol';
  static const _keyThreshold = 'lowStockThreshold';
  static const _keyLastBackup = 'lastBackupTime';
  static const _keyThemeMode = 'themeMode';
  static const _keyTaxRate = 'taxRate';
  static const _keyLanguage = 'language';
  static const _keyDownloadDir = 'downloadDirectory';

  @override
  Map<String, dynamic> build() {
    _loadFromDisk();
    return {
      'shopName': 'My Shop',
      'currencySymbol': '\$',
      'lowStockThreshold': 10,
      'lastBackupTime': null,
      'themeMode': 'system',
      'taxRate': 0.0,
      'language': 'en',
      'downloadDirectory': '',
    };
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = prefs.getString(_keyCurrency) ?? '\$';
    CurrencyFormatter.setSymbol(currency);
    state = {
      'shopName': prefs.getString(_keyShopName) ?? 'My Shop',
      'currencySymbol': currency,
      'lowStockThreshold': prefs.getInt(_keyThreshold) ?? 10,
      'lastBackupTime':
          prefs.getString(_keyLastBackup) != null ? DateTime.tryParse(prefs.getString(_keyLastBackup)!) : null,
      'themeMode': prefs.getString(_keyThemeMode) ?? 'system',
      'taxRate': prefs.getDouble(_keyTaxRate) ?? 0.0,
      'language': prefs.getString(_keyLanguage) ?? 'en',
      'downloadDirectory': prefs.getString(_keyDownloadDir) ?? '',
    };
  }

  Future<void> updateShopName(String name) async {
    state = {...state, 'shopName': name};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopName, name);
  }

  Future<void> updateCurrencySymbol(String symbol) async {
    CurrencyFormatter.setSymbol(symbol);
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

  Future<void> updateThemeMode(String mode) async {
    state = {...state, 'themeMode': mode};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<void> updateTaxRate(double rate) async {
    state = {...state, 'taxRate': rate};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTaxRate, rate);
  }

  String get shopName => state['shopName'] as String? ?? 'My Shop';
  String get currencySymbol => state['currencySymbol'] as String? ?? '\$';
  int get lowStockThreshold => state['lowStockThreshold'] as int? ?? 10;
  DateTime? get lastBackupTime => state['lastBackupTime'] as DateTime?;
  String get themeMode => state['themeMode'] as String? ?? 'system';
  double get taxRate => (state['taxRate'] as num?)?.toDouble() ?? 0.0;
  String get language => state['language'] as String? ?? 'en';

  Future<void> updateLanguage(String lang) async {
    state = {...state, 'language': lang};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang);
  }

  String get downloadDirectory => state['downloadDirectory'] as String? ?? '';

  Future<void> updateDownloadDirectory(String path) async {
    state = {...state, 'downloadDirectory': path};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownloadDir, path);
  }
}
