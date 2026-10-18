import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/l10n/app_localizations.dart';
import 'data/services/auto_backup_runner.dart';
import 'data/services/isar_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/providers/trash_provider.dart';

class SellerBookApp extends ConsumerStatefulWidget {
  const SellerBookApp({super.key});

  @override
  ConsumerState<SellerBookApp> createState() => _SellerBookAppState();
}

class _SellerBookAppState extends ConsumerState<SellerBookApp> {
  Timer? _autoBackupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Fire-and-forget, well after the first frame: the backup encodes the
      // whole DB on this isolate and would freeze the dashboard. The runner
      // short-circuits if auto-backup is disabled, the Drive account isn't
      // signed in, or the last backup was less than 12 hours ago.
      _autoBackupTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) ref.read(autoBackupRunnerProvider).runIfDue();
      });

      // Drop recycle-bin entries past the retention window. Also
      // fire-and-forget: a failure here must never keep the app from
      // starting, and the next launch will retry.
      try {
        final service = await ref.read(trashServiceProvider.future);
        await service.purgeExpired();
      } catch (_) {
        // Non-fatal — stale entries simply persist until the next launch.
      }
    });
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pre-warm the Isar DB on app start
    ref.watch(isarProvider);

    // Only what MaterialApp uses — watching the whole map rebuilt the app on
    // every settings write.
    final (mode, langCode, shopName) =
        ref.watch(settingsProvider.select((s) => (
              s['themeMode'] as String? ?? 'system',
              s['language'] as String? ?? 'en',
              s['shopName'] as String? ?? '',
            )));
    final themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

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
