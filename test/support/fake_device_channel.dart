import 'package:micro_seller/data/services/device_channel.dart';

/// The app's device channel without a device: answers [camera] and
/// [biometry], and counts what was asked. Override `deviceChannelProvider`
/// with it.
class FakeDeviceChannel implements DeviceChannel {
  FakeDeviceChannel({
    this.camera = CameraAccess.granted,
    this.biometry = BiometryHardware.unknown,
    this.settingsOpen = true,
    this.onOpenSettings,
  });

  /// What [cameraAccess] answers. Set it to change the answer, as allowing
  /// the camera in the system's Settings does.
  CameraAccess camera;

  /// What [biometryHardware] answers.
  BiometryHardware biometry;

  /// What [openAppSettings] answers: whether Settings opened.
  bool settingsOpen;

  /// Runs when Settings is opened, e.g. to allow the camera there.
  void Function()? onOpenSettings;

  /// How many times [cameraAccess] was asked.
  int cameraChecks = 0;

  /// How many times [openAppSettings] was called.
  int settingsOpens = 0;

  /// How many times [biometryHardware] was asked.
  int biometryChecks = 0;

  @override
  Future<CameraAccess> cameraAccess() async {
    cameraChecks++;
    return camera;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpens++;
    onOpenSettings?.call();
    return settingsOpen;
  }

  @override
  Future<BiometryHardware> biometryHardware() async {
    biometryChecks++;
    return biometry;
  }
}
