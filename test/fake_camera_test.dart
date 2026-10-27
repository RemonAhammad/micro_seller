// FakeCamera (test/support/fake_camera.dart), which the scanner tests put in
// place of the device's camera: it drives mobile_scanner's real controller as
// a phone does (a refused or missing camera, the flashlight and its stream, a
// scanned code) and counts what was asked of it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'support/fake_camera.dart';

void main() {
  tearDown(MobileScannerController.resetPlatformSessionOwner);

  /// A scanner on screen whose camera is [camera], not yet started.
  Future<MobileScannerController> scanner(
      WidgetTester tester, FakeCamera camera) async {
    MobileScannerPlatform.instance = camera;
    final controller = MobileScannerController(autoStart: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: MobileScanner(controller: controller)),
    );
    return controller;
  }

  testWidgets('starts, follows the flashlight, scans and stops',
      (tester) async {
    final camera = FakeCamera();
    final controller = await scanner(tester, camera);
    await controller.start();
    expect(camera.starts, 1);
    expect(controller.value.isRunning, isTrue);
    expect(controller.value.torchState, TorchState.off);

    await controller.toggleTorch();
    await tester.pump();
    expect(camera.toggles, 1);
    expect(controller.value.torchState, TorchState.on);
    camera.torch = TorchState.off;
    await tester.pump();
    expect(controller.value.torchState, TorchState.off);

    final scanned = controller.barcodes.first;
    camera.scan('0036000291452');
    expect((await scanned).barcodes.single.rawValue, '0036000291452');

    await controller.stop();
    expect(camera.stops, 1);
    expect(controller.value.isRunning, isFalse);
  });

  testWidgets('a refused camera fails to start until it is allowed',
      (tester) async {
    final camera = FakeCamera(startError: FakeCamera.refused);
    final controller = await scanner(tester, camera);
    await controller.start();
    expect(camera.starts, 1);
    expect(controller.value.isRunning, isFalse);
    expect(controller.value.error?.errorCode,
        MobileScannerErrorCode.permissionDenied);
    expect(controller.value.torchState, TorchState.unavailable);

    camera.startError = null;
    await controller.start();
    expect(camera.starts, 2);
    expect(controller.value.isRunning, isTrue);
    expect(controller.value.error, isNull);
  });

  testWidgets('no camera, and a camera that fails', (tester) async {
    for (final (error, code) in [
      (FakeCamera.noCamera, MobileScannerErrorCode.unsupported),
      (FakeCamera.broken, MobileScannerErrorCode.genericError),
    ]) {
      final controller = await scanner(tester, FakeCamera(startError: error));
      await controller.start();
      expect(controller.value.error?.errorCode, code);
      await tester.pumpWidget(const SizedBox());
      MobileScannerController.resetPlatformSessionOwner();
    }
  });

  testWidgets('without a flashlight, a switch is never asked for',
      (tester) async {
    final camera = FakeCamera(torch: TorchState.unavailable);
    final controller = await scanner(tester, camera);
    await controller.start();
    expect(controller.value.torchState, TorchState.unavailable);
    await controller.toggleTorch();
    expect(camera.toggles, 0);
  });

  testWidgets('a flashlight that fails to switch throws to the caller',
      (tester) async {
    final camera = FakeCamera()..toggleError = Exception('torch busy');
    final controller = await scanner(tester, camera);
    await controller.start();
    await expectLater(controller.toggleTorch(), throwsException);
    expect(camera.toggles, 1);
    expect(controller.value.torchState, TorchState.off);
  });
}
