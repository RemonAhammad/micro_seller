// Where a share sheet points. On an iPad (and a Mac) the share sheet is a
// popover anchored to the control that was tapped; share_plus needs that
// control's rect in window coordinates, or the popover opens from the middle
// of the screen. shareOriginOf finds the rect, the Display size zoom
// included, and the services that share pass it on.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/utils/share_origin.dart';
import 'package:micro_seller/data/services/csv_export_service.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';
import 'package:micro_seller/shared/widgets/pdf_saved_sheet.dart';

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// path_provider's channel, for the temporary folder an export writes to.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// The system's save sheet, unable to open: the PDF goes to the share sheet.
class _FailingFilePicker extends FilePickerPlatform {
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
  }) async => throw PlatformException(code: 'save_file_error');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shareOriginOf', () {
    /// A button away from the middle of a phone-sized window, in an app
    /// zoomed to [displayPercent] as AppZoom zooms the real one.
    Future<void> pumpButton(
      WidgetTester tester,
      GlobalKey key, {
      int? displayPercent,
    }) async {
      tester.view.physicalSize = const Size(411 * 3, 914 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: displayPercent == null
              ? null
              : (context, child) =>
                    AppZoom(displayPercent: displayPercent, child: child!),
          home: Scaffold(
            appBar: AppBar(title: const Text('Statement')),
            body: Align(
              alignment: const Alignment(0.6, 0.5),
              child: OutlinedButton(
                key: key,
                onPressed: () {},
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is where the control is drawn at 125% Display size', (
      tester,
    ) async {
      final key = GlobalKey();
      await pumpButton(tester, key, displayPercent: 125);
      final origin = shareOriginOf(key.currentContext);
      expect(origin, tester.getRect(find.byKey(key)));
      // The zoom is in it: the button is drawn 1.25 times its own size, and
      // in window coordinates.
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      expect(origin!.width, moreOrLessEquals(box.size.width * 1.25));
      expect(origin.height, moreOrLessEquals(box.size.height * 1.25));
      expect(origin.right, lessThanOrEqualTo(411));
      expect(origin.bottom, lessThanOrEqualTo(914));
      expect(origin.left, greaterThan(411 / 2));
    });

    testWidgets('is where the control is without a zoom', (tester) async {
      final key = GlobalKey();
      await pumpButton(tester, key);
      final origin = shareOriginOf(key.currentContext);
      expect(origin, tester.getRect(find.byKey(key)));
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      expect(origin!.size, box.size);
    });

    testWidgets('is null without a laid-out box', (tester) async {
      expect(shareOriginOf(null), isNull);

      // A sliver isn't a box.
      final sliver = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(key: sliver, child: const Text('Row')),
            ],
          ),
        ),
      );
      expect(shareOriginOf(sliver.currentContext), isNull);

      // A control that is gone.
      final key = GlobalKey();
      await pumpButton(tester, key);
      final context = key.currentContext!;
      await tester.pumpWidget(const SizedBox());
      expect(context.mounted, isFalse);
      expect(shareOriginOf(context), isNull);
    });
  });

  group('the share sheet points at the control', () {
    const origin = Rect.fromLTWH(600, 40, 48, 44);

    /// What the share sheet was given.
    late List<Map<Object?, Object?>> shared;
    late Directory temp;

    setUp(() {
      shared = [];
      temp = Directory.systemTemp.createTempSync('share_origin_test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_shareChannel, (call) async {
        shared.add(call.arguments as Map<Object?, Object?>);
        return 'com.apple.UIKit.activity.CopyToPasteboard';
      });
      messenger.setMockMethodCallHandler(
        _pathChannel,
        (call) async =>
            call.method == 'getTemporaryDirectory' ? temp.path : null,
      );
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_shareChannel, null);
      messenger.setMockMethodCallHandler(_pathChannel, null);
      temp.deleteSync(recursive: true);
    });

    void expectOrigin(Map<Object?, Object?> arguments) {
      expect(arguments['originX'], origin.left);
      expect(arguments['originY'], origin.top);
      expect(arguments['originWidth'], origin.width);
      expect(arguments['originHeight'], origin.height);
    }

    test('a PDF the save sheet couldn\'t take', () async {
      FilePickerPlatform.instance = _FailingFilePicker();
      expect(
        await savePdfWithSystemSheet(
          fileName: 'ORD-0001_invoice.pdf',
          bytes: Uint8List.fromList('%PDF-1.4'.codeUnits),
          shareOrigin: origin,
        ),
        isTrue,
      );
      expectOrigin(shared.single);
    });

    test('a CSV export', () async {
      await CsvExportService().exportExpenses(const [], shareOrigin: origin);
      expectOrigin(shared.single);
      expect(shared.single['subject'], 'expenses_export');
    });

    test('no origin, no rect: the sheet opens as before', () async {
      await CsvExportService().exportExpenses(const []);
      expect(shared.single.containsKey('originX'), isFalse);
    });
  });
}
