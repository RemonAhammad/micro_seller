import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/sidebar_items.dart';
import '../../../core/theme/app_color_theme.dart';
import '../../../core/utils/currency_formatter.dart';

part 'settings_provider.g.dart';

typedef _PrimedSettings = ({
  String themeMode,
  String colorThemeId,
  String customColorThemes,
});

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

  static const _keyAutoBackupError = 'autoBackupError';

  static const keyColorThemeId = 'colorThemeId';

  static const keyCustomColorThemes = 'customColorThemes';

  static const sidebarPositionLeft = 'left';
  static const sidebarPositionRight = 'right';
  static const sidebarPositionBottom = 'bottom';

  static const _themeModes = {'light', 'dark', 'system'};
  static const _noCustomColorThemes = '[]';

  static _PrimedSettings? _primed;

  static void primeFrom(SharedPreferences prefs) {
    try {

      final customs = decodeCustomColorThemes(prefs.get(keyCustomColorThemes));
      _primed = (
        themeMode: _themeModeFrom(prefs.get(_keyThemeMode)),
        colorThemeId: _colorThemeIdFrom(prefs.get(keyColorThemeId), customs),
        customColorThemes: encodeCustomColorThemes(customs),
      );
    } catch (_) {
      _primed = null;
    }
  }

  @visibleForTesting
  static void debugResetPrimed() => _primed = null;

  static String get primedThemeMode => _primed?.themeMode ?? 'system';

  static AppColorTheme get primedColorTheme {
    final primed = _primed;
    if (primed == null) return kDefaultColorTheme;
    return resolveColorTheme(
      primed.colorThemeId,
      decodeCustomColorThemes(primed.customColorThemes),
    );
  }

  static void _remember(Map<String, dynamic> settings) {
    _primed = (
      themeMode: settings['themeMode'] as String? ?? 'system',
      colorThemeId:
          settings[keyColorThemeId] as String? ?? kDefaultColorThemeId,
      customColorThemes: settings[keyCustomColorThemes] as String? ??
          _noCustomColorThemes,
    );
  }

  static String _themeModeFrom(Object? raw) =>
      raw is String && _themeModes.contains(raw) ? raw : 'system';

  static String _colorThemeIdFrom(Object? raw, List<AppColorTheme> customs) =>
      raw is String ? resolveColorTheme(raw, customs).id : kDefaultColorThemeId;

  @override
  Map<String, dynamic> build() {
    _loadFromDisk();
    final primed = _primed;
    return {
      'shopName': 'My Shop',
      'shopPhone': '',
      'currencySymbol': '\$',
      'lowStockThreshold': 10,
      'lastBackupTime': null,
      'themeMode': primed?.themeMode ?? 'system',
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
      'colorThemeId': primed?.colorThemeId ?? kDefaultColorThemeId,
      'customColorThemes': primed?.customColorThemes ?? _noCustomColorThemes,
    };
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = _readState(prefs);
    CurrencyFormatter.setSymbol(loaded['currencySymbol'] as String);
    _remember(loaded);
    state = loaded;
  }

  static Map<String, dynamic> _readState(SharedPreferences prefs) {

    String text(String key, String fallback) {
      final value = prefs.get(key);
      return value is String ? value : fallback;
    }

    bool flag(String key, bool fallback) {
      final value = prefs.get(key);
      return value is bool ? value : fallback;
    }

    final orderRaw = prefs.get(_keySidebarOrder);
    List<String> order = List<String>.from(defaultSidebarOrder);
    if (orderRaw is String && orderRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(orderRaw);
        if (decoded is List) {
          order = reconcileSidebarOrder(decoded.map((e) => e.toString()).toList());
        }
      } catch (_) {

      }
    }

    final hiddenRaw = prefs.get(_keyHiddenSidebarItems);
    List<String> hidden = const [];
    if (hiddenRaw is String && hiddenRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(hiddenRaw);
        if (decoded is List) {
          hidden = decoded
              .map((e) => e.toString())
              .where((k) => k != 'settings')
              .toList();
        }
      } catch (_) {}
    }

    final threshold = prefs.get(_keyThreshold);
    final lastBackup = prefs.get(_keyLastBackup);
    final taxRate = prefs.get(_keyTaxRate);
    final position = prefs.get(_keySidebarPosition);
    final autoBackupError = prefs.get(_keyAutoBackupError);
    final customs = decodeCustomColorThemes(prefs.get(keyCustomColorThemes));

    return {
      'shopName': text(_keyShopName, 'My Shop'),
      'shopPhone': text(_keyShopPhone, ''),
      'currencySymbol': text(_keyCurrency, '\$'),
      'lowStockThreshold': threshold is int ? threshold : 10,
      'lastBackupTime':
          lastBackup is String ? DateTime.tryParse(lastBackup) : null,
      'themeMode': _themeModeFrom(prefs.get(_keyThemeMode)),
      'taxRate': taxRate is num ? taxRate.toDouble() : 0.0,
      'language': text(_keyLanguage, 'en'),
      'downloadDirectory': text(_keyDownloadDir, ''),
      'sidebarOrder': order,
      'sidebarPosition': position == sidebarPositionRight
          ? sidebarPositionRight
          : position == sidebarPositionBottom
              ? sidebarPositionBottom
              : sidebarPositionLeft,
      'hiddenSidebarItems': hidden,
      'autoBackup': flag(_keyAutoBackup, false),
      'securityFingerprintEnabled': flag(_keySecurityFingerprint, true),
      'securityPinEnabled': flag(_keySecurityPin, true),
      'autoBackupError': autoBackupError is String ? autoBackupError : null,
      'colorThemeId': _colorThemeIdFrom(prefs.get(keyColorThemeId), customs),
      'customColorThemes': encodeCustomColorThemes(customs),
    };
  }

  Future<void> updateShopName(String name) async {
    state = {...state, 'shopName': name};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopName, name);
  }

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
    _remember(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<void> updateColorTheme(String id) async {
    final selected = _colorThemeIdFrom(id, customColorThemes);
    state = {...state, keyColorThemeId: selected};
    _remember(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyColorThemeId, selected);
  }

  Future<void> saveCustomColorTheme(AppColorTheme theme) async {

    final saved = AppColorTheme.fromJson(theme.toJson());
    if (saved == null || !saved.isCustom) {
      throw ArgumentError.value(theme.id, 'theme', 'Not a custom color theme');
    }
    final themes = List<AppColorTheme>.of(customColorThemes);
    final index = themes.indexWhere((t) => t.id == saved.id);
    if (index >= 0) {
      themes[index] = saved;
    } else if (themes.length >= kMaxCustomColorThemes) {
      throw StateError(
          'At most $kMaxCustomColorThemes custom color themes can be saved');
    } else {
      themes.add(saved);
    }
    final json = encodeCustomColorThemes(themes);
    state = {...state, keyCustomColorThemes: json};
    _remember(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCustomColorThemes, json);
  }

  Future<void> deleteCustomColorTheme(String id) async {
    final themes = customColorThemes.where((t) => t.id != id).toList();
    if (themes.length == customColorThemes.length) return;
    final json = encodeCustomColorThemes(themes);
    final wasSelected = colorThemeId == id;
    state = {
      ...state,
      keyCustomColorThemes: json,
      if (wasSelected) keyColorThemeId: kDefaultColorThemeId,
    };
    _remember(state);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(keyCustomColorThemes, json),
      if (wasSelected) prefs.setString(keyColorThemeId, kDefaultColorThemeId),
    ]);
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
        : position == sidebarPositionBottom
            ? sidebarPositionBottom
            : sidebarPositionLeft;
    state = {...state, 'sidebarPosition': normalised};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySidebarPosition, normalised);
  }

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

  String get colorThemeId =>
      state[keyColorThemeId] as String? ?? kDefaultColorThemeId;

  List<AppColorTheme> get customColorThemes {
    final json =
        state[keyCustomColorThemes] as String? ?? _noCustomColorThemes;
    if (json != _customThemesJson) {
      _customThemes = List.unmodifiable(decodeCustomColorThemes(json));
      _customThemesJson = json;
    }
    return _customThemes;
  }

  String? _customThemesJson;
  List<AppColorTheme> _customThemes = const [];

  AppColorTheme get activeColorTheme =>
      resolveColorTheme(colorThemeId, customColorThemes);

  Future<void> refreshAutoBackupError() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.reload();
    final error = prefs.getString(_keyAutoBackupError);

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

  Map<String, dynamic> exportSettings() => _export(state);

  static Map<String, dynamic> exportFromPrefs(SharedPreferences prefs) =>
      _export(_readState(prefs));

  static Map<String, dynamic> _export(Map<String, dynamic> settings) {
    return {
      'shopName': settings['shopName'] as String? ?? 'My Shop',
      'shopPhone': settings['shopPhone'] as String? ?? '',
      'currencySymbol': settings['currencySymbol'] as String? ?? '\$',
      'lowStockThreshold': settings['lowStockThreshold'] as int? ?? 10,
      'themeMode': settings['themeMode'] as String? ?? 'system',
      'taxRate': (settings['taxRate'] as num?)?.toDouble() ?? 0.0,
      'language': settings['language'] as String? ?? 'en',
      'downloadDirectory': settings['downloadDirectory'] as String? ?? '',
      'sidebarOrder': List<String>.from(
          settings['sidebarOrder'] as List? ?? defaultSidebarOrder),
      'sidebarPosition':
          settings['sidebarPosition'] as String? ?? sidebarPositionLeft,
      'hiddenSidebarItems': List<String>.from(
          settings['hiddenSidebarItems'] as List? ?? const []),
      'autoBackup': settings['autoBackup'] as bool? ?? false,
      'securityFingerprintEnabled':
          settings['securityFingerprintEnabled'] as bool? ?? true,
      'securityPinEnabled': settings['securityPinEnabled'] as bool? ?? true,
      keyColorThemeId:
          settings[keyColorThemeId] as String? ?? kDefaultColorThemeId,

      keyCustomColorThemes: [
        for (final theme
            in decodeCustomColorThemes(settings[keyCustomColorThemes]))
          theme.toJson(),
      ],
    };
  }

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
    if (theme is String && _themeModes.contains(theme)) {
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
        (position == sidebarPositionLeft || position == sidebarPositionRight ||
            position == sidebarPositionBottom)) {
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

      final list = hidden
          .map((e) => e.toString())
          .where((k) => k.isNotEmpty && k != 'settings')
          .toSet()
          .toList();
      changes['hiddenSidebarItems'] = list;
      writes.add(prefs.setString(_keyHiddenSidebarItems, jsonEncode(list)));
    }

    final customThemes =
        _importedCustomColorThemes(data[keyCustomColorThemes]);
    final themeId = data[keyColorThemeId];
    if (customThemes != null || themeId is String) {
      if (customThemes != null) {
        final json = encodeCustomColorThemes(customThemes);
        changes[keyCustomColorThemes] = json;
        writes.add(prefs.setString(keyCustomColorThemes, json));
      }
      final selected = _colorThemeIdFrom(
        themeId is String ? themeId : colorThemeId,
        customThemes ?? customColorThemes,
      );
      changes[keyColorThemeId] = selected;
      writes.add(prefs.setString(keyColorThemeId, selected));
    }

    await Future.wait(writes);
    if (changes.isNotEmpty) {
      state = {...state, ...changes};
      _remember(state);
    }
  }

  static List<AppColorTheme>? _importedCustomColorThemes(Object? raw) {
    var data = raw;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    return data is List ? decodeCustomColorThemes(data) : null;
  }
}
