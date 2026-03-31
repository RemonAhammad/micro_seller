import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'data/services/isar_service.dart';

class SellerBookApp extends ConsumerWidget {
  const SellerBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-warm the Isar DB on app start
    ref.watch(isarProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
