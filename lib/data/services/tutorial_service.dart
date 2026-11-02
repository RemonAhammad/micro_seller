import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _keySplashShown = 'splash_shown';
  static const _keyTourCompleted = 'tour_completed';

  /// Prefix for the per-screen one-time guide flags (`screen_guide_<id>`),
  /// one per main tab. Independent of the sidebar [_keyTourCompleted] tour.
  static const _screenGuidePrefix = 'screen_guide_';

  static bool _splashShown = false;

  static bool get splashShown => _splashShown;

  static void primeFrom(SharedPreferences prefs) {
    _splashShown = prefs.getBool(_keySplashShown) ?? false;
  }

  static Future<bool> isSplashShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySplashShown) ?? false;
  }

  static Future<void> setSplashShown() async {
    _splashShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySplashShown, true);
  }

  static Future<bool> isTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTourCompleted) ?? false;
  }

  static Future<void> setTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTourCompleted, true);
  }

  /// Whether the one-time guide for screen [id] (a sidebar key) has run.
  static Future<bool> isScreenGuideShown(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_screenGuidePrefix$id') ?? false;
  }

  static Future<void> setScreenGuideShown(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_screenGuidePrefix$id', true);
  }

  static Future<void> resetAll() async {
    _splashShown = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySplashShown);
    await prefs.remove(_keyTourCompleted);
    // Per-screen guide flags are dynamic keys; clear every one so a reset
    // (or a future "Replay guides") brings them all back.
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_screenGuidePrefix)) await prefs.remove(key);
    }
  }
}
