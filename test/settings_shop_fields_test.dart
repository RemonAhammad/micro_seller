// Settings → Shop's number fields read what a phone's number pad types in
// any region: the tax rate takes a comma or the Arabic decimal point and any
// script's digits, at most two decimals; the low-stock threshold takes whole
// numbers in any script, and no decimal point.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/layout_harness.dart';

/// Drive, signed out, without Google.
class _FakeDrive extends DriveService {
  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
    PackageInfo.setMockInitialValues(
      appName: 'Micro Seller',
      packageName: 'com.blackshadowsoftware.micro_seller',
      version: '1.0.11',
      buildNumber: '19',
      buildSignature: '',
    );
  });

  tearDownAll(dotenv.clean);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Settings. Returns its settings notifier and strings' context.
  Future<(Settings, BuildContext)> pumpSettings(WidgetTester tester) async {
    setLayoutScreen(tester, 411, height: 6000);
    addTearDown(tester.view.reset);
    await pumpLayoutApp(
      tester,
      SettingsScreen(driveService: _FakeDrive()),
      overrides: [
        updateChannelProvider.overrideWithValue(
          const AsyncValue.data(UpdateChannel.none),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsScreen));
    return (
      ProviderScope.containerOf(context).read(settingsProvider.notifier),
      context,
    );
  }

  /// Opens [label]'s edit dialog, enters [typed] over its whole value (a
  /// paste, or a keyboard's text over it all), saves, and returns what the
  /// field held.
  Future<String> edit(WidgetTester tester, String label, String typed) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    await tester.enterText(field, typed);
    await tester.pump();
    final shown = tester.widget<TextField>(field).controller!.text;
    final s = AppStrings.of(tester.element(find.byType(AlertDialog)));
    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    return shown;
  }

  testWidgets('the tax rate', (tester) async {
    final (settings, context) = await pumpSettings(tester);
    final s = AppStrings.of(context);
    // A French or Brazilian number pad's comma.
    expect(await edit(tester, s.taxRate, '7,5'), '7.5');
    expect(settings.taxRate, 7.5);
    // An Arabic one's digits and point.
    expect(await edit(tester, s.taxRate, '١٢٫٥'), '12.5');
    expect(settings.taxRate, 12.5);
    // Two decimals at most.
    expect(await edit(tester, s.taxRate, '12.345'), '12.35');
    expect(settings.taxRate, 12.35);
  });

  testWidgets('the low-stock threshold', (tester) async {
    final (settings, context) = await pumpSettings(tester);
    final s = AppStrings.of(context);
    // A Bengali keyboard's digits.
    expect(await edit(tester, s.defaultLowStockThreshold, '১২'), '12');
    expect(settings.lowStockThreshold, 12);
    // A fraction isn't a number of items: the field keeps what it had.
    final before = settings.lowStockThreshold.toString();
    expect(await edit(tester, s.defaultLowStockThreshold, '7.5'), before);
    expect(settings.lowStockThreshold, 12);
  });
}
