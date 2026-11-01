import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart' show svg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'core/constants/app_icons.dart';
import 'core/constants/sidebar_items.dart';
import 'core/theme/dynamic_color_support.dart';
import 'core/theme/system_ui_style.dart';
import 'core/utils/currency_formatter.dart';
import 'core/utils/orientation_policy.dart';
import 'data/services/auto_backup_runner.dart';
import 'data/services/notification_service.dart';
import 'data/services/tutorial_service.dart';
import 'features/settings/providers/display_scale_provider.dart';
import 'features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final results = await Future.wait<Object?>([
    _loadEnv(),
    SharedPreferences.getInstance(),
  ]);
  final prefs = results[1] as SharedPreferences;

  final currency = prefs.getString('currencySymbol');
  if (currency != null && currency.isNotEmpty) {
    CurrencyFormatter.setSymbol(currency);
  }

  TutorialService.primeFrom(prefs);

  DisplayScale.primeFrom(prefs);

  Settings.primeFrom(prefs);
  final colorTheme = Settings.primedColorTheme;

  if (colorTheme.isPhone) await DynamicColorSupport.prime();

  publishDocumentBrand(
    colorTheme,
    lightDynamic: DynamicColorSupport.schemesFor(colorTheme).light,
  );

  if (Platform.isIOS) await NotificationService.init();

  await OrientationPolicy.install();

  SystemChrome.setSystemUIOverlayStyle(initialSystemUiStyle(
    splash: !TutorialService.splashShown,
    themeMode: Settings.primedThemeMode,
    platform: WidgetsBinding.instance.platformDispatcher.platformBrightness,
  ));

  svg.cache.maximumSize = 300;

  runApp(
    const ProviderScope(
      child: SellerBookApp(),
    ),
  );

  if (!Platform.isIOS) {
    unawaited(NotificationService.init().catchError((Object e) {
      if (kDebugMode) debugPrint('[main] notification init failed: $e');
    }));
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_warmIcons());
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(autoBackupCallbackDispatcher);
      if (prefs.getBool('autoBackup') ?? false) {

        await AutoBackupRunner.scheduleAutoBackup(replace: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[main] workmanager init failed: $e');
    }
  });
}

Future<void> _warmIcons() async {
  try {
    final sidebar = [for (final item in sidebarItems) item.icon];
    await warmThinIcons(sidebar);
    await warmThinIcons(sidebar, strokeWidth: kIconStrokeSelected);
    await warmThinIcons(AppIcons.dashboardSet);
  } catch (e) {
    if (kDebugMode) debugPrint('[main] icon warm-up failed: $e');
  }
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) debugPrint('[main] .env not loaded: $e');
  }
}
