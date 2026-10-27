// On an iPad the share sheet is a popover anchored to the control that was
// tapped. The Dashboard's Due Book card (Remind, when WhatsApp can't open),
// the Reports export and Settings → Export backup each hand share_plus the
// rect of their own control, so the popover points at it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/dashboard/presentation/dashboard_screen.dart';
import 'package:micro_seller/features/reports/presentation/reports_screen.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// url_launcher's platform side, faked below so Remind's real launchUrl runs
// without a device. A dependency of url_launcher, not of the app.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'layout/dashboard_reports_data.dart';
import 'support/layout_harness.dart';

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// path_provider's channel, for the temporary folder an export writes to.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// A device without WhatsApp: no app opens wa.me links.
class _NoWhatsApp extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return false;
  }
}

/// Drive, signed out, without Google.
class _FakeDrive extends DriveService {
  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;
}

/// Local backup without a database: records where its share sheet points.
class _FakeBackup extends LocalBackupService {
  final origins = <Rect?>[];

  @override
  Future<String?> exportBackup(
    Isar isar, {
    Map<String, dynamic>? settings,
    Rect? shareOrigin,
  }) async {
    origins.add(shareOrigin);
    return null;
  }
}

/// No database: the fake backup never opens it.
class _NoIsar extends Fake implements Isar {}

/// The rect share_plus was handed.
Rect _origin(Map<Object?, Object?> arguments) => Rect.fromLTWH(
  arguments['originX']! as double,
  arguments['originY']! as double,
  arguments['originWidth']! as double,
  arguments['originHeight']! as double,
);

/// An iPad mini in portrait, beside the sidebar with labels.
void _iPad(WidgetTester tester) {
  setLayoutScreen(tester, 744, height: 1133, devicePixelRatio: 2);
  addTearDown(tester.view.reset);
}

void main() {
  late UrlLauncherPlatform realLauncher;
  late _NoWhatsApp launcher;

  /// What the share sheet was given.
  late List<Map<Object?, Object?>> shared;
  late Directory temp;

  setUpAll(() {
    realLauncher = UrlLauncherPlatform.instance;
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
    PackageInfo.setMockInitialValues(
      appName: 'Micro Seller',
      packageName: 'com.blackshadowsoftware.microseller',
      version: '1.0.11',
      buildNumber: '19',
      buildSignature: '',
    );
  });

  tearDownAll(() {
    UrlLauncherPlatform.instance = realLauncher;
    dotenv.clean();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launcher = _NoWhatsApp();
    UrlLauncherPlatform.instance = launcher;
    shared = [];
    temp = Directory.systemTemp.createTempSync('share_origin_screens');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'com.apple.UIKit.activity.Message';
    });
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => call.method == 'getTemporaryDirectory' ? temp.path : null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_pathChannel, null);
    temp.deleteSync(recursive: true);
  });

  testWidgets(
    'the Due Book card\'s Remind points at its button',
    (tester) async {
      _iPad(tester);
      await pumpLayoutApp(
        tester,
        const DashboardScreen(),
        overrides: dashboardOverrides(
          stats: typicalDashboardStats(),
          dues: typicalDues(),
        ),
      );
      await tester.pumpAndSettle();
      final s = AppStrings.of(tester.element(find.byType(DashboardScreen)));
      // The second customer to chase (40 days), so the rect isn't the
      // first row's.
      await tester.scrollUntilVisible(
        find.text('Nasima Begum'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final remind = find
          .byWidgetPredicate((w) => w is IconButton && w.tooltip == s.remind)
          .at(1);
      await tester.tap(remind);
      await tester.pumpAndSettle();
      expect(launcher.launched.single, startsWith('https://wa.me/'));
      expect(_origin(shared.single), tester.getRect(remind));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'the Reports export points at the export button',
    (tester) async {
      _iPad(tester);
      await pumpLayoutApp(
        tester,
        const ReportsScreen(),
        overrides: reportOverrides(),
      );
      await tester.pumpAndSettle();
      final s = AppStrings.of(tester.element(find.byType(ReportsScreen)));
      final button = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == s.tr('export'),
      );
      final rect = tester.getRect(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.tr('shareAsCsv')));
      await tester.pump();
      // The CSV is encoded on a worker isolate and written to a real file.
      for (var i = 0; i < 300 && shared.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      // Shared from the export slot, where the spinner stood in for the
      // button meanwhile.
      expect(_origin(shared.single), rect);
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Settings → Export backup points at its row',
    (tester) async {
      _iPad(tester);
      final backup = _FakeBackup();
      await pumpLayoutApp(
        tester,
        SettingsScreen(driveService: _FakeDrive(), localBackupService: backup),
        overrides: [
          isarProvider.overrideWithValue(AsyncValue.data(_NoIsar())),
          updateChannelProvider.overrideWithValue(
            const AsyncValue.data(UpdateChannel.none),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final s = AppStrings.of(tester.element(find.byType(SettingsScreen)));
      final row = find.widgetWithText(ListTile, s.exportBackup);
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(backup.origins, [tester.getRect(row)]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
