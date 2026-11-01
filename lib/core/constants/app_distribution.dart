

abstract final class AppDistribution {

  static const repo = 'RemonAhammad/micro_seller';

  static final latestReleaseApi =
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  static final releasesPage = Uri.parse('https://github.com/$repo/releases');

  static const playInstaller = 'com.android.vending';

  static const String? appStoreId = null;
}
