// The security gate's biometric step under local_auth 3, which reports a
// cancel (Face ID's Cancel button included), a lockout or biometrics that
// aren't available as a LocalAuthException, not a PlatformException. Each
// must come back as "not passed" instead of escaping the gate and the screen
// that asked (Clear All Data, the Recycle Bin, the Security switches).
//
// Also the biometric's kind, which Settings → Security names: Face ID or
// Touch ID on iOS, even before one is set up; Android's own row elsewhere.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:micro_seller/data/services/auth_gate_service.dart';
import 'package:micro_seller/data/services/device_channel.dart';
import 'package:micro_seller/shared/widgets/auth_gate.dart';

import 'support/fake_device_channel.dart';

/// A device with [enrolled] biometrics (Face ID by default) whose prompt ends
/// with [error], or passes when there is none.
class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({
    this.error,
    this.biometricsError,
    this.enrolled = const [BiometricType.face],
    this.hasSensor = true,
    this.hasPasscode = true,
  });

  /// What the prompt throws.
  final Object? error;

  /// What asking for the enrolled biometrics throws.
  final Object? biometricsError;

  /// The biometrics set up on the device.
  final List<BiometricType> enrolled;

  /// Whether the device has a biometric sensor, set up or not.
  final bool hasSensor;

  /// Whether the device has a passcode: without one, iOS allows no
  /// biometrics.
  final bool hasPasscode;

  /// How many times the prompt was shown.
  int prompts = 0;

  @override
  Future<bool> get canCheckBiometrics async => hasSensor;

  @override
  Future<bool> isDeviceSupported() async => hasPasscode;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (biometricsError case final e?) throw e;
    return enrolled;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    if (error case final e?) throw e;
    return true;
  }
}

void main() {
  setUpAll(() {
    // Both gate paths built in, as by default.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=true\nENABLE_PIN_GATE=true',
    );
  });

  group('authenticateBiometric', () {
    test('a LocalAuthException of any kind is "not passed"', () async {
      for (final code in LocalAuthExceptionCode.values) {
        final auth = _FakeLocalAuth(
          error: LocalAuthException(code: code, description: code.name),
        );
        expect(
          await AuthGateService(localAuth: auth).authenticateBiometric('Clear'),
          isFalse,
          reason: code.name,
        );
        expect(auth.prompts, 1, reason: code.name);
      }
    });

    test('a PlatformException is "not passed", as before', () async {
      final auth = _FakeLocalAuth(
        error: PlatformException(code: 'NotAvailable'),
      );
      expect(
        await AuthGateService(localAuth: auth).authenticateBiometric('Clear'),
        isFalse,
      );
    });

    test('a recognised face passes', () async {
      expect(
        await AuthGateService(
          localAuth: _FakeLocalAuth(),
        ).authenticateBiometric('Clear'),
        isTrue,
      );
    });
  });

  test('biometrics that throw a LocalAuthException count as unavailable',
      () async {
    final service = AuthGateService(
      localAuth: _FakeLocalAuth(
        biometricsError: const LocalAuthException(
          code: LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
        ),
      ),
    );
    expect(await service.isBiometricAvailable(), isFalse);
  });

  testWidgets('cancelling Face ID cancels the gate, without an error', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      }),
    ));
    for (final code in [
      LocalAuthExceptionCode.userCanceled,
      LocalAuthExceptionCode.systemCanceled,
      LocalAuthExceptionCode.biometricLockout,
      LocalAuthExceptionCode.temporaryLockout,
    ]) {
      final auth = _FakeLocalAuth(error: LocalAuthException(code: code));
      final passed = await runAuthGate(
        context,
        reason: 'Clear All Data',
        fingerprintEnabled: true,
        pinEnabled: true,
        service: AuthGateService(localAuth: auth),
      );
      await tester.pumpAndSettle();
      expect(passed, isFalse, reason: code.name);
      expect(auth.prompts, 1, reason: code.name);
      expect(tester.takeException(), isNull, reason: code.name);
      // An explicit cancel is a cancel: no fall-through to the PIN.
      expect(find.byType(BottomSheet), findsNothing, reason: code.name);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('biometrics: whether it can authorize, and its kind', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    /// What [auth] and [device] tell on [platform].
    Future<({bool available, BiometricKind kind})> biometrics(
      TargetPlatform platform,
      _FakeLocalAuth auth,
      FakeDeviceChannel device,
    ) {
      debugDefaultTargetPlatformOverride = platform;
      return AuthGateService(localAuth: auth, device: device).biometrics();
    }

    test('iOS: Face ID set up is Face ID, without asking the sensor',
        () async {
      final device = FakeDeviceChannel(biometry: BiometryHardware.touchId);
      expect(
        await biometrics(TargetPlatform.iOS, _FakeLocalAuth(), device),
        (available: true, kind: BiometricKind.faceId),
      );
      expect(device.biometryChecks, 0);
    });

    test('iOS: Touch ID set up is Touch ID', () async {
      final device = FakeDeviceChannel();
      expect(
        await biometrics(
          TargetPlatform.iOS,
          _FakeLocalAuth(enrolled: const [BiometricType.fingerprint]),
          device,
        ),
        (available: true, kind: BiometricKind.touchId),
      );
      expect(device.biometryChecks, 0);
    });

    test('iOS: nothing set up names the sensor the device has', () async {
      const kinds = {
        BiometryHardware.faceId: BiometricKind.faceId,
        BiometryHardware.touchId: BiometricKind.touchId,
        BiometryHardware.none: BiometricKind.other,
        BiometryHardware.unknown: BiometricKind.other,
      };
      for (final MapEntry(key: sensor, value: kind) in kinds.entries) {
        final device = FakeDeviceChannel(biometry: sensor);
        expect(
          await biometrics(
            TargetPlatform.iOS,
            _FakeLocalAuth(enrolled: const []),
            device,
          ),
          (available: false, kind: kind),
          reason: sensor.name,
        );
        expect(device.biometryChecks, 1, reason: sensor.name);
      }
    });

    test('iOS: no passcode, no sensor or a failing check still names it',
        () async {
      final device = FakeDeviceChannel(biometry: BiometryHardware.faceId);
      for (final auth in [
        _FakeLocalAuth(hasPasscode: false),
        _FakeLocalAuth(hasSensor: false),
        _FakeLocalAuth(
          biometricsError: const LocalAuthException(
            code: LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
          ),
        ),
        _FakeLocalAuth(biometricsError: PlatformException(code: 'boom')),
      ]) {
        expect(
          await biometrics(TargetPlatform.iOS, auth, device),
          (available: false, kind: BiometricKind.faceId),
        );
      }
    });

    test('Android: always its own row, without asking the channel', () async {
      final device = FakeDeviceChannel(biometry: BiometryHardware.faceId);
      for (final enrolled in [
        const [BiometricType.strong],
        const [BiometricType.weak, BiometricType.strong],
        const [BiometricType.face],
        const [BiometricType.fingerprint],
      ]) {
        expect(
          await biometrics(
            TargetPlatform.android,
            _FakeLocalAuth(enrolled: enrolled),
            device,
          ),
          (available: true, kind: BiometricKind.other),
          reason: '$enrolled',
        );
      }
      expect(
        await biometrics(
          TargetPlatform.android,
          _FakeLocalAuth(enrolled: const []),
          device,
        ),
        (available: false, kind: BiometricKind.other),
      );
      expect(device.biometryChecks, 0);
    });

    test('the gate asks only what is set up, never the sensor', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final device = FakeDeviceChannel(biometry: BiometryHardware.faceId);
      expect(
        await AuthGateService(
          localAuth: _FakeLocalAuth(enrolled: const []),
          device: device,
        ).isBiometricAvailable(),
        isFalse,
      );
      expect(
        await AuthGateService(localAuth: _FakeLocalAuth(), device: device)
            .isBiometricAvailable(),
        isTrue,
      );
      expect(device.biometryChecks, 0);
    });

    test('local_auth missing on this platform is unavailable, not an error',
        () async {
      // No plugin answers local_auth's channel in a test, as on Linux.
      final service = AuthGateService(device: FakeDeviceChannel());
      expect(await service.isBiometricAvailable(), isFalse);
      expect(
        await service.biometrics(),
        (available: false, kind: BiometricKind.other),
      );
    });

    test('the provider is kept alive and asks the device channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final device = FakeDeviceChannel(biometry: BiometryHardware.faceId);
      final container = ProviderContainer(
        overrides: [deviceChannelProvider.overrideWithValue(device)],
      );
      addTearDown(container.dispose);
      final service = container.read(authGateServiceProvider);
      expect(container.read(authGateServiceProvider), same(service));
      // Nothing set up (no plugin answers here): the sensor names it.
      expect(
        await service.biometrics(),
        (available: false, kind: BiometricKind.faceId),
      );
      expect(device.biometryChecks, 1);
    });
  });
}
