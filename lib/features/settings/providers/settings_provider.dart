import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/sidebar_items.dart';
import '../../../core/utils/currency_formatter.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  static const _keyShopName = 'shopName';
  static const _keyShopPhone = 'shopPhone';
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
  static const _keyAutoBackup = 'autoBackup';
  static const _keySecurityFingerprint = 'securityFingerprintEnabled';
  static const _keySecurityPin = 'securityPinEnabled';
  // Set by the background worker (`auto_backup_runner.dart`) when Drive
  // access is revoked / silent sign-in returns null. Read by the Settings
  // UI to surface a "Sign in to resume" banner. Always cleared on a
  // successful backup.
  static const _keyAutoBackupError = 'autoBackupError';

  /// 'left' (default) or 'right'.
  static const sidebarPositionLeft = 'left';
  static const sidebarPositionRight = 'right';

  @override
  Map<String, dynamic> build() {
    _loadFromDisk();
    return {
      'shopName': 'My Shop',
      'shopPhone': '',
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
      'autoBackup': false,
      'securityFingerprintEnabled': true,
      'securityPinEnabled': true,
      'autoBackupError': null,
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
      'shopPhone': prefs.getString(_keyShopPhone) ?? '',
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
      'autoBackup': prefs.getBool(_keyAutoBackup) ?? false,
      'securityFingerprintEnabled':
          prefs.getBool(_keySecurityFingerprint) ?? true,
      'securityPinEnabled': prefs.getBool(_keySecurityPin) ?? true,
      'autoBackupError': prefs.getString(_keyAutoBackupError),
    };
  }

  Future<void> updateShopName(String name) async {
    state = {...state, 'shopName': name};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopName, name);
  }

  /// Contact number printed on the shared product catalog. Optional.
  Future<void> updateShopPhone(String phone) async {
    state = {...state, 'shopPhone': phone};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopPhone, phone);
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
  String get shopPhone => state['shopPhone'] as String? ?? '';
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
  bool get autoBackup => state['autoBackup'] as bool? ?? false;
  bool get securityFingerprintEnabled =>
      state['securityFingerprintEnabled'] as bool? ?? true;
  bool get securityPinEnabled =>
      state['securityPinEnabled'] as bool? ?? true;
  String? get autoBackupError => state['autoBackupError'] as String?;

  /// Re-read [_keyAutoBackupError] from disk into state. The key is written
  /// from the background isolate by `auto_backup_runner.dart`, so the
  /// foreground provider's in-memory state can be stale until we sync.
  Future<void> refreshAutoBackupError() async {
    final prefs = await SharedPreferences.getInstance();
    // The worker's isolate has its own prefs cache; without a reload this
    // isolate's cache never sees its write.
    await prefs.reload();
    final error = prefs.getString(_keyAutoBackupError);
    // Called on every app resume — don't rebuild watchers for no change.
    if (error != autoBackupError) {
      state = {...state, 'autoBackupError': error};
    }
  }

  Future<void> clearAutoBackupError() async {
    state = {...state, 'autoBackupError': null};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAutoBackupError);
  }

  Future<void> updateAutoBackup(bool enabled) async {
    state = {...state, 'autoBackup': enabled};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackup, enabled);
  }

  Future<void> updateSecurityFingerprintEnabled(bool enabled) async {
    state = {...state, 'securityFingerprintEnabled': enabled};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecurityFingerprint, enabled);
  }

  Future<void> updateSecurityPinEnabled(bool enabled) async {
    state = {...state, 'securityPinEnabled': enabled};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecurityPin, enabled);
  }

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
  /// only snapshot — only stable user preferences are exported. Display size
  /// and text size are per-device too: they live in `displayScaleProvider`
  /// and are not exported.
  Map<String, dynamic> exportSettings() {
    return {
      'shopName': shopName,
      'shopPhone': shopPhone,
      'currencySymbol': currencySymbol,
      'lowStockThreshold': lowStockThreshold,
      'themeMode': themeMode,
      'taxRate': taxRate,
      'language': language,
      'downloadDirectory': downloadDirectory,
      'sidebarOrder': sidebarOrder,
      'sidebarPosition': sidebarPosition,
      'hiddenSidebarItems': hiddenSidebarItems,
      'autoBackup': autoBackup,
      'securityFingerprintEnabled': securityFingerprintEnabled,
      'securityPinEnabled': securityPinEnabled,
    };
  }

  /// Apply a previously-exported settings map (from a backup). Unknown keys
  /// are ignored; missing keys keep their current values. Each known key is
  /// validated and only applied if it parses correctly.
  ///
  /// Persists every key, then assigns state once — each assignment rebuilds
  /// every settings watcher.
  Future<void> importSettings(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final changes = <String, dynamic>{};
    final writes = <Future<bool>>[];

    final shopName = data['shopName'];
    if (shopName is String && shopName.isNotEmpty) {
      changes['shopName'] = shopName;
      writes.add(prefs.setString(_keyShopName, shopName));
    }
    final shopPhone = data['shopPhone'];
    if (shopPhone is String) {
      changes['shopPhone'] = shopPhone;
      writes.add(prefs.setString(_keyShopPhone, shopPhone));
    }
    final currency = data['currencySymbol'];
    if (currency is String && currency.isNotEmpty) {
      CurrencyFormatter.setSymbol(currency);
      changes['currencySymbol'] = currency;
      writes.add(prefs.setString(_keyCurrency, currency));
    }
    final threshold = data['lowStockThreshold'];
    if (threshold is num) {
      changes['lowStockThreshold'] = threshold.toInt();
      writes.add(prefs.setInt(_keyThreshold, threshold.toInt()));
    }
    final theme = data['themeMode'];
    if (theme is String && const {'light', 'dark', 'system'}.contains(theme)) {
      changes['themeMode'] = theme;
      writes.add(prefs.setString(_keyThemeMode, theme));
    }
    final taxRate = data['taxRate'];
    if (taxRate is num) {
      changes['taxRate'] = taxRate.toDouble();
      writes.add(prefs.setDouble(_keyTaxRate, taxRate.toDouble()));
    }
    final language = data['language'];
    if (language is String && language.isNotEmpty) {
      changes['language'] = language;
      writes.add(prefs.setString(_keyLanguage, language));
    }
    final downloadDir = data['downloadDirectory'];
    if (downloadDir is String) {
      changes['downloadDirectory'] = downloadDir;
      writes.add(prefs.setString(_keyDownloadDir, downloadDir));
    }
    final order = data['sidebarOrder'];
    if (order is List) {
      final reconciled =
          reconcileSidebarOrder(order.map((e) => e.toString()).toList());
      changes['sidebarOrder'] = reconciled;
      writes.add(prefs.setString(_keySidebarOrder, jsonEncode(reconciled)));
    }
    final position = data['sidebarPosition'];
    if (position is String &&
        (position == sidebarPositionLeft || position == sidebarPositionRight)) {
      changes['sidebarPosition'] = position;
      writes.add(prefs.setString(_keySidebarPosition, position));
    }
    final autoBackup = data['autoBackup'];
    if (autoBackup is bool) {
      changes['autoBackup'] = autoBackup;
      writes.add(prefs.setBool(_keyAutoBackup, autoBackup));
    }
    final secFp = data['securityFingerprintEnabled'];
    if (secFp is bool) {
      changes['securityFingerprintEnabled'] = secFp;
      writes.add(prefs.setBool(_keySecurityFingerprint, secFp));
    }
    final secPin = data['securityPinEnabled'];
    if (secPin is bool) {
      changes['securityPinEnabled'] = secPin;
      writes.add(prefs.setBool(_keySecurityPin, secPin));
    }
    final hidden = data['hiddenSidebarItems'];
    if (hidden is List) {
      // Replaces the current hidden set. Settings can never be hidden
      // (soft-lockout), same as toggleSidebarItemHidden.
      final list = hidden
          .map((e) => e.toString())
          .where((k) => k.isNotEmpty && k != 'settings')
          .toSet()
          .toList();
      changes['hiddenSidebarItems'] = list;
      writes.add(prefs.setString(_keyHiddenSidebarItems, jsonEncode(list)));
    }

    await Future.wait(writes);
    if (changes.isNotEmpty) state = {...state, ...changes};
  }
}
