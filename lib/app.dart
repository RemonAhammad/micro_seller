import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/l10n/app_localizations.dart';
import 'data/services/isar_service.dart';
import 'features/settings/providers/settings_provider.dart';

class SellerBookApp extends ConsumerWidget {
  const SellerBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-warm the Isar DB on app start
    ref.watch(isarProvider);

    final settings = ref.watch(settingsProvider);
    final mode = settings['themeMode'] as String? ?? 'system';
    final themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final langCode = settings['language'] as String? ?? 'en';
    final shopName = settings['shopName'] as String? ?? '';

    return MaterialApp.router(
      // OS task switcher / browser tab title — show the user's shop name when
      // they've set one, fall back to the app's brand name otherwise.
      title: shopName.isNotEmpty ? shopName : AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      locale: Locale(langCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
