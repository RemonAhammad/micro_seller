import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_color_theme.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dynamic_color_support.dart';
import 'core/constants/app_strings.dart';
import 'core/l10n/app_localizations.dart';
import 'data/services/auto_backup_runner.dart';
import 'data/services/isar_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/providers/trash_provider.dart';
import 'shared/widgets/app_frame.dart';

class SellerBookApp extends ConsumerStatefulWidget {
  const SellerBookApp({super.key});

  @override
  ConsumerState<SellerBookApp> createState() => _SellerBookAppState();
}

class _SellerBookAppState extends ConsumerState<SellerBookApp> {
  Timer? _autoBackupTimer;

  (String, String)? _colorThemeKey;
  AppColorTheme _colorTheme = kDefaultColorTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {

      _autoBackupTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) ref.read(autoBackupRunnerProvider).runIfDue();
      });

      try {
        final service = await ref.read(trashServiceProvider.future);
        await service.purgeExpired();
      } catch (_) {

      }
    });
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    super.dispose();
  }

  AppColorTheme _resolveColorTheme(String id, String customThemesJson) {
    final key = (id, customThemesJson);
    if (key != _colorThemeKey) {
      _colorThemeKey = key;
      _colorTheme =
          resolveColorTheme(id, decodeCustomColorThemes(customThemesJson));
    }
    return _colorTheme;
  }

  @override
  Widget build(BuildContext context) {

    ref.watch(isarProvider);

    final (mode, langCode, shopName, colorThemeId, customThemesJson) =
        ref.watch(settingsProvider.select((s) => (
              s['themeMode'] as String? ?? 'system',
              s['language'] as String? ?? 'en',
              s['shopName'] as String? ?? '',
              s[Settings.keyColorThemeId] as String? ?? kDefaultColorThemeId,
              s[Settings.keyCustomColorThemes] as String? ?? '',
            )));
    final themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final colorTheme = _resolveColorTheme(colorThemeId, customThemesJson);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final system = DynamicColorSupport.schemesFor(
          colorTheme,
          lightDynamic: lightDynamic,
          darkDynamic: darkDynamic,
        );
        publishDocumentBrand(colorTheme, lightDynamic: system.light);
        return MaterialApp.router(

          title: shopName.isNotEmpty ? shopName : AppStrings.appName,
          debugShowCheckedModeBanner: false,

          theme: AppTheme.build(Brightness.light, colorTheme,
              dynamicScheme: system.light),
          darkTheme: AppTheme.build(Brightness.dark, colorTheme,
              dynamicScheme: system.dark),
          themeMode: themeMode,
          routerConfig: appRouter,

          builder: (context, child) =>
              AppFrame(child: child ?? const SizedBox.shrink()),
          locale: Locale(langCode),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
