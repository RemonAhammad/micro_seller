// The camera of the two scanners (the Scanner tab and the product form's QR
// scanner) and of a product photo, when it can't run: the seller is told why
// in the app's language, with the button that fixes it, instead of the
// scanner plugin's English text on a black box. A refused camera is asked
// for again only when the screen opens or the seller taps Allow camera:
// Android's prompt pauses and resumes the app, so asking on resume would
// loop. Back from Settings with the camera allowed, it starts by itself. The
// flashlight button follows the camera, and is gone where there's none.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/data/services/device_channel.dart';
import 'package:micro_seller/features/categories/providers/category_provider.dart';
import 'package:micro_seller/features/products/presentation/product_form_screen.dart';
import 'package:micro_seller/features/scanner/presentation/scanner_screen.dart';
import 'package:micro_seller/shared/screens/qr_scanner_screen.dart';
import 'package:micro_seller/shared/widgets/scanner_camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import 'support/fake_camera.dart';
import 'support/fake_device_channel.dart';
import 'support/layout_harness.dart';

/// The photo picker, failing as the platform does: with [error].
class _FakePicker extends Fake implements ImagePicker {
  _FakePicker(this.error);

  final Object error;
  int picks = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    picks++;
    throw error;
  }
}

const _englishHint = 'Point the camera at a QR code or barcode';

/// The plugin's own error text, which the app's view replaces.
const _pluginText = 'Camera permission denied.';

Finder _icon(ThinIconBuilder builder) => find.byWidgetPredicate(
    (w) => w is ThinIcon && w.builder == builder,
    description: 'ThinIcon');

/// The camera's controller of the scanner on screen.
MobileScannerController _controllerOf(WidgetTester tester) =>
    tester.widget<MobileScanner>(find.byType(MobileScanner)).controller!;

/// The app goes to the background, as when the seller opens Settings:
/// inactive, hidden, paused.
void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// The app comes back to the foreground through the states it skipped:
/// hidden, inactive, resumed. Nothing when it is there.
void _foreground(WidgetTester tester) {
  final done = switch (tester.binding.lifecycleState) {
    AppLifecycleState.paused || AppLifecycleState.detached => 0,
    AppLifecycleState.hidden => 1,
    AppLifecycleState.inactive => 2,
    AppLifecycleState.resumed || null => 3,
  };
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ].skip(done)) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  late FakeCamera camera;
  late FakeDeviceChannel device;

  setUp(() {
    camera = FakeCamera();
    MobileScannerPlatform.instance = camera;
    device = FakeDeviceChannel();
  });

  tearDown(MobileScannerController.resetPlatformSessionOwner);

  /// The app's strings, in the language the app is shown in.
  dynamic strings(WidgetTester tester) =>
      AppStrings.of(tester.element(find.byType(Scaffold).first));

  /// Pumps [screen] (the Scanner tab unless given) and lets its camera start
  /// or fail.
  Future<void> pumpScanner(
    WidgetTester tester, {
    Widget screen = const ScannerScreen(),
    Locale? locale,
  }) async {
    await pumpLayoutApp(
      tester,
      screen,
      rail: false,
      locale: locale,
      overrides: [deviceChannelProvider.overrideWithValue(device)],
    );
    await tester.pump();
  }

  group('a refused camera', () {
    testWidgets('says so in the app\'s language, with Open Settings', (
      tester,
    ) async {
      // iOS never asks twice: only Settings can allow it.
      camera.startError = FakeCamera.refused;
      device.camera = CameraAccess.permanentlyDenied;
      await pumpScanner(tester, locale: const Locale('bn'));
      final s = strings(tester);

      expect(find.byType(ScannerErrorView), findsOneWidget);
      expect(find.text(s.cameraAccessOff), findsOneWidget);
      expect(find.text(s.cameraAllowInSettings), findsOneWidget);
      expect(find.text(s.allowCamera), findsNothing);
      // Not the plugin's English text and Material icon.
      expect(find.text(_pluginText), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(_icon(tabler.CameraOff.new), findsOneWidget);
      // No scanning frame or hint over it, and no flashlight.
      expect(find.text(s.pointCameraAtCode), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      await tester.tap(find.text(s.openSettings));
      await tester.pump();
      expect(device.settingsOpens, 1);
      // Nothing was asked again.
      expect(camera.starts, 1);
    });

    testWidgets('on Android, Allow camera asks again and starts it', (
      tester,
    ) async {
      // Android after a first "Deny": it may ask again.
      camera.startError = FakeCamera.refused;
      device.camera = CameraAccess.denied;
      await pumpScanner(tester);
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(
        find.text('Micro Seller needs the camera to scan codes and take '
            'photos.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);

      // This time the seller allows it in the prompt.
      camera.startError = null;
      device.camera = CameraAccess.granted;
      await tester.tap(find.text('Allow camera'));
      await tester.pump();
      await tester.pump();
      expect(camera.starts, 2);
      expect(find.byType(ScannerErrorView), findsNothing);
      expect(find.text(_englishHint), findsOneWidget);
    });

    testWidgets('starts by itself back from Settings, where it was allowed', (
      tester,
    ) async {
      addTearDown(() => _foreground(tester));
      camera.startError = FakeCamera.refused;
      device.camera = CameraAccess.permanentlyDenied;
      // The seller allows the camera in Settings.
      device.onOpenSettings = () {
        camera.startError = null;
        device.camera = CameraAccess.granted;
      };
      await pumpScanner(tester);
      expect(camera.starts, 1);

      await tester.tap(find.text('Open Settings'));
      _background(tester);
      await tester.pump();
      expect(camera.starts, 1);

      _foreground(tester);
      await tester.pump();
      await tester.pump();
      expect(camera.starts, 2);
      expect(find.byType(ScannerErrorView), findsNothing);
      expect(find.text(_englishHint), findsOneWidget);
    });

    testWidgets('still refused on resume, it isn\'t asked for again', (
      tester,
    ) async {
      addTearDown(() => _foreground(tester));
      for (final access in [
        CameraAccess.denied,
        CameraAccess.permanentlyDenied,
        CameraAccess.unknown,
      ]) {
        camera
          ..startError = FakeCamera.refused
          ..starts = 0;
        device
          ..camera = access
          ..cameraChecks = 0;
        await pumpScanner(tester);
        expect(camera.starts, 1, reason: '$access');
        // Android's prompt pauses and resumes the app: asking on resume
        // would show it again, and again.
        for (var i = 0; i < 3; i++) {
          _background(tester);
          await tester.pump();
          _foreground(tester);
          await tester.pump();
          await tester.pump();
        }
        expect(camera.starts, 1, reason: '$access');
        // Each resume checked whether Settings allowed it meanwhile.
        expect(device.cameraChecks, 1 + 3, reason: '$access');
        expect(find.byType(ScannerErrorView), findsOneWidget, reason: '$access');
        await tester.pumpWidget(const SizedBox());
        MobileScannerController.resetPlatformSessionOwner();
      }
    });

    testWidgets('hidden and shown again, it is asked for only if it can be', (
      tester,
    ) async {
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      for (final (access, asks) in [
        (CameraAccess.permanentlyDenied, false),
        (CameraAccess.restricted, false),
        (CameraAccess.denied, true),
      ]) {
        camera
          ..startError = FakeCamera.refused
          ..starts = 0;
        device.camera = access;
        shown.value = true;
        // Another tab shown, then this one again: the branch stays mounted
        // under a TickerMode.
        await pumpScanner(
          tester,
          screen: ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: const ScannerScreen(),
          ),
        );
        expect(camera.starts, 1, reason: '$access');
        shown.value = false;
        await tester.pump();
        shown.value = true;
        await tester.pump();
        await tester.pump();
        expect(camera.starts, asks ? 2 : 1, reason: '$access');
        await tester.pumpWidget(const SizedBox());
        MobileScannerController.resetPlatformSessionOwner();
      }
    });

    testWidgets('stays explained when an iPad turns, or the camera reports '
        'anything else', (tester) async {
      addTearDown(() => _foreground(tester));
      camera.startError = FakeCamera.refused;
      device.camera = CameraAccess.permanentlyDenied;
      await pumpScanner(tester);
      expect(find.byType(ScannerErrorView), findsOneWidget);
      final controller = _controllerOf(tester);

      // What mobile_scanner does when the screen turns (an iPad rotates):
      // its state's update forgets the error, though the camera is off.
      controller.value = controller.value.copyWith(
        deviceOrientation: DeviceOrientation.landscapeLeft,
      );
      await tester.pump();
      expect(controller.value.error, isNull);
      expect(find.byType(ScannerErrorView), findsOneWidget);
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      // No scanning frame or hint over a black preview.
      expect(find.text(_englishHint), findsNothing);
      // The flashlight's stream, likewise.
      camera.torch = TorchState.unavailable;
      await tester.pump();
      expect(find.byType(ScannerErrorView), findsOneWidget);

      // Shown again from the background, still refused: still explained,
      // and not asked for again.
      _background(tester);
      await tester.pump();
      _foreground(tester);
      await tester.pump();
      await tester.pump();
      expect(find.byType(ScannerErrorView), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(camera.starts, 1);

      // Allowed in Settings meanwhile: it starts by itself, and the view goes.
      camera.startError = null;
      device.camera = CameraAccess.granted;
      _background(tester);
      await tester.pump();
      _foreground(tester);
      await tester.pump();
      await tester.pump();
      expect(camera.starts, 2);
      expect(find.byType(ScannerErrorView), findsNothing);
      expect(find.text(_englishHint), findsOneWidget);
    });

    testWidgets('restricted by a device policy has no button', (tester) async {
      camera.startError = FakeCamera.refused;
      device.camera = CameraAccess.restricted;
      await pumpScanner(tester);
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(
        find.text('The camera is restricted on this device.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ScannerErrorView),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing,
      );
    });
  });

  group('a camera that won\'t run', () {
    testWidgets('missing: says so, with nothing to tap', (tester) async {
      camera.startError = FakeCamera.noCamera;
      await pumpScanner(tester);
      expect(
        find.text('No camera is available on this device.'),
        findsOneWidget,
      );
      expect(find.text('Camera access is off'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Open Settings'), findsNothing);
      // Not a permission problem: the access isn't checked.
      expect(device.cameraChecks, 0);
    });

    testWidgets('failed: Try again starts it', (tester) async {
      camera.startError = FakeCamera.broken;
      await pumpScanner(tester);
      expect(find.text('The camera couldn\'t start.'), findsOneWidget);
      expect(find.text('Camera access is off'), findsNothing);

      camera.startError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(camera.starts, 2);
      expect(find.byType(ScannerErrorView), findsNothing);
      expect(find.text(_englishHint), findsOneWidget);
    });
  });

  group('the flashlight', () {
    Finder torch(String tooltip) => find.byTooltip(tooltip);

    testWidgets('has no button on a device without one', (tester) async {
      camera.torch = TorchState.unavailable;
      await pumpScanner(tester);
      expect(camera.starts, 1);
      expect(find.text(_englishHint), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('its button follows the camera', (tester) async {
      await pumpScanner(tester);
      expect(torch('Turn on flashlight'), findsOneWidget);
      expect(_icon(tabler.BoltOff.new), findsOneWidget);

      await tester.tap(torch('Turn on flashlight'));
      await tester.pump();
      expect(camera.toggles, 1);
      expect(torch('Turn off flashlight'), findsOneWidget);
      expect(_icon(tabler.Bolt.new), findsOneWidget);

      // Turned off by the system (another app took the camera).
      camera.torch = TorchState.off;
      await tester.pump();
      expect(torch('Turn on flashlight'), findsOneWidget);
    });

    testWidgets('a switch that fails changes nothing', (tester) async {
      camera.toggleError = Exception('torch busy');
      await pumpScanner(tester);
      await tester.tap(torch('Turn on flashlight'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(camera.toggles, 1);
      expect(torch('Turn on flashlight'), findsOneWidget);
    });

    testWidgets('is gone while the camera is stopped', (tester) async {
      addTearDown(() => _foreground(tester));
      await pumpScanner(tester);
      expect(torch('Turn on flashlight'), findsOneWidget);
      _background(tester);
      await tester.pump();
      expect(camera.stops, 1);
      _foreground(tester);
      await tester.pump();
      await tester.pump();
      expect(camera.starts, 2);
      expect(torch('Turn on flashlight'), findsOneWidget);
    });
  });

  group("the product form's QR scanner", () {
    /// What the scanner returned, once it closed.
    String? scanned;
    var closed = false;

    /// A screen that opens the QR scanner, as the product form's scan
    /// button does.
    Widget opener() => Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  scanned = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                  closed = true;
                },
                child: const Text('Scan'),
              ),
            ),
          ),
        );

    Future<void> open(WidgetTester tester, {Locale? locale}) async {
      scanned = null;
      closed = false;
      await pumpScanner(tester, screen: opener(), locale: locale);
      await tester.tap(find.text('Scan'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('runs its camera in the foreground only', (tester) async {
      addTearDown(() => _foreground(tester));
      await open(tester);
      expect(camera.starts, 1);
      _background(tester);
      await tester.pump();
      expect(camera.stops, 1);
      _foreground(tester);
      await tester.pump();
      expect(camera.starts, 2);
    });

    testWidgets('has its hint in the app\'s language', (tester) async {
      await open(tester, locale: const Locale('bn'));
      final hint = strings(tester).pointCameraAtCode as String;
      expect(hint, isNot(_englishHint));
      expect(find.text(hint), findsOneWidget);
      expect(find.text(_englishHint), findsNothing);
    });

    testWidgets('returns a code trimmed, and no blank one', (tester) async {
      await open(tester);
      camera.scan('   \n');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(QrScannerScreen), findsOneWidget);
      expect(closed, isFalse);

      camera.scan(' 123 ');
      await tester.pump();
      expect(closed, isTrue);
      expect(scanned, '123');
      await tester.pumpAndSettle();
      expect(find.byType(QrScannerScreen), findsNothing);
    });

    testWidgets('says why a refused camera is off', (tester) async {
      camera.startError = FakeCamera.refused;
      device.camera = CameraAccess.permanentlyDenied;
      await open(tester);
      expect(find.byType(ScannerErrorView), findsOneWidget);
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text(_englishHint), findsNothing);
      expect(find.text(_pluginText), findsNothing);
      // Still, once the screen turned (an iPad rotating).
      final controller = _controllerOf(tester);
      controller.value = controller.value.copyWith(
        deviceOrientation: DeviceOrientation.landscapeRight,
      );
      await tester.pump();
      expect(find.byType(ScannerErrorView), findsOneWidget);
      expect(find.text(_englishHint), findsNothing);
      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(device.settingsOpens, 1);
    });
  });

  group('a product photo', () {
    /// Opens the product form's photo sheet and takes a photo with a camera
    /// that fails with [error].
    Future<_FakePicker> takePhoto(WidgetTester tester, Object error) async {
      final picker = _FakePicker(error);
      await pumpLayoutApp(
        tester,
        const ProductFormScreen(),
        rail: false,
        overrides: [
          categoriesProvider.overrideWithValue(const AsyncValue.data([])),
          imagePickerProvider.overrideWithValue(picker),
          deviceChannelProvider.overrideWithValue(device),
        ],
      );
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Take Photo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(picker.picks, 1);
      return picker;
    }

    PlatformException failure(String code) => PlatformException(code: code);

    testWidgets('a refused camera is explained only when the phone won\'t '
        'ask again', (tester) async {
      for (final (code, access, explained) in [
        // Android after a first "Deny": it asks again next time.
        ('camera_access_denied', CameraAccess.denied, false),
        // iOS, or Android's "Don't ask again".
        ('camera_access_denied', CameraAccess.permanentlyDenied, true),
        ('camera_access_restricted', CameraAccess.restricted, true),
        ('camera_access_denied', CameraAccess.unknown, true),
      ]) {
        device.camera = access;
        await takePhoto(tester, failure(code));
        expect(find.byType(AlertDialog), explained ? findsOneWidget : findsNothing,
            reason: '$code, $access');
        expect(find.byType(SnackBar), findsNothing, reason: '$code, $access');
        if (explained) {
          expect(find.text('Camera access is off'), findsOneWidget);
          final settings = access != CameraAccess.restricted;
          expect(find.text('Open Settings'), settings ? findsOneWidget : findsNothing);
          expect(find.text(settings ? 'Cancel' : 'Close'), findsOneWidget);
          expect(
            find.text(settings
                ? 'To scan codes and take photos, allow camera access for '
                    'Micro Seller in Settings.'
                : 'The camera is restricted on this device.'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Open Settings in the dialog opens Settings', (tester) async {
      device.camera = CameraAccess.permanentlyDenied;
      await takePhoto(tester, failure('camera_access_denied'));
      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(device.settingsOpens, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no camera, and any other failure, say so in a snackbar', (
      tester,
    ) async {
      for (final (error, message) in [
        (failure('no_available_camera'), 'No camera is available on this device.'),
        (failure('photo_access_denied'), 'Error'),
        (StateError('picker gone'), 'Error'),
      ]) {
        await takePhoto(tester, error);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.descendant(of: find.byType(SnackBar), matching: find.text(message)),
          findsOneWidget,
          reason: '$error',
        );
        expect(device.cameraChecks, 0);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
