import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/utils/currency_formatter.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
