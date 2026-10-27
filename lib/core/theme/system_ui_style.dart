/// The status bar's style: readable over the app's own theme, whatever the
/// phone's light / dark setting.
///
/// The app frame (`app_frame.dart`) puts [appSystemUiStyle] in an
/// AnnotatedRegion over the whole window, the first-launch splash puts
/// [kSplashSystemUiStyle] over itself (the region nearest the status bar
/// wins), and main() sets [initialSystemUiStyle] before the first frame.
/// Each sets both platforms' fields: Android reads statusBarIconBrightness,
/// iOS statusBarBrightness (the brightness of what's behind the bar).
///
/// Flutter's MaterialApp also sends SystemUiOverlayStyle.dark or .light
/// whenever it builds its theme. A region is read at the end of every
/// frame, so in a frame where the theme is rebuilt the region's style
/// replaces MaterialApp's before it reaches the platform.
///
/// The navigation bar's fields stay null, so Android's navigation bar keeps
/// exactly the look it has always had. Don't use SystemUiOverlayStyle.light
/// or .dark: they force a black navigation bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Over a light theme: dark icons and text.
const _overLightTheme = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// Over a dark theme: light icons and text.
const _overDarkTheme = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// The status bar over the app in a [theme]-brightness theme (the resolved
/// one: System follows the phone). Transparent, so the shell's scaffold
/// shows through, with icons and text that read on it.
SystemUiOverlayStyle appSystemUiStyle(Brightness theme) =>
    theme == Brightness.dark ? _overDarkTheme : _overLightTheme;

/// The status bar over the first-launch splash's teal: light icons and text
/// in either theme.
const kSplashSystemUiStyle = _overDarkTheme;

/// The style main() sets before the first frame, so the native launch
/// screen hands over to a readable status bar: the splash's when it will
/// show ([splash]), else the app's in the saved [themeMode] ('light',
/// 'dark' or 'system'; System, or anything else, follows [platform], the
/// phone's brightness).
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
