/// The font the app's text is drawn in.
///
/// Android draws Roboto, its system font. iPhones and iPads ship San
/// Francisco, so the app bundles Roboto (`assets/fonts/roboto/`, declared in
/// pubspec.yaml as [kBundledRobotoFamily]) to draw the same text, layouts and
/// PDFs there. Scripts Roboto doesn't cover (Bengali, Arabic, Urdu, Thai, the
/// ৳ sign) still fall back to each phone's own fonts.
library;

import 'package:flutter/foundation.dart';

/// Android's system font, by the name the theme gives it.
const kSystemRobotoFamily = 'Roboto';

/// The bundled Roboto: four static weights (400, 500, 700, 900). It isn't
/// named 'Roboto', because a bundled family wins over the system's, and
/// Android's variable system Roboto would lose its real 600 and 800.
const kBundledRobotoFamily = 'RobotoStatic';

/// The family the theme names wherever it names a font: the bundled Roboto
/// on iOS, the system's elsewhere. Read when the theme is built, so a test's
/// `debugDefaultTargetPlatformOverride` reaches it.
String get appFontFamily => defaultTargetPlatform == TargetPlatform.iOS
    ? kBundledRobotoFamily
    : kSystemRobotoFamily;
