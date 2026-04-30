import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/sidebar_items.dart';
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
  static const _keySidebarOrder = 'sidebarOrder';
  static const _keySidebarPosition = 'sidebarPosition';
  static const _keyHiddenSidebarItems = 'hiddenSidebarItems';

  /// 'left' (default) or 'right'.
  static const sidebarPositionLeft = 'left';
  static const sidebarPositionRight = 'right';

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
      'sidebarOrder': List<String>.from(defaultSidebarOrder),
      'sidebarPosition': sidebarPositionLeft,
      'hiddenSidebarItems': const <String>[],
    };
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = prefs.getString(_keyCurrency) ?? '\$';
    CurrencyFormatter.setSymbol(currency);

    // Sidebar order: stored as JSON-encoded list of keys.
    final orderRaw = prefs.getString(_keySidebarOrder);
    List<String> order = List<String>.from(defaultSidebarOrder);
    if (orderRaw != null && orderRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(orderRaw);
        if (decoded is List) {
          order = reconcileSidebarOrder(decoded.map((e) => e.toString()).toList());
        }
      } catch (_) {
        // Corrupt entry — fall back to default.
      }
    }

    // Hidden sidebar items: JSON-encoded list of keys. The user can never
    // hide the Settings tab — that would be a soft-lockout — so we always
    // strip it from the hidden list before storing or returning.
    final hiddenRaw = prefs.getString(_keyHiddenSidebarItems);
    List<String> hidden = const [];
    if (hiddenRaw != null && hiddenRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(hiddenRaw);
        if (decoded is List) {
          hidden = decoded
              .map((e) => e.toString())
              .where((k) => k != 'settings')
              .toList();
        }
      } catch (_) {/* fall back to empty */}
    }

    final position = prefs.getString(_keySidebarPosition);

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
      'sidebarOrder': order,
      'sidebarPosition': position == sidebarPositionRight
          ? sidebarPositionRight
          : sidebarPositionLeft,
      'hiddenSidebarItems': hidden,
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

  Future<void> updateSidebarOrder(List<String> order) async {
    final reconciled = reconcileSidebarOrder(order);
    state = {...state, 'sidebarOrder': reconciled};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySidebarOrder, jsonEncode(reconciled));
  }

  Future<void> resetSidebarOrder() async {
    await updateSidebarOrder(List<String>.from(defaultSidebarOrder));
  }

  Future<void> updateSidebarPosition(String position) async {
    final normalised = position == sidebarPositionRight
        ? sidebarPositionRight
        : sidebarPositionLeft;
    state = {...state, 'sidebarPosition': normalised};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySidebarPosition, normalised);
  }

  /// Toggle whether [key] is hidden from the sidebar. Settings tab is always
  /// visible (calling this with 'settings' is a no-op) so the user can never
  /// lock themselves out of the configuration UI.
  Future<void> toggleSidebarItemHidden(String key, bool hidden) async {
    if (key == 'settings') return;
    final current = List<String>.from(state['hiddenSidebarItems'] as List? ?? const []);
    final next = current.toSet();
    if (hidden) {
      next.add(key);
    } else {
      next.remove(key);
    }
    next.remove('settings');
    final list = next.toList();
    state = {...state, 'hiddenSidebarItems': list};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHiddenSidebarItems, jsonEncode(list));
  }

  String get shopName => state['shopName'] as String? ?? 'My Shop';
  String get currencySymbol => state['currencySymbol'] as String? ?? '\$';
  int get lowStockThreshold => state['lowStockThreshold'] as int? ?? 10;
  DateTime? get lastBackupTime => state['lastBackupTime'] as DateTime?;
  String get themeMode => state['themeMode'] as String? ?? 'system';
  double get taxRate => (state['taxRate'] as num?)?.toDouble() ?? 0.0;
  String get language => state['language'] as String? ?? 'en';
  List<String> get sidebarOrder =>
      List<String>.from(state['sidebarOrder'] as List? ?? defaultSidebarOrder);
  String get sidebarPosition =>
      state['sidebarPosition'] as String? ?? sidebarPositionLeft;
  List<String> get hiddenSidebarItems =>
      List<String>.from(state['hiddenSidebarItems'] as List? ?? const []);

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

  /// Serialise every persisted setting into a JSON-friendly map. Used by
  /// LocalBackupService / DriveService when building a backup. Excludes
  /// `lastBackupTime` (per-device, not portable) and the live in-memory
  /// only snapshot — only stable user preferences are exported.
  Map<String, dynamic> exportSettings() {
    return {
      'shopName': shopName,
      'currencySymbol': currencySymbol,
      'lowStockThreshold': lowStockThreshold,
      'themeMode': themeMode,
      'taxRate': taxRate,
      'language': language,
      'downloadDirectory': downloadDirectory,
      'sidebarOrder': sidebarOrder,
      'sidebarPosition': sidebarPosition,
      'hiddenSidebarItems': hiddenSidebarItems,
    };
  }

  /// Apply a previously-exported settings map (from a backup). Unknown keys
  /// are ignored; missing keys keep their current values. Each known key is
  /// validated and only applied if it parses correctly.
  Future<void> importSettings(Map<String, dynamic> data) async {
    final shopName = data['shopName'];
    if (shopName is String && shopName.isNotEmpty) {
      await updateShopName(shopName);
    }
    final currency = data['currencySymbol'];
    if (currency is String && currency.isNotEmpty) {
      await updateCurrencySymbol(currency);
    }
    final threshold = data['lowStockThreshold'];
    if (threshold is num) {
      await updateLowStockThreshold(threshold.toInt());
    }
    final theme = data['themeMode'];
    if (theme is String && const {'light', 'dark', 'system'}.contains(theme)) {
      await updateThemeMode(theme);
    }
    final taxRate = data['taxRate'];
    if (taxRate is num) {
      await updateTaxRate(taxRate.toDouble());
    }
    final language = data['language'];
    if (language is String && language.isNotEmpty) {
      await updateLanguage(language);
    }
    final downloadDir = data['downloadDirectory'];
    if (downloadDir is String) {
      await updateDownloadDirectory(downloadDir);
    }
    final order = data['sidebarOrder'];
    if (order is List) {
      await updateSidebarOrder(order.map((e) => e.toString()).toList());
    }
    final position = data['sidebarPosition'];
    if (position is String &&
        (position == sidebarPositionLeft || position == sidebarPositionRight)) {
      await updateSidebarPosition(position);
    }
    final hidden = data['hiddenSidebarItems'];
    if (hidden is List) {
      // Reset & re-apply: clear current hidden set, then add each key from
      // backup. toggleSidebarItemHidden auto-strips 'settings'.
      final current = hiddenSidebarItems.toSet();
      for (final k in current) {
        await toggleSidebarItemHidden(k, false);
      }
      for (final raw in hidden) {
        final k = raw.toString();
        if (k.isNotEmpty) await toggleSidebarItemHidden(k, true);
      }
    }
  }
}
