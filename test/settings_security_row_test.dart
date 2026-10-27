// Settings → Security names the device's biometrics: Face ID or Touch ID on
// an iPhone or iPad, "Fingerprint" elsewhere (Android can't tell a face from
// a fingerprint). The device is asked once, not on every rebuild, and again
// when the app comes back to the front: the seller may have set up Face ID
// in the system's Settings meanwhile. The saved setting keeps its key,
// securityFingerprintEnabled, which backups carry.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/data/services/auth_gate_service.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import 'support/layout_harness.dart';

/// The device's biometrics: answers [answer], counting the asks, and passes
/// a biometric prompt.
class _FakeAuthGate extends AuthGateService {
  _FakeAuthGate(this.answer);

  ({bool available, BiometricKind kind}) answer;
  int asks = 0;
  final prompts = <String>[];

  @override
  Future<({bool available, BiometricKind kind})> biometrics() async {
    asks++;
    return answer;
  }

  @override
  Future<bool> isBiometricAvailable() async => answer.available;

  @override
  Future<bool> authenticateBiometric(String reason) async {
    prompts.add(reason);
    return true;
  }
}

/// Drive, signed out, without Google.
class _FakeDrive extends DriveService {
  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;
}

/// Settings with [auth] standing in for the device's biometrics. Returns a
/// context in it.
Future<BuildContext> _pumpSettings(
  WidgetTester tester,
  _FakeAuthGate auth,
) async {
  setLayoutScreen(tester, 411, height: 6000);
  addTearDown(tester.view.reset);
  await pumpLayoutApp(
    tester,
    SettingsScreen(driveService: _FakeDrive()),
    overrides: [
      authGateServiceProvider.overrideWithValue(auth),
      updateChannelProvider.overrideWithValue(
        const AsyncValue.data(UpdateChannel.none),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return tester.element(find.byType(SettingsScreen));
}

/// The biometric row: the Security row with a face or a fingerprint (its
/// texts and its switch, one node for a screen reader).
Finder get _row => find
    .ancestor(
      of: find.byWidgetPredicate(
        (w) =>
            w is ThinIcon &&
            (w.builder == tabler.FaceId.new ||
                w.builder == tabler.Fingerprint.new),
      ),
      matching: find.byType(MergeSemantics),
    )
    .first;

/// The biometric row's switch.
Switch _switch(WidgetTester tester) => tester.widget<Switch>(
  find.descendant(of: _row, matching: find.byType(Switch)),
);

/// The icon [builder] draws in the biometric row.
Finder _icon(ThinIconBuilder builder) => find.descendant(
  of: _row,
  matching: find.byWidgetPredicate(
    (w) => w is ThinIcon && w.builder == builder,
  ),
);

/// Steps the app to the background and back, as leaving for the system's
/// Settings does.
void _leaveAndComeBack(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  setUpAll(() {
    // Both Security rows shown, as by default; the biometric one first.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=true\nENABLE_PIN_GATE=true',
    );
    PackageInfo.setMockInitialValues(
      appName: 'Micro Seller',
      packageName: 'com.blackshadowsoftware.microseller',
      version: '1.0.11',
      buildNumber: '19',
      buildSignature: '',
    );
  });

  tearDownAll(dotenv.clean);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the biometric row is named as the device names it', () {
    for (final (kind, icon, title, description, notSetUp) in [
      (
        BiometricKind.faceId,
        tabler.FaceId.new as ThinIconBuilder,
        'securityFaceId',
        'securityFaceIdDesc',
        'faceIdNotSetUp',
      ),
      (
        BiometricKind.touchId,
        tabler.Fingerprint.new as ThinIconBuilder,
        'securityTouchId',
        'securityTouchIdDesc',
        'touchIdNotSetUp',
      ),
      (
        BiometricKind.other,
        tabler.Fingerprint.new as ThinIconBuilder,
        'securityFingerprint',
        'securityFingerprintDesc',
        'biometricNotAvailable',
      ),
    ]) {
      testWidgets('${kind.name}, set up and not', (tester) async {
        final auth = _FakeAuthGate((available: true, kind: kind));
        final s = AppStrings.of(await _pumpSettings(tester, auth));
        expect(
          find.descendant(of: _row, matching: find.text(s.tr(title))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _row, matching: find.text(s.tr(description))),
          findsOneWidget,
        );
        expect(_icon(icon), findsOneWidget);
        if (kind != BiometricKind.faceId) {
          expect(_icon(tabler.FaceId.new), findsNothing);
        }
        // On by default, and can be turned off.
        final on = _switch(tester);
        expect(on.value, isTrue);
        expect(on.onChanged, isNotNull);

        // Not set up on this device: says so, and can't be turned on.
        await tester.pumpWidget(const SizedBox());
        auth.answer = (available: false, kind: kind);
        await _pumpSettings(tester, auth);
        expect(
          find.descendant(of: _row, matching: find.text(s.tr(title))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _row, matching: find.text(s.tr(notSetUp))),
          findsOneWidget,
        );
        expect(_icon(icon), findsOneWidget);
        final off = _switch(tester);
        expect(off.value, isFalse);
        expect(off.onChanged, isNull);
      });
    }

    test('every app language has words for each kind', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        // Face ID isn't a fingerprint. (Touch ID may well be called one:
        // Arabic iOS calls it بصمة الإصبع.)
        expect(
          l10n.tr('securityFaceId'),
          isNot(l10n.tr('securityFingerprint')),
          reason: locale.languageCode,
        );
        for (final key in [
          'securityFaceId',
          'securityFaceIdDesc',
          'faceIdNotSetUp',
          'securityTouchId',
          'securityTouchIdDesc',
          'touchIdNotSetUp',
          'securityFingerprint',
          'securityFingerprintDesc',
          'biometricNotAvailable',
        ]) {
          final words = l10n.tr(key);
          expect(words, isNot(key), reason: '${locale.languageCode}: $key');
          expect(
            words.trim(),
            isNotEmpty,
            reason: '${locale.languageCode}: $key',
          );
        }
      }
    });
  });

  testWidgets('asks the device once, not on every rebuild', (tester) async {
    final auth = _FakeAuthGate((available: true, kind: BiometricKind.faceId));
    final context = await _pumpSettings(tester, auth);
    expect(auth.asks, 1);
    // Every setting change rebuilds Settings.
    final settings = ProviderScope.containerOf(
      context,
    ).read(settingsProvider.notifier);
    for (final name in ['Shop A', 'Shop B', 'Shop C']) {
      await settings.updateShopName(name);
      await tester.pumpAndSettle();
    }
    expect(find.text('Shop C'), findsOneWidget);
    expect(auth.asks, 1);
  });

  testWidgets('asks again when the app comes back to the front', (
    tester,
  ) async {
    final auth = _FakeAuthGate((available: false, kind: BiometricKind.faceId));
    final s = AppStrings.of(await _pumpSettings(tester, auth));
    expect(find.text(s.faceIdNotSetUp), findsOneWidget);

    // The seller sets up Face ID in the system's Settings, and comes back.
    auth.answer = (available: true, kind: BiometricKind.faceId);
    _leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(auth.asks, 2);
    expect(find.text(s.faceIdNotSetUp), findsNothing);
    expect(find.text(s.securityFaceIdDesc), findsOneWidget);
    expect(_switch(tester).onChanged, isNotNull);
  });

  testWidgets('turning it off asks Face ID itself, and keeps the setting key', (
    tester,
  ) async {
    final auth = _FakeAuthGate((available: true, kind: BiometricKind.faceId));
    final context = await _pumpSettings(tester, auth);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(auth.prompts, hasLength(1));
    expect(_switch(tester).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('securityFingerprintEnabled'), isFalse);
    expect(
      ProviderScope.containerOf(context)
          .read(settingsProvider.notifier)
          .exportSettings()['securityFingerprintEnabled'],
      isFalse,
    );
  });
}
