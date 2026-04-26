import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/utils/currency_formatter.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (OAuth client IDs etc). Don't crash the app if it's missing —
  // Android google_sign_in works without it.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) debugPrint('[main] .env not loaded: $e');
  }

  // Load currency symbol before anything renders
  final prefs = await SharedPreferences.getInstance();
  final currency = prefs.getString('currencySymbol');
  if (currency != null && currency.isNotEmpty) {
    CurrencyFormatter.setSymbol(currency);
  }

  await NotificationService.init();

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

  runApp(
    const ProviderScope(
      child: SellerBookApp(),
    ),
  );
}
