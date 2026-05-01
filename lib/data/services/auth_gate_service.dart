import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gates destructive actions (Clear All Data, etc.) behind a biometric prompt
/// or, if the device has no biometrics enrolled, a 4-digit PIN.
///
/// Two-tier strategy:
///   1. Try biometric first (`canCheckBiometrics && hasEnrolled`). On success
///      — pass. On user cancel / failure — fall back to PIN.
///   2. PIN: a 4-digit numeric secret, stored as SHA-256(salt + pin) in
///      SharedPreferences. The hash is single-purpose (this gate); we are
///      not protecting against an attacker with full disk access — we're
///      protecting against an opportunist who picks up the unlocked phone.
///      The salt is per-install so two devices with the same PIN have
///      different stored hashes.
///
/// Use via [AuthGateService.runGate] which returns true if the user passed
/// the gate (biometric ok OR pin verified OR pin freshly set up).
class AuthGateService {
  AuthGateService();

  static const _keyPinHash = 'authGate.pinHash';
  static const _keyPinSalt = 'authGate.pinSalt';

  final LocalAuthentication _auth = LocalAuthentication();

  /// True if the device has biometrics that the user has enrolled. False if
  /// the OS doesn't support biometrics, the device has none enrolled, or the
  /// platform check throws (some manufacturers stub the API).
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Triggers the system biometric prompt with [reason] as the dialog message.
  /// Returns true on success, false on user-cancel or failure.
  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// True if a PIN has been set up on this device.
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Hashes [pin] together with the per-install salt and stores it.
  /// Generates a fresh salt on first call.
  Future<void> setPin(String pin) async {
    assert(pin.length == 4 && int.tryParse(pin) != null,
        'PIN must be 4 numeric digits');
    final prefs = await SharedPreferences.getInstance();
    var salt = prefs.getString(_keyPinSalt);
    if (salt == null || salt.isEmpty) {
      salt = _newSalt();
      await prefs.setString(_keyPinSalt, salt);
    }
    await prefs.setString(_keyPinHash, _hash(pin, salt));
  }

  /// Constant-ish-time compare of the hash of [pin] against the stored hash.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    final salt = prefs.getString(_keyPinSalt);
    if (stored == null || salt == null) return false;
    final candidate = _hash(pin, salt);
    // SHA-256 outputs are equal length so simple == is fine here; we don't
    // need true constant-time compare on 4-digit input space.
    return candidate == stored;
  }

  /// Wipe the PIN. Currently unused — kept for a future "Reset PIN" flow.
  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.remove(_keyPinSalt);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  String _newSalt() {
    // Combination of microsecond-precision time + identityHashCode is enough
    // entropy for the threat model (defeating rainbow-table reuse on the
    // installed device). Not a cryptographic random — that's overkill here.
    final ts = DateTime.now().microsecondsSinceEpoch;
    final id = identityHashCode(this);
    return '$ts.$id';
  }
}
