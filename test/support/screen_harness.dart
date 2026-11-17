import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';

import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/data/services/isar_service.dart';

/// The text the route under the screen shows, so a test sees the pop.
const kBelowScreen = 'screen below';

/// Lets a screen backed by a real Isar database get on: each await inside an
/// Isar call needs a real event-loop turn (runAsync), then a pump to run what
/// it resumed. Bounded, since a spinner or a stream never "settles".
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// [screen] pushed over a plain page (so it can pop), on a tall phone, in
/// English, with [isar] as the app's database.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Isar isar,
  required Widget screen,
  List overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text(kBelowScreen)),
        routes: [GoRoute(path: 'screen', builder: (_, _) => screen)],
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [isarProvider.overrideWith((ref) async => isar), ...overrides.cast()],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await settleDb(tester);
}
