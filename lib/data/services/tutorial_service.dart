import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _keySplashShown = 'splash_shown';
  static const _keyTourCompleted = 'tour_completed';

  static bool _splashShown = false;

  /// Synchronous copy of the splash flag for the router's initialLocation.
  /// Valid once [primeFrom] has run (main(), before runApp).
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

  static Future<void> resetAll() async {
    _splashShown = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySplashShown);
    await prefs.remove(_keyTourCompleted);
  }
}
