/// The app's own platform channel, `micro_seller/device`: what the plugins
/// don't tell. Android answers in `DeviceChannel.kt` (registered by
/// `MainActivity.configureFlutterEngine`), iOS in `AppDelegate.swift`
/// (`didInitializeImplicitFlutterEngine`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_channel.g.dart';

/// Whether the app may use the camera.
enum CameraAccess {
  granted,

  /// iOS hasn't asked yet.
  notDetermined,

  /// Refused, and Android may ask again.
  denied,

  /// Refused for good: only the system's Settings can allow it. iOS never
  /// asks twice, so every refusal there is this. On Android it is also what
  /// a camera that was never asked for reports (Android can't tell the two
  /// apart), so read it after a refusal, not before the first ask.
  permanentlyDenied,

  /// A device policy (Screen Time, a profile) forbids it.
  restricted,

  /// Not known: no camera permission on this platform, or the check failed.
  unknown,
}

/// The biometric sensor the device has, enrolled or not.
enum BiometryHardware { faceId, touchId, none, unknown }

/// Talks to `micro_seller/device`. Never throws: a failed call or another
/// platform answers [CameraAccess.unknown], [BiometryHardware.unknown] or
/// false.
class DeviceChannel {
  const DeviceChannel();

  static const channel = MethodChannel('micro_seller/device');

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether the app may use the camera. Android and iOS only.
  Future<CameraAccess> cameraAccess() async {
    if (!_isMobile) return CameraAccess.unknown;
    return switch (await _invoke<String>('cameraStatus')) {
      'granted' => CameraAccess.granted,
      'notDetermined' => CameraAccess.notDetermined,
      'denied' => CameraAccess.denied,
      'permanentlyDenied' => CameraAccess.permanentlyDenied,
      'restricted' => CameraAccess.restricted,
      _ => CameraAccess.unknown,
    };
  }

  /// Opens this app's page in the system's Settings. False when it couldn't.
  Future<bool> openAppSettings() async {
    if (!_isMobile) return false;
    return await _invoke<bool>('openAppSettings') ?? false;
  }

  /// The biometric sensor, from iOS's `LAContext.biometryType`: known even
  /// when nothing is enrolled yet. Other platforms answer
  /// [BiometryHardware.unknown] without asking (Android can't tell a face
  /// from a fingerprint).
  Future<BiometryHardware> biometryHardware() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return BiometryHardware.unknown;
    }
    return switch (await _invoke<String>('biometryType')) {
      'face' => BiometryHardware.faceId,
      'touch' => BiometryHardware.touchId,
      'none' => BiometryHardware.none,
      _ => BiometryHardware.unknown,
    };
  }

  /// [method]'s answer, or null when the call failed, nothing answers it, or
  /// the answer isn't a [T].
  static Future<T?> _invoke<T extends Object>(String method) async {
    try {
      final answer = await channel.invokeMethod<Object?>(method);
      return answer is T ? answer : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// The device channel, overridden with a fake in tests.
@Riverpod(keepAlive: true)
DeviceChannel deviceChannel(Ref ref) => const DeviceChannel();

/// The photo picker (camera and gallery), overridden with a fake in tests.
@Riverpod(keepAlive: true)
ImagePicker imagePicker(Ref ref) => ImagePicker();
