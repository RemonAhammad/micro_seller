// The security gate's biometric step under local_auth 3, which reports a
// cancel (Face ID's Cancel button included), a lockout or biometrics that
// aren't available as a LocalAuthException, not a PlatformException. Each
// must come back as "not passed" instead of escaping the gate and the screen
// that asked (Clear All Data, the Recycle Bin, the Security switches).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:micro_seller/data/services/auth_gate_service.dart';
import 'package:micro_seller/shared/widgets/auth_gate.dart';

/// A device with Face ID enrolled whose prompt ends with [error], or passes
/// when there is none.
class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({this.error, this.biometricsError});

  /// What the prompt throws.
  final Object? error;

  /// What asking for the enrolled biometrics throws.
  final Object? biometricsError;

  /// How many times the prompt was shown.
  int prompts = 0;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (biometricsError case final e?) throw e;
    return [BiometricType.face];
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
}
