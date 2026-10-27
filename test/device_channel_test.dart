// The app's own channel, micro_seller/device: each answer the Android
// (DeviceChannel.kt) and iOS (AppDelegate.swift) sides give maps to its
// value, and a failed call, a missing handler or another platform gives
// "unknown" / false instead of an error.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:micro_seller/data/services/device_channel.dart';

import 'support/fake_device_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The calls the channel received.
  late List<String> calls;

  /// Answers each call with [answer], or throws it when it's an exception.
  void answer(Object? answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceChannel.channel, (call) async {
      calls.add(call.method);
      if (answer is Exception) throw answer;
      return answer;
    });
  }

  setUp(() => calls = []);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceChannel.channel, null);
  });

  const device = DeviceChannel();

  group('cameraAccess', () {
    const statuses = {
      'granted': CameraAccess.granted,
      'notDetermined': CameraAccess.notDetermined,
      'denied': CameraAccess.denied,
      'permanentlyDenied': CameraAccess.permanentlyDenied,
      'restricted': CameraAccess.restricted,
    };

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('${platform.name}: each status maps to its value', () async {
        debugDefaultTargetPlatformOverride = platform;
        for (final MapEntry(:key, :value) in statuses.entries) {
          answer(key);
          expect(await device.cameraAccess(), value, reason: key);
        }
        expect(calls, List.filled(statuses.length, 'cameraStatus'));
      });
    }

    test('an unknown or wrongly typed answer is unknown', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      for (final odd in ['authorized', '', null, 1, true]) {
        answer(odd);
        expect(await device.cameraAccess(), CameraAccess.unknown,
            reason: '$odd');
      }
    });

    test('a PlatformException is unknown', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer(PlatformException(code: 'boom'));
      expect(await device.cameraAccess(), CameraAccess.unknown);
      expect(calls, ['cameraStatus']);
    });

    test('no handler (MissingPluginException) is unknown', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await device.cameraAccess(), CameraAccess.unknown);
    });

    test('other platforms answer unknown without asking', () async {
      answer('granted');
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(await device.cameraAccess(), CameraAccess.unknown,
            reason: platform.name);
      }
      expect(calls, isEmpty);
    });
  });

  group('openAppSettings', () {
    test('passes on whether Settings opened', () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        answer(true);
        expect(await device.openAppSettings(), isTrue, reason: platform.name);
        answer(false);
        expect(await device.openAppSettings(), isFalse,
            reason: platform.name);
      }
      expect(calls, List.filled(4, 'openAppSettings'));
    });

    test('a failure, no handler or an odd answer is false', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer(PlatformException(code: 'boom'));
      expect(await device.openAppSettings(), isFalse);
      answer('yes');
      expect(await device.openAppSettings(), isFalse);
      answer(null);
      expect(await device.openAppSettings(), isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceChannel.channel, null);
      expect(await device.openAppSettings(), isFalse);
    });

    test('macOS answers false without asking', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      answer(true);
      expect(await device.openAppSettings(), isFalse);
      expect(calls, isEmpty);
    });
  });

  group('biometryHardware', () {
    test('iOS: each sensor maps to its value', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const sensors = {
        'face': BiometryHardware.faceId,
        'touch': BiometryHardware.touchId,
        'none': BiometryHardware.none,
        'unknown': BiometryHardware.unknown,
        'optic': BiometryHardware.unknown,
      };
      for (final MapEntry(:key, :value) in sensors.entries) {
        answer(key);
        expect(await device.biometryHardware(), value, reason: key);
      }
      expect(calls, List.filled(sensors.length, 'biometryType'));
    });

    test('iOS: a failure or no handler is unknown', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer(PlatformException(code: 'boom'));
      expect(await device.biometryHardware(), BiometryHardware.unknown);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceChannel.channel, null);
      expect(await device.biometryHardware(), BiometryHardware.unknown);
    });

    test('Android and the rest answer unknown without asking', () async {
      answer('face');
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(await device.biometryHardware(), BiometryHardware.unknown,
            reason: platform.name);
      }
      expect(calls, isEmpty);
    });
  });

  group('providers', () {
    test('the real channel and picker, kept alive', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(deviceChannelProvider), isA<DeviceChannel>());
      final picker = container.read(imagePickerProvider);
      expect(picker, isA<ImagePicker>());
      expect(container.read(imagePickerProvider), same(picker));
    });

    test('a fake stands in for the device', () async {
      final fake = FakeDeviceChannel(camera: CameraAccess.denied);
      final container = ProviderContainer(
        overrides: [deviceChannelProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final device = container.read(deviceChannelProvider);
      expect(await device.cameraAccess(), CameraAccess.denied);
      fake.onOpenSettings = () => fake.camera = CameraAccess.granted;
      expect(await device.openAppSettings(), isTrue);
      expect(await device.cameraAccess(), CameraAccess.granted);
      expect(fake.cameraChecks, 2);
      expect(fake.settingsOpens, 1);
    });
  });
}
