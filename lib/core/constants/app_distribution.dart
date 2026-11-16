

abstract final class AppDistribution {

  static const repo = 'microseller/microseller';

  static final latestReleaseApi =
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  static final releasesPage = Uri.parse('https://github.com/$repo/releases');

  /// The repo's GitHub issues list.
  static final issuesPage = Uri.parse('https://github.com/$repo/issues');

  /// A pre-filled "new issue" link for the Support screen's Report a problem.
  /// GitHub reads `title` and `body` from the query string.
  static Uri newIssueUrl({required String title, required String body}) =>
      Uri.parse('https://github.com/$repo/issues/new').replace(
        queryParameters: {'title': title, 'body': body},
      );

  /// Privacy policy page. Empty until the owner publishes one (e.g. a GitHub
  /// Pages URL); while empty, the Support screen hides the privacy row.
  static const privacyPolicyUrl = '';

  static const playInstaller = 'com.android.vending';

  static const String? appStoreId = null;
}
