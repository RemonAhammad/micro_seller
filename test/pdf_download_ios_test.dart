// "Download PDF" on iOS. A folder picked there can't be written to (the
// picker hands back a bare path, without the security-scoped access writing
// needs), so the order screens give the PDF to the system's save sheet
// (Files) each time instead, or to the share sheet, which can Save to Files
// too, when the save sheet can't open. Settings has no download folder on
// iOS (checked in drive_ios_test.dart). Elsewhere the folder picked once
// stays.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/shared/widgets/pdf_saved_sheet.dart';

/// The system's save sheet without a device: records what it was offered,
/// and saves (as [result]) or fails (with [error]).
class _FakeFilePicker extends FilePickerPlatform {
  final offered = <({String fileName, Uint8List bytes, String mimeType})>[];

  /// Where the file was saved; null when the sheet is cancelled.
  Uri? result;

  /// What the sheet fails with instead of opening.
  Object? error;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    offered.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
    if (error case final e?) throw e;
    return result;
  }
}

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFilePicker picker;

  /// What the share sheet was given.
  late List<Map<Object?, Object?>> shared;

  final pdf = Uint8List.fromList('%PDF-1.4 receipt'.codeUnits);

  setUp(() {
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
    shared = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          shared.add(call.arguments as Map<Object?, Object?>);
          // iOS names the activity the user picked.
          return 'com.apple.DocumentManagerUICore.SaveToFiles';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
  });

  test('asks where to save each time on iOS only', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(
        pdfDownloadAsksWhereToSave,
        platform == TargetPlatform.iOS,
        reason: platform.name,
      );
    }
  });

  test('offers the PDF in the save sheet, under its name', () async {
    picker.result = Uri.file('/private/var/mobile/ORD-0001_receipt.pdf');
    expect(
      await savePdfWithSystemSheet(
        fileName: 'ORD-0001_receipt.pdf',
        bytes: pdf,
      ),
      isTrue,
    );
    final offer = picker.offered.single;
    expect(offer.fileName, 'ORD-0001_receipt.pdf');
    expect(offer.bytes, pdf);
    expect(offer.mimeType, 'application/pdf');
    expect(shared, isEmpty);

    // Cancelled: nothing saved, and no share sheet either.
    picker.result = null;
    expect(
      await savePdfWithSystemSheet(
        fileName: 'ORD-0001_receipt.pdf',
        bytes: pdf,
      ),
      isFalse,
    );
    expect(shared, isEmpty);
  });

  test('when the save sheet fails, shares the PDF under its name', () async {
    picker.error = PlatformException(code: 'save_file_error');
    expect(
      await savePdfWithSystemSheet(
        fileName: 'ORD-0001_invoice.pdf',
        bytes: pdf,
      ),
      isTrue,
    );
    final share = shared.single;
    final path = (share['paths']! as List).single as String;
    addTearDown(() => File(path).parent.deleteSync(recursive: true));
    expect(path, endsWith('/ORD-0001_invoice.pdf'));
    expect(File(path).readAsBytesSync(), pdf);
    expect(share['mimeTypes'], ['application/pdf']);
  });
}
