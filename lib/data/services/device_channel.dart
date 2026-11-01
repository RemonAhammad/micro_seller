

library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_channel.g.dart';

enum CameraAccess {
  granted,

  notDetermined,

  denied,

  permanentlyDenied,

  restricted,

  unknown,
}

enum BiometryHardware { faceId, touchId, none, unknown }

class DeviceChannel {
  const DeviceChannel();

  static const channel = MethodChannel('micro_seller/device');

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

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

  Future<bool> openAppSettings() async {
    if (!_isMobile) return false;
    return await _invoke<bool>('openAppSettings') ?? false;
  }

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

@Riverpod(keepAlive: true)
DeviceChannel deviceChannel(Ref ref) => const DeviceChannel();

@Riverpod(keepAlive: true)
ImagePicker imagePicker(Ref ref) => ImagePicker();
