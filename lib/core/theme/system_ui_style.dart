

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _overLightTheme = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

const _overDarkTheme = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

SystemUiOverlayStyle appSystemUiStyle(Brightness theme) =>
    theme == Brightness.dark ? _overDarkTheme : _overLightTheme;

const kSplashSystemUiStyle = _overDarkTheme;

SystemUiOverlayStyle initialSystemUiStyle({
  required bool splash,
  required String themeMode,
  required Brightness platform,
}) {
  if (splash) return kSplashSystemUiStyle;
  return appSystemUiStyle(switch (themeMode) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => platform,
  });
}
