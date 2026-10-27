/// Where the app is published: its GitHub repository (the iPhone `.ipa` and
/// the Android APKs are release assets there) and its store listings.
abstract final class AppDistribution {
  /// The GitHub repository, `owner/name`.
  static const repo = 'RemonAhammad/micro_seller';

  /// GitHub's API for the latest release: never a draft or a pre-release.
  static final latestReleaseApi =
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  /// The repository's releases page; a release's own page starts with it.
  static final releasesPage = Uri.parse('https://github.com/$repo/releases');

  /// Google Play's installer package: an install from Play updates through
  /// Play's own in-app update, not the GitHub notice.
  static const playInstaller = 'com.android.vending';

  /// The app's App Store id, once it is listed there. Null while the iPhone
  /// app is only sideloaded, so it offers no rating.
  static const String? appStoreId = null;
}
