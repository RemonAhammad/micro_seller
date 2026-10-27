import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The camera, without a camera, for `MobileScannerPlatform.instance`: starts
/// at once and shows a black preview, or fails to start with [startError].
/// Its flashlight is [torch], which the scanner's controller follows through
/// the torch stream, as on a phone. Counts what the app asked of it.
class FakeCamera extends MobileScannerPlatform {
  FakeCamera({this.startError, this._torch = TorchState.off});

  /// A [startError]: the camera permission was refused.
  static const refused = MobileScannerException(
    errorCode: MobileScannerErrorCode.permissionDenied,
  );

  /// A [startError]: the device has no camera.
  static const noCamera = MobileScannerException(
    errorCode: MobileScannerErrorCode.unsupported,
  );

  /// A [startError]: the camera failed to start.
  static const broken = MobileScannerException(
    errorCode: MobileScannerErrorCode.genericError,
  );

  /// What [start] throws, or null to start. The controller turns it into
  /// its `value.error` ([refused], [noCamera], [broken]).
  MobileScannerException? startError;

  /// What [toggleTorch] throws, or null to switch the flashlight.
  Object? toggleError;

  /// How many times the camera was asked to start (failed starts included).
  int starts = 0;

  /// How many times the camera was stopped.
  int stops = 0;

  /// How many times the flashlight was switched (failed switches included).
  int toggles = 0;

  TorchState _torch;
  final _torchStates = StreamController<TorchState>.broadcast();
  final _barcodes = StreamController<BarcodeCapture?>.broadcast();

  /// The flashlight: [TorchState.unavailable] on a device without one
  /// (iPads, some Androids).
  TorchState get torch => _torch;

  /// Changes the flashlight, telling a running controller as the platform
  /// does.
  set torch(TorchState state) {
    _torch = state;
    _torchStates.add(state);
  }

  /// A running camera reads a code whose text is [rawValue].
  void scan(String? rawValue) => _barcodes.add(
        BarcodeCapture(barcodes: [Barcode(rawValue: rawValue)]),
      );

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torchStates.stream;

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    if (startError case final error?) throw error;
    return MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: _torch,
      size: const Size(1080, 1920),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> toggleTorch() async {
    toggles++;
    if (toggleError case final error?) throw error;
    switch (_torch) {
      case TorchState.off:
        torch = TorchState.on;
      case TorchState.on:
        torch = TorchState.off;
      case TorchState.auto || TorchState.unavailable:
        break;
    }
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> setFocusPoint(Offset position) async {}

  // Kept open: one fake serves every test in a file, and the controller
  // disposes the platform when a scanner screen goes away.
  @override
  Future<void> dispose() async {}
}
