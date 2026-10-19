// Display size / Text size preferences: per-device, read synchronously before
// the first frame, never part of a backup.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/features/settings/providers/display_scale_provider.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _display = DisplayScale.keyDisplayPercent;
const _text = DisplayScale.keyTextPercent;

Future<SharedPreferences> _prefs(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DisplayScale.debugResetPrimed();
  });
  tearDown(DisplayScale.debugResetPrimed);

  group('primeFrom', () {
    test('the first read already has the saved sizes', () async {
      DisplayScale.primeFrom(await _prefs({_display: 90, _text: 115}));
      expect(_container().read(displayScaleProvider), (
        displayPercent: 90,
        textPercent: 115,
      ));
    });

    test('nothing saved: 100% and follow the phone', () async {
      DisplayScale.primeFrom(await _prefs({}));
      expect(_container().read(displayScaleProvider), (
        displayPercent: 100,
        textPercent: null,
      ));
    });

    test('never primed: the same defaults', () {
      expect(_container().read(displayScaleProvider), (
        displayPercent: 100,
        textPercent: null,
      ));
    });

    test('unusable values are normalised, never thrown', () async {
      // (stored, display size, text size)
      const cases = <(Object, int, int?)>[
        (37, 80, 80),
        (93, 95, 95),
        (200, 130, 130),
        (1.5, 80, 80),
        (112.4, 110, 110),
        (-20, 80, 80),
        (double.nan, 100, null),
        (double.infinity, 100, null),
        ('abc', 100, null),
        ('90', 100, null),
        (true, 100, null),
        (<String>['90'], 100, null),
      ];
      for (final (stored, display, text) in cases) {
        DisplayScale.debugResetPrimed();
        final prefs = await _prefs({_display: stored, _text: stored});
        DisplayScale.primeFrom(prefs);
        expect(_container().read(displayScaleProvider), (
          displayPercent: display,
          textPercent: text,
        ), reason: 'stored $stored');
      }
    });

    test(
      'a wrongly typed value would make getInt throw; primeFrom does not',
      () async {
        final prefs = await _prefs({_display: 'abc', _text: 1.5});
        expect(() => prefs.getInt(_display), throwsA(isA<TypeError>()));
        expect(() => prefs.getInt(_text), throwsA(isA<TypeError>()));
        DisplayScale.primeFrom(prefs);
        expect(_container().read(displayScaleProvider), (
          displayPercent: 100,
          textPercent: 80,
        ));
      },
    );

    test('normalise helpers', () {
      expect(DisplayScale.normaliseDisplayPercent(null), 100);
      expect(DisplayScale.normaliseDisplayPercent(118), 120);
      expect(
        DisplayScale.normaliseDisplayPercent(double.negativeInfinity),
        100,
      );
      expect(DisplayScale.normaliseTextPercent(null), isNull);
      expect(DisplayScale.normaliseTextPercent(77.5), 80);
      expect(DisplayScale.normaliseTextPercent(double.nan), isNull);
    });
  });

  group('setters', () {
    test('setDisplayPercent snaps, updates state first and persists', () async {
      final container = _container();
      final notifier = container.read(displayScaleProvider.notifier);

      final saving = notifier.setDisplayPercent(87);
      // State changes before the write lands.
      expect(container.read(displayScaleProvider).displayPercent, 85);
      await saving;

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(_display), 85);
      expect(prefs.containsKey(_text), isFalse);
      expect(container.read(displayScaleProvider), (
        displayPercent: 85,
        textPercent: null,
      ));

      await notifier.setDisplayPercent(500);
      expect(container.read(displayScaleProvider).displayPercent, 130);
      expect(prefs.get(_display), 130);
    });

    test('setTextPercent snaps and stores; null removes the key', () async {
      final container = _container();
      final notifier = container.read(displayScaleProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      await notifier.setTextPercent(112);
      expect(container.read(displayScaleProvider), (
        displayPercent: 100,
        textPercent: 110,
      ));
      expect(prefs.get(_text), 110);

      await notifier.setTextPercent(null);
      expect(container.read(displayScaleProvider), (
        displayPercent: 100,
        textPercent: null,
      ));
      expect(prefs.containsKey(_text), isFalse);
    });

    test('a rebuilt provider keeps the latest sizes', () async {
      final container = _container();
      await container.read(displayScaleProvider.notifier).setDisplayPercent(90);
      await container.read(displayScaleProvider.notifier).setTextPercent(120);

      container.invalidate(displayScaleProvider);
      expect(container.read(displayScaleProvider), (
        displayPercent: 90,
        textPercent: 120,
      ));
    });
  });

  group('backup', () {
    test('exportSettings carries neither size', () async {
      final container = _container();
      final settings = container.read(settingsProvider.notifier);
      // Let Settings finish its async load from disk.
      await Future<void>.delayed(Duration.zero);
      await container.read(displayScaleProvider.notifier).setDisplayPercent(90);
      await container.read(displayScaleProvider.notifier).setTextPercent(120);

      final exported = settings.exportSettings();
      expect(exported, isNot(contains(_display)));
      expect(exported, isNot(contains(_text)));
      expect(
        exported.keys.where((k) => k.toLowerCase().contains('scale')),
        isEmpty,
      );
    });

    test('importSettings leaves this device\'s sizes alone', () async {
      DisplayScale.primeFrom(await _prefs({_display: 105}));
      final container = _container();
      final settings = container.read(settingsProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(displayScaleProvider), (
        displayPercent: 105,
        textPercent: null,
      ));

      await settings.importSettings({
        _display: 90,
        _text: 120,
        'shopName': 'Imported Shop',
        'themeMode': 'dark',
        'lowStockThreshold': 3,
      });

      // The rest of the backup was applied ...
      expect(container.read(settingsProvider)['shopName'], 'Imported Shop');
      expect(container.read(settingsProvider)['themeMode'], 'dark');
      // ... but not to the sizes.
      expect(container.read(displayScaleProvider), (
        displayPercent: 105,
        textPercent: null,
      ));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(_display), 105);
      expect(prefs.containsKey(_text), isFalse);
    });
  });
}
