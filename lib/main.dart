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
import 'core/utils/currency_formatter.dart';
import 'data/services/auto_backup_runner.dart';
import 'data/services/notification_service.dart';
import 'data/services/tutorial_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In parallel. .env must still be loaded before runApp — DriveService
  // reads it.
  final results = await Future.wait<Object?>([
    _loadEnv(),
    SharedPreferences.getInstance(),
  ]);
  final prefs = results[1] as SharedPreferences;

  // Load currency symbol before anything renders
  final currency = prefs.getString('currencySymbol');
  if (currency != null && currency.isNotEmpty) {
    CurrencyFormatter.setSymbol(currency);
  }

  // Before runApp: the router's initialLocation reads it synchronously.
  TutorialService.primeFrom(prefs);

  // iOS asks for notification permission during init; keep that prompt
  // before the first frame as it always was.
  if (Platform.isIOS) await NotificationService.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // The app draws ~140 distinct (icon, stroke) SVGs; flutter_svg keeps 100
  // by default, so icons evicted while navigating were re-parsed in an
  // isolate and popped in a frame late.
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

  // After the first frame, so it stays off the startup path.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_warmIcons());
  });

  // Workmanager — Android only, after the first frame so it stays off the
  // startup path. Initialized once per process; the dispatcher is a
  // top-level entry-point (see auto_backup_runner.dart) so AOT keeps it
  // alive in release builds. Schedule the daily backup when the user has
  // Auto Backup turned on; otherwise leave it idle.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(autoBackupCallbackDispatcher);
      if (prefs.getBool('autoBackup') ?? false) {
        // keep, not replace: leave an already-pending run alone.
        await AutoBackupRunner.scheduleAutoBackup(replace: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[main] workmanager init failed: $e');
    }
  });
}

/// Parse the sidebar icons (at both strokes: the active tab is drawn bolder)
/// and the dashboard's into the SVG cache, so switching tabs doesn't wait a
/// frame on an isolate parse. Best effort — an icon that isn't warmed just
/// loads the way it always did.
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

/// Load .env (OAuth client IDs etc). Don't crash the app if it's missing —
/// Android google_sign_in works without it.
Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) debugPrint('[main] .env not loaded: $e');
  }
}
