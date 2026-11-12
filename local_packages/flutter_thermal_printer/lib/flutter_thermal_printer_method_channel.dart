import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_thermal_printer_platform_interface.dart';
import 'utils/printer.dart';

/// An implementation of [FlutterThermalPrinterPlatform] that uses method channels.
class MethodChannelFlutterThermalPrinter extends FlutterThermalPrinterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_thermal_printer');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<dynamic> startUsbScan() async =>
      methodChannel.invokeMethod('getUsbDevicesList');

  @override
  Future<bool> connect(Printer device) async =>
      await methodChannel.invokeMethod('connect', device.toJson());

  @override
  Future<bool> printText(
    Printer device,
    Uint8List data, {
    String? path,
  }) async =>
      await methodChannel.invokeMethod('printText', {
        'vendorId': device.vendorId.toString(),
        'productId': device.productId.toString(),
        'name': device.name,
        'data': List<int>.from(data),
        'path': path ?? '',
      });

  @override
  Future<bool> isConnected(Printer device) async =>
      await methodChannel.invokeMethod('isConnected', device.toJson());

  @override
  Future<dynamic> convertImageToGrayscale(Uint8List? value) async =>
      methodChannel.invokeMethod('convertimage', {
        'path': List<int>.from(value!),
      });

  @override
  Future<bool> disconnect(Printer device) async =>
      await methodChannel.invokeMethod('disconnect', {
        'vendorId': device.vendorId.toString(),
        'productId': device.productId.toString(),
      });
}
