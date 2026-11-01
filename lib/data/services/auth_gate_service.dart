import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_channel.dart';

part 'auth_gate_service.g.dart';

enum BiometricKind {

  faceId,

  touchId,

  other,
}

class AuthGateService {

  AuthGateService({LocalAuthentication? localAuth, DeviceChannel? device})
      : _auth = localAuth ?? LocalAuthentication(),
        _device = device ?? const DeviceChannel();

  static const _keyPinHash = 'authGate.pinHash';
  static const _keyPinSalt = 'authGate.pinSalt';

  final LocalAuthentication _auth;
  final DeviceChannel _device;

  Future<bool> isBiometricAvailable() async =>
      (await _enrolledBiometrics()).isNotEmpty;

  Future<({bool available, BiometricKind kind})> biometrics() async {
    final enrolled = await _enrolledBiometrics();
    return (available: enrolled.isNotEmpty, kind: await _kindOf(enrolled));
  }

  Future<List<BiometricType>> _enrolledBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return const [];
      return await _auth.getAvailableBiometrics();
    } on LocalAuthException {
      return const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<BiometricKind> _kindOf(List<BiometricType> enrolled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return BiometricKind.other;
    }
    if (enrolled.contains(BiometricType.face)) return BiometricKind.faceId;
    if (enrolled.contains(BiometricType.fingerprint)) {
      return BiometricKind.touchId;
    }
    return switch (await _device.biometryHardware()) {
      BiometryHardware.faceId => BiometricKind.faceId,
      BiometryHardware.touchId => BiometricKind.touchId,
      BiometryHardware.none || BiometryHardware.unknown => BiometricKind.other,
    };
  }

  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,

        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

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

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    final salt = prefs.getString(_keyPinSalt);
    if (stored == null || salt == null) return false;
    final candidate = _hash(pin, salt);

    return candidate == stored;
  }

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

    final ts = DateTime.now().microsecondsSinceEpoch;
    final id = identityHashCode(this);
    return '$ts.$id';
  }
}

@Riverpod(keepAlive: true)
AuthGateService authGateService(Ref ref) =>
    AuthGateService(device: ref.watch(deviceChannelProvider));
