// Color theme settings: primed before the first frame, persisted by each
// method, carried by the backup (and validated on the way back in), the
// auto-backup worker's export equal to the app's, Phone colors' system
// schemes, and the documents' brand color.
import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/theme/app_color_theme.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/theme/document_brand.dart';
import 'package:micro_seller/core/theme/dynamic_color_support.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = Settings.keyColorThemeId;
const _customs = Settings.keyCustomColorThemes;

const _sunny = AppColorTheme(
  id: 'custom-1',
  name: 'Sunny',
  seed: 0xFFFFFF00,
  onPrimary: OnColor.black,
);

const _navy = AppColorTheme(
  id: 'custom-2',
  name: 'Navy',
  seed: 0xFF000080,
  accent: 0xFFFFC107,
  style: ThemeStyle.muted,
  onPrimary: OnColor.white,
);

AppColorTheme _numbered(int i) => AppColorTheme(
  id: 'custom-${100 + i}',
  name: 'Theme $i',
  seed: 0xFF000000 + (i * 0x0B0D0F) % 0x1000000,
  onPrimary: OnColor.white,
);

Future<SharedPreferences> _prefs(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// The notifier once its load from disk has finished.
Future<Settings> _loaded(ProviderContainer container) async {
  final settings = container.read(settingsProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  return settings;
}

Map<String, Object?> _jsonRoundTrip(Map<String, dynamic> map) =>
    jsonDecode(jsonEncode(map)) as Map<String, Object?>;

/// The system palette Android hands out: 5 tonal palettes × 13 tones, as
/// signed 32-bit ARGB ints (an IntArray on the Kotlin side).
Int32List _systemPalette() {
  const tones = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100];
  const hues = [280.0, 250.0, 320.0, 280.0, 280.0];
  const saturations = [0.6, 0.3, 0.4, 0.05, 0.1];
  return Int32List.fromList([
    for (var p = 0; p < hues.length; p++)
      for (final tone in tones)
        HSLColor.fromAHSL(1, hues[p], saturations[p], tone / 100)
            .toColor()
            .toARGB32(),
  ]);
}

/// The palette's tone [tone] of its first (primary) palette.
Color _primaryTone(int tone) =>
    HSLColor.fromAHSL(1, 280, 0.6, tone / 100).toColor();

void _mockSystemPalette(Object? Function() answer) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(DynamicColorPlugin.channel, (call) async {
        expect(call.method, DynamicColorPlugin.methodName);
        return answer();
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Settings.debugResetPrimed();
    DynamicColorSupport.debugReset();
  });
  tearDown(() {
    Settings.debugResetPrimed();
    DynamicColorSupport.debugReset();
    DocumentBrand.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DynamicColorPlugin.channel, null);
  });

  group('primeFrom', () {
    test('the first read already has the saved theme', () async {
      Settings.primeFrom(await _prefs({
        'themeMode': 'dark',
        _id: 'custom-2',
        _customs: encodeCustomColorThemes([_sunny, _navy]),
      }));
      final container = _container();

      // Synchronously, before the load from disk can have finished.
      final first = container.read(settingsProvider);
      expect(first['themeMode'], 'dark');
      expect(first[_id], 'custom-2');
      expect(first[_customs], encodeCustomColorThemes([_sunny, _navy]));
      final settings = container.read(settingsProvider.notifier);
      expect(settings.activeColorTheme, _navy);
      expect(settings.customColorThemes, [_sunny, _navy]);
      expect(Settings.primedColorTheme, _navy);

      // The load reads the same values: no flash to another theme.
      await _loaded(container);
      final loaded = container.read(settingsProvider);
      expect(loaded['themeMode'], 'dark');
      expect(loaded[_id], 'custom-2');
      expect(loaded[_customs], first[_customs]);
    });

    test('nothing saved: system mode, Teal, no custom themes', () async {
      Settings.primeFrom(await _prefs({}));
      final container = _container();
      final first = container.read(settingsProvider);
      expect(first['themeMode'], 'system');
      expect(first[_id], kDefaultColorThemeId);
      expect(first[_customs], '[]');
      expect(Settings.primedColorTheme, kDefaultColorTheme);
      await _loaded(container);
    });

    test('never primed: the defaults until the load lands', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark', _id: 'blue'});
      final container = _container();
      final first = container.read(settingsProvider);
      expect(first['themeMode'], 'system');
      expect(first[_id], kDefaultColorThemeId);
      expect(Settings.primedColorTheme, kDefaultColorTheme);

      final settings = await _loaded(container);
      expect(settings.themeMode, 'dark');
      expect(settings.colorThemeId, 'blue');
    });

    test('presets and Phone colors are primed as saved', () async {
      for (final id in ['blue', 'mono', kPhoneColorThemeId]) {
        Settings.primeFrom(await _prefs({_id: id}));
        expect(Settings.primedColorTheme.id, id);
        expect(_container().read(settingsProvider)[_id], id);
        await Future<void>.delayed(Duration.zero);
      }
      expect(Settings.primedColorTheme, kPhoneColorTheme);
    });

    test('unusable values fall back, never thrown', () async {
      // (stored theme mode, stored id, stored custom themes) →
      // (theme mode, id, custom themes)
      final valid = encodeCustomColorThemes([_sunny]);
      final cases = <(Object?, Object?, Object?, String, String, String)>[
        (42, 7, 3.5, 'system', 'teal', '[]'),
        ('sepia', 'nope', 'not json', 'system', 'teal', '[]'),
        (true, true, true, 'system', 'teal', '[]'),
        (<String>['dark'], <String>['blue'], '{"id": "custom-1"}', 'system',
            'teal', '[]'),
        // A deleted custom theme selects Teal.
        ('light', 'custom-404', valid, 'light', 'teal', valid),
        // Only custom themes are kept: a preset id is not one.
        (
          'dark',
          'blue',
          jsonEncode([
            {'id': 'blue', 'seed': 0xFF1976D2, 'onPrimary': 'white'},
            _sunny.toJson(),
          ]),
          'dark',
          'blue',
          valid,
        ),
      ];
      for (final (mode, id, customs, wantMode, wantId, wantCustoms) in cases) {
        Settings.debugResetPrimed();
        final prefs = await _prefs({
          'themeMode': ?mode,
          _id: ?id,
          _customs: ?customs,
        });
        Settings.primeFrom(prefs);
        final first = _container().read(settingsProvider);
        final reason = 'stored ($mode, $id, $customs)';
        expect(first['themeMode'], wantMode, reason: reason);
        expect(first[_id], wantId, reason: reason);
        expect(first[_customs], wantCustoms, reason: reason);
      }
      await Future<void>.delayed(Duration.zero);
    });

    test('a wrongly typed value would make getString throw; primeFrom and '
        'the load do not', () async {
      final prefs = await _prefs({
        'themeMode': 1,
        _id: 2,
        _customs: false,
        'shopName': 3,
        'lowStockThreshold': 'ten',
        'taxRate': 'high',
        'autoBackup': 'yes',
        'sidebarOrder': 4,
        'hiddenSidebarItems': 5,
        'lastBackupTime': 6,
        'autoBackupError': 7,
      });
      expect(() => prefs.getString('themeMode'), throwsA(isA<TypeError>()));
      expect(() => prefs.getString(_id), throwsA(isA<TypeError>()));
      Settings.primeFrom(prefs);
      expect(Settings.primedColorTheme, kDefaultColorTheme);

      final settings = await _loaded(_container());
      expect(settings.themeMode, 'system');
      expect(settings.colorThemeId, kDefaultColorThemeId);
      expect(settings.customColorThemes, isEmpty);
      expect(settings.shopName, 'My Shop');
      expect(settings.lowStockThreshold, 10);
      expect(settings.taxRate, 0.0);
      expect(settings.autoBackup, isFalse);
      expect(settings.sidebarOrder, defaultSidebarOrder);
      expect(settings.hiddenSidebarItems, isEmpty);
      expect(settings.lastBackupTime, isNull);
      expect(settings.autoBackupError, isNull);
    });

    test('debugResetPrimed forgets the snapshot', () async {
      Settings.primeFrom(await _prefs({_id: 'green', 'themeMode': 'dark'}));
      expect(Settings.primedColorTheme.id, 'green');
      Settings.debugResetPrimed();
      expect(Settings.primedColorTheme, kDefaultColorTheme);
      expect(_container().read(settingsProvider)['themeMode'], 'system');
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('methods persist', () {
    test('updateColorTheme selects presets, Phone colors and saved themes; '
        'anything else is Teal', () async {
      final container = _container();
      final settings = await _loaded(container);
      final prefs = await SharedPreferences.getInstance();

      final saving = settings.updateColorTheme('purple');
      // State changes before the write lands.
      expect(container.read(settingsProvider)[_id], 'purple');
      await saving;
      expect(prefs.getString(_id), 'purple');
      expect(settings.activeColorTheme.id, 'purple');

      await settings.updateColorTheme(kPhoneColorThemeId);
      expect(settings.colorThemeId, kPhoneColorThemeId);
      expect(prefs.getString(_id), kPhoneColorThemeId);

      // Not saved (yet): Teal.
      await settings.updateColorTheme(_sunny.id);
      expect(settings.colorThemeId, kDefaultColorThemeId);
      expect(prefs.getString(_id), kDefaultColorThemeId);

      await settings.saveCustomColorTheme(_sunny);
      await settings.updateColorTheme(_sunny.id);
      expect(settings.colorThemeId, _sunny.id);
      expect(settings.activeColorTheme, _sunny);
      expect(prefs.getString(_id), _sunny.id);

      for (final id in ['', 'nope', 'custom-', 'Teal']) {
        await settings.updateColorTheme(id);
        expect(settings.colorThemeId, kDefaultColorThemeId, reason: id);
      }
    });

    test('saveCustomColorTheme adds, replaces in place and does not select',
        () async {
      final container = _container();
      final settings = await _loaded(container);
      final prefs = await SharedPreferences.getInstance();

      await settings.saveCustomColorTheme(_sunny);
      await settings.saveCustomColorTheme(_navy);
      expect(settings.customColorThemes, [_sunny, _navy]);
      expect(settings.colorThemeId, kDefaultColorThemeId);
      expect(decodeCustomColorThemes(prefs.getString(_customs)),
          [_sunny, _navy]);
      expect(container.read(settingsProvider)[_customs],
          encodeCustomColorThemes([_sunny, _navy]));

      final renamed = _sunny.copyWith(name: 'Lemon', onPrimary: OnColor.white);
      await settings.saveCustomColorTheme(renamed);
      expect(settings.customColorThemes, [renamed, _navy]);
      expect(decodeCustomColorThemes(prefs.getString(_customs)),
          [renamed, _navy]);
    });

    test('saveCustomColorTheme stores the theme as a reload reads it',
        () async {
      final settings = await _loaded(_container());
      const translucent = AppColorTheme(
        id: 'custom-9',
        name: '  Spaced  ',
        seed: 0x80123456,
        accent: 0x00ABCDEF,
        onPrimary: OnColor.white,
      );
      await settings.saveCustomColorTheme(translucent);
      final saved = settings.customColorThemes.single;
      expect(saved.name, 'Spaced');
      expect(saved.seed, 0xFF123456);
      expect(saved.accent, 0xFFABCDEF);
      expect(saved, AppColorTheme.fromJson(translucent.toJson()));
    });

    test('saveCustomColorTheme rejects a theme that is not a custom one',
        () async {
      final settings = await _loaded(_container());
      for (final theme in [
        kDefaultColorTheme,
        kPhoneColorTheme,
        _sunny.copyWith(id: 'blue'),
        _sunny.copyWith(id: 'custom-'),
        _sunny.copyWith(id: 'mine'),
      ]) {
        await expectLater(
          settings.saveCustomColorTheme(theme),
          throwsArgumentError,
          reason: theme.id,
        );
      }
      expect(settings.customColorThemes, isEmpty);
    });

    test('at most 12 custom themes: the 13th throws a StateError', () async {
      final container = _container();
      final settings = await _loaded(container);
      final prefs = await SharedPreferences.getInstance();
      expect(kMaxCustomColorThemes, 12);

      final twelve = [for (var i = 0; i < 12; i++) _numbered(i)];
      for (final theme in twelve) {
        await settings.saveCustomColorTheme(theme);
      }
      expect(settings.customColorThemes, twelve);
      final stored = prefs.getString(_customs);

      await expectLater(
        settings.saveCustomColorTheme(_sunny),
        throwsA(isA<StateError>()),
      );
      expect(settings.customColorThemes, twelve);
      expect(prefs.getString(_customs), stored);

      // Replacing one is not adding one.
      final edited = twelve[5].copyWith(name: 'Edited');
      await settings.saveCustomColorTheme(edited);
      expect(settings.customColorThemes[5], edited);
      expect(settings.customColorThemes, hasLength(12));

      // Room again after a delete.
      await settings.deleteCustomColorTheme(twelve.first.id);
      await settings.saveCustomColorTheme(_sunny);
      expect(settings.customColorThemes.last, _sunny);
      expect(settings.customColorThemes, hasLength(12));
    });

    test('deleting the selected theme selects Teal', () async {
      final container = _container();
      final settings = await _loaded(container);
      final prefs = await SharedPreferences.getInstance();
      await settings.saveCustomColorTheme(_sunny);
      await settings.saveCustomColorTheme(_navy);
      await settings.updateColorTheme(_navy.id);

      await settings.deleteCustomColorTheme(_navy.id);
      expect(settings.customColorThemes, [_sunny]);
      expect(settings.colorThemeId, kDefaultColorThemeId);
      expect(settings.activeColorTheme, kDefaultColorTheme);
      expect(prefs.getString(_id), kDefaultColorThemeId);
      expect(decodeCustomColorThemes(prefs.getString(_customs)), [_sunny]);
      expect(Settings.primedColorTheme, kDefaultColorTheme);
    });

    test('deleting another theme keeps the selection', () async {
      final settings = await _loaded(_container());
      final prefs = await SharedPreferences.getInstance();
      await settings.saveCustomColorTheme(_sunny);
      await settings.saveCustomColorTheme(_navy);
      await settings.updateColorTheme(_sunny.id);

      await settings.deleteCustomColorTheme(_navy.id);
      expect(settings.customColorThemes, [_sunny]);
      expect(settings.colorThemeId, _sunny.id);
      expect(prefs.getString(_id), _sunny.id);
    });

    test('deleting an id that is not a saved theme changes nothing', () async {
      final container = _container();
      final settings = await _loaded(container);
      await settings.saveCustomColorTheme(_sunny);
      await settings.updateColorTheme('blue');
      final before = container.read(settingsProvider);

      for (final id in ['blue', 'custom-404', kPhoneColorThemeId]) {
        await settings.deleteCustomColorTheme(id);
      }
      expect(identical(container.read(settingsProvider), before), isTrue);
      expect(settings.colorThemeId, 'blue');
      expect(settings.customColorThemes, [_sunny]);
    });

    test('a rebuilt provider starts from the latest theme and mode', () async {
      final container = _container();
      final settings = await _loaded(container);
      await settings.saveCustomColorTheme(_navy);
      await settings.updateColorTheme(_navy.id);
      await settings.updateThemeMode('dark');
      expect(Settings.primedColorTheme, _navy);

      container.invalidate(settingsProvider);
      // Before its own load from disk finishes.
      final first = container.read(settingsProvider);
      expect(first['themeMode'], 'dark');
      expect(first[_id], _navy.id);
      expect(first[_customs], encodeCustomColorThemes([_navy]));
      await _loaded(container);
      expect(container.read(settingsProvider)[_id], _navy.id);
    });

    test('customColorThemes is decoded once per change and read-only',
        () async {
      final settings = await _loaded(_container());
      await settings.saveCustomColorTheme(_sunny);
      final themes = settings.customColorThemes;
      expect(identical(settings.customColorThemes, themes), isTrue);
      expect(() => themes.add(_navy), throwsUnsupportedError);
      await settings.saveCustomColorTheme(_navy);
      expect(settings.customColorThemes, [_sunny, _navy]);
    });
  });

  group('backup', () {
    test('exportSettings carries the theme, custom themes as JSON maps',
        () async {
      final settings = await _loaded(_container());
      await settings.saveCustomColorTheme(_sunny);
      await settings.saveCustomColorTheme(_navy);
      await settings.updateColorTheme(_sunny.id);

      final exported = settings.exportSettings();
      expect(exported[_id], _sunny.id);
      expect(exported[_customs], [_sunny.toJson(), _navy.toJson()]);
      // Survives the backup's JSON as is.
      expect(_jsonRoundTrip(exported), exported);
    });

    test('round trip: a backup restored on another phone brings the theme '
        'back', () async {
      final source = _container();
      final mine = await _loaded(source);
      await mine.saveCustomColorTheme(_sunny);
      await mine.saveCustomColorTheme(_navy);
      await mine.updateColorTheme(_navy.id);
      await mine.updateThemeMode('dark');
      await mine.updateShopPhone('+880 1712-345678');
      final backup = _jsonRoundTrip(mine.exportSettings());

      // The other phone has its own theme.
      final their = _numbered(7);
      SharedPreferences.setMockInitialValues({
        _id: their.id,
        _customs: encodeCustomColorThemes([their]),
      });
      Settings.debugResetPrimed();
      final target = ProviderContainer();
      addTearDown(target.dispose);
      final theirs = await _loaded(target);
      expect(theirs.activeColorTheme, their);

      await theirs.importSettings(Map<String, dynamic>.from(backup));
      expect(theirs.customColorThemes, [_sunny, _navy]);
      expect(theirs.colorThemeId, _navy.id);
      expect(theirs.activeColorTheme, _navy);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_id), _navy.id);
      expect(decodeCustomColorThemes(prefs.getString(_customs)),
          [_sunny, _navy]);
      // Everything else came back too, and the next backup is the same.
      expect(theirs.exportSettings(), mine.exportSettings());
      expect(Settings.exportFromPrefs(prefs), mine.exportSettings());
      // The next cold start is primed with it.
      expect(Settings.primedColorTheme, _navy);
      expect(target.read(settingsProvider)['themeMode'], 'dark');
    });

    test('an id the backup does not carry selects Teal', () async {
      final settings = await _loaded(_container());
      final prefs = await SharedPreferences.getInstance();
      final cases = <(Object?, List<Object?>, String)>[
        ('nope', [_sunny.toJson()], kDefaultColorThemeId),
        ('custom-404', [_sunny.toJson()], kDefaultColorThemeId),
        // A newer version's preset.
        ('lavender', [], kDefaultColorThemeId),
        ('', [], kDefaultColorThemeId),
        (_sunny.id, [_sunny.toJson()], _sunny.id),
        ('orange', [], 'orange'),
        (kPhoneColorThemeId, [], kPhoneColorThemeId),
      ];
      for (final (id, customs, want) in cases) {
        await settings.updateColorTheme('blue');
        await settings.importSettings({_id: id, _customs: customs});
        expect(settings.colorThemeId, want, reason: '$id');
        expect(prefs.getString(_id), want, reason: '$id');
      }
    });

    test('garbage custom themes: only the valid ones are kept', () async {
      final settings = await _loaded(_container());
      await settings.importSettings({
        _id: 'custom-3',
        _customs: [
          _sunny.toJson(),
          {'id': 'custom-3'}, // no main color
          'garbage',
          42,
          null,
          {'id': 'blue', 'seed': 0xFF1976D2, 'onPrimary': 'white'}, // a preset
          {..._sunny.toJson(), 'seed': 0xFF00FF00}, // a second custom-1
          _navy.toJson(),
          {'id': 'custom-5', 'seed': 'red'},
        ],
      });
      expect(settings.customColorThemes, [_sunny, _navy]);
      // custom-3 wasn't a valid theme.
      expect(settings.colorThemeId, kDefaultColorThemeId);
    });

    test('a backup with more than 12 custom themes keeps the first 12',
        () async {
      final settings = await _loaded(_container());
      final twenty = [for (var i = 0; i < 20; i++) _numbered(i)];
      await settings.importSettings({
        _id: twenty.last.id,
        _customs: [for (final theme in twenty) theme.toJson()],
      });
      expect(settings.customColorThemes, twenty.take(12));
      expect(settings.colorThemeId, kDefaultColorThemeId);
    });

    test('custom themes as JSON text are accepted', () async {
      final settings = await _loaded(_container());
      await settings.importSettings({
        _id: _navy.id,
        _customs: encodeCustomColorThemes([_navy]),
      });
      expect(settings.customColorThemes, [_navy]);
      expect(settings.colorThemeId, _navy.id);
    });

    test('custom themes that are not a list leave the saved ones alone',
        () async {
      final settings = await _loaded(_container());
      await settings.saveCustomColorTheme(_sunny);
      await settings.updateColorTheme(_sunny.id);
      for (final garbage in <Object?>[42, 'not json', '{"a": 1}', true, null]) {
        await settings.importSettings({_customs: garbage});
        expect(settings.customColorThemes, [_sunny], reason: '$garbage');
        expect(settings.colorThemeId, _sunny.id, reason: '$garbage');
      }
    });

    test('a backup from before color themes changes neither', () async {
      final container = _container();
      final settings = await _loaded(container);
      await settings.saveCustomColorTheme(_sunny);
      await settings.updateColorTheme(_sunny.id);
      final prefs = await SharedPreferences.getInstance();

      await settings.importSettings({'shopName': 'Old Shop', _id: 5});
      expect(settings.shopName, 'Old Shop');
      expect(settings.colorThemeId, _sunny.id);
      expect(settings.customColorThemes, [_sunny]);
      expect(prefs.getString(_id), _sunny.id);
    });

    test('custom themes without an id: the selection is checked against '
        'them', () async {
      final settings = await _loaded(_container());
      await settings.saveCustomColorTheme(_sunny);
      await settings.updateColorTheme(_sunny.id);

      // The selected theme survives when the backup carries it ...
      await settings.importSettings({
        _customs: [_navy.toJson(), _sunny.toJson()],
      });
      expect(settings.customColorThemes, [_navy, _sunny]);
      expect(settings.colorThemeId, _sunny.id);

      // ... and is Teal when it doesn't, as is an id of another type.
      await settings.importSettings({
        _id: 3,
        _customs: [_navy.toJson()],
      });
      expect(settings.customColorThemes, [_navy]);
      expect(settings.colorThemeId, kDefaultColorThemeId);
    });

    test('a preset selected locally stays selected when only custom themes '
        'are imported', () async {
      final settings = await _loaded(_container());
      await settings.updateColorTheme('red');
      await settings.importSettings({_customs: <Object?>[]});
      expect(settings.colorThemeId, 'red');
      expect(settings.customColorThemes, isEmpty);
    });
  });

  group('the auto-backup worker exports what the app exports', () {
    Future<void> expectParity(Map<String, Object> stored) async {
      Settings.debugResetPrimed();
      final prefs = await _prefs(stored);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = await _loaded(container);

      final worker = Settings.exportFromPrefs(prefs);
      expect(worker, settings.exportSettings(), reason: '$stored');
      expect(worker, contains('shopPhone'));
      expect(_jsonRoundTrip(worker), worker);
    }

    test('nothing saved', () => expectParity({}));

    test('everything saved, the shop phone too', () async {
      await expectParity({
        'shopName': 'Rahman Traders',
        'shopPhone': '+880 1712-345678',
        'currencySymbol': '৳',
        'lowStockThreshold': 3,
        'themeMode': 'dark',
        'taxRate': 7.5,
        'language': 'bn',
        'downloadDirectory': '/storage/emulated/0/Download',
        // An old order without the newer tabs, and Settings hidden.
        'sidebarOrder': jsonEncode(['orders', 'dashboard', 'products']),
        'sidebarPosition': 'right',
        'hiddenSidebarItems': jsonEncode(['reports', 'settings']),
        'autoBackup': true,
        'securityFingerprintEnabled': false,
        'securityPinEnabled': false,
        'lastBackupTime': '2026-10-19T12:30:00.000',
        'autoBackupError': 'revoked',
        _id: _navy.id,
        _customs: encodeCustomColorThemes([_sunny, _navy]),
      });
      final exported = Settings.exportFromPrefs(
          await SharedPreferences.getInstance());
      expect(exported['shopPhone'], '+880 1712-345678');
      expect(exported['sidebarOrder'],
          reconcileSidebarOrder(['orders', 'dashboard', 'products']));
      expect(exported['hiddenSidebarItems'], ['reports']);
      expect(exported[_id], _navy.id);
      expect(exported[_customs], [_sunny.toJson(), _navy.toJson()]);
      // Per-device values stay out of the backup.
      expect(exported, isNot(contains('lastBackupTime')));
      expect(exported, isNot(contains('autoBackupError')));
    });

    test('corrupt and unknown values', () => expectParity({
      'shopName': 1,
      'shopPhone': false,
      'currencySymbol': 2.5,
      'lowStockThreshold': '10',
      'themeMode': 'sepia',
      'taxRate': 'zero',
      'sidebarOrder': 'not json',
      'sidebarPosition': 'top',
      'hiddenSidebarItems': '{"a": 1}',
      'autoBackup': 'true',
      _id: 'custom-404',
      _customs: '[{"id": "custom-1"}, 42]',
    }));
  });

  group('Phone colors', () {
    test('no plugin answer: unavailable, nothing primed, Teal', () async {
      expect(DynamicColorSupport.isSupportedPlatform, isTrue);
      await DynamicColorSupport.prime();
      expect(DynamicColorSupport.primedScheme(Brightness.light), isNull);
      expect(DynamicColorSupport.primedScheme(Brightness.dark), isNull);
      expect(await _container().read(dynamicColorAvailableProvider.future),
          isFalse);

      final schemes = DynamicColorSupport.schemesFor(kPhoneColorTheme);
      expect(schemes.light, isNull);
      expect(schemes.dark, isNull);
      // Without a system scheme Phone colors is Teal, exactly.
      expect(
        identical(AppTheme.build(Brightness.light, kPhoneColorTheme),
            AppTheme.lightTheme),
        isTrue,
      );
      expect(
        identical(AppTheme.build(Brightness.dark, kPhoneColorTheme),
            AppTheme.darkTheme),
        isTrue,
      );
    });

    test('Android 12+: primed before the first frame, as the builder will '
        'convert it', () async {
      _mockSystemPalette(_systemPalette);
      await DynamicColorSupport.prime();
      final light = DynamicColorSupport.primedScheme(Brightness.light)!;
      final dark = DynamicColorSupport.primedScheme(Brightness.dark)!;
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.primary, _primaryTone(40));
      expect(light.onPrimary, _primaryTone(100));
      expect(dark.primary, _primaryTone(80));

      // DynamicColorBuilder's own answer gives equal schemes, so the theme
      // it builds is the one already drawn.
      final palette = await DynamicColorPlugin.getCorePalette();
      expect(palette!.toColorScheme(), light);
      expect(palette.toColorScheme(brightness: Brightness.dark), dark);
      expect(
        identical(
          AppTheme.build(Brightness.light, kPhoneColorTheme,
              dynamicScheme: palette.toColorScheme()),
          AppTheme.build(Brightness.light, kPhoneColorTheme,
              dynamicScheme: light),
        ),
        isTrue,
      );

      final primed = DynamicColorSupport.schemesFor(kPhoneColorTheme);
      expect(primed.light, light);
      expect(primed.dark, dark);
      expect(await _container().read(dynamicColorAvailableProvider.future),
          isTrue);
    });

    test('schemesFor: the builder wins over the primed schemes; only Phone '
        'colors uses them', () async {
      _mockSystemPalette(_systemPalette);
      await DynamicColorSupport.prime();
      final builderLight = ColorScheme.fromSeed(seedColor: Colors.orange);
      final builderDark = ColorScheme.fromSeed(
          seedColor: Colors.orange, brightness: Brightness.dark);

      final phone = DynamicColorSupport.schemesFor(kPhoneColorTheme,
          lightDynamic: builderLight, darkDynamic: builderDark);
      expect(phone.light, builderLight);
      expect(phone.dark, builderDark);

      for (final theme in [kDefaultColorTheme, _sunny, ...kPresetColorThemes]) {
        final schemes = DynamicColorSupport.schemesFor(theme,
            lightDynamic: builderLight, darkDynamic: builderDark);
        expect(schemes.light, isNull, reason: theme.id);
        expect(schemes.dark, isNull, reason: theme.id);
      }
    });

    test('Android before 12 answers with no palette', () async {
      _mockSystemPalette(() => null);
      await DynamicColorSupport.prime();
      expect(DynamicColorSupport.primedScheme(Brightness.light), isNull);
      expect(await _container().read(dynamicColorAvailableProvider.future),
          isFalse);
    });

    test('a failing plugin is unavailable, never thrown', () async {
      _mockSystemPalette(() => throw PlatformException(code: 'boom'));
      await DynamicColorSupport.prime();
      expect(DynamicColorSupport.primedScheme(Brightness.light), isNull);
      expect(await _container().read(dynamicColorAvailableProvider.future),
          isFalse);
    });

    test('a plugin that never answers is given up on', () async {
      _mockSystemPalette(() => Future<Object?>.delayed(
          const Duration(milliseconds: 200), _systemPalette));
      await DynamicColorSupport.prime(
          timeout: const Duration(milliseconds: 20));
      expect(DynamicColorSupport.primedScheme(Brightness.light), isNull);
      // Let the late answer land before the handler is removed.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(DynamicColorSupport.primedScheme(Brightness.light), isNull);
    });

    test('only Android: other platforms never ask', () async {
      var asked = false;
      _mockSystemPalette(() {
        asked = true;
        return _systemPalette();
      });
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(DynamicColorSupport.isSupportedPlatform, isFalse);
          await DynamicColorSupport.prime();
          expect(DynamicColorSupport.primedScheme(Brightness.light), isNull);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          expect(await container.read(dynamicColorAvailableProvider.future),
              isFalse);
          final builderLight = ColorScheme.fromSeed(seedColor: Colors.orange);
          final builderDark = ColorScheme.fromSeed(
              seedColor: Colors.orange, brightness: Brightness.dark);
          // A restored Phone colors theme stays Teal there.
          expect(
            DynamicColorSupport.schemesFor(kPhoneColorTheme,
                    lightDynamic: builderLight, darkDynamic: builderDark)
                .light,
            isNull,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
      expect(asked, isFalse);
    });
  });

  group('documents are branded with the light main color', () {
    test('Teal: #00897B with white text, as before themes', () {
      DocumentBrand.set(Colors.red, onColor: Colors.green);
      publishDocumentBrand(kDefaultColorTheme);
      expect(DocumentBrand.color, const Color(0xFF00897B));
      expect(DocumentBrand.onColor, Colors.white);
    });

    test("a custom theme's own White or Black choice, readable or not", () {
      publishDocumentBrand(_sunny);
      expect(DocumentBrand.color, const Color(0xFFFFFF00));
      expect(DocumentBrand.onColor, Colors.black);

      publishDocumentBrand(_sunny.copyWith(onPrimary: OnColor.white));
      expect(DocumentBrand.color, const Color(0xFFFFFF00));
      expect(DocumentBrand.onColor, Colors.white);
    });

    test("presets: the light pair, not the dark one", () {
      for (final preset in kPresetColorThemes) {
        publishDocumentBrand(preset);
        expect(DocumentBrand.color, preset.seedColor, reason: preset.id);
        expect(DocumentBrand.onColor, preset.onPrimary.color,
            reason: preset.id);
        // The same pair the light theme's buttons use.
        final scheme = AppTheme.build(Brightness.light, preset).colorScheme;
        expect(DocumentBrand.color, scheme.primary, reason: preset.id);
        expect(DocumentBrand.onColor, scheme.onPrimary, reason: preset.id);
      }
    });

    test('Phone colors: the system main color, text picked by contrast; '
        'Teal without one', () {
      publishDocumentBrand(kPhoneColorTheme);
      expect(DocumentBrand.color, const Color(0xFF00897B));
      expect(DocumentBrand.onColor, Colors.white);

      final system = ColorScheme.fromSeed(seedColor: const Color(0xFFFFEB3B))
          .copyWith(primary: const Color(0xFFFFEB3B));
      publishDocumentBrand(kPhoneColorTheme, lightDynamic: system);
      expect(DocumentBrand.color, const Color(0xFFFFEB3B));
      expect(DocumentBrand.onColor, Colors.black);

      // Only Phone colors uses a system scheme.
      publishDocumentBrand(_navy, lightDynamic: system);
      expect(DocumentBrand.color, const Color(0xFF000080));
      expect(DocumentBrand.onColor, Colors.white);
    });
  });
}
