/// The update notice for installs no store updates: the iPhone app,
/// sideloaded from a GitHub release's `.ipa`, and Android APKs installed from
/// GitHub. Play installs keep Play's own in-app update (`update_service.dart`).
///
/// It asks GitHub for the latest release at most once a day and remembers
/// the answer, so the notice still shows offline. What it remembers is
/// per-device (`update_notice_*` in SharedPreferences) and never part of a
/// backup: `Settings.exportSettings` exports only the keys it names.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_distribution.dart';

/// How this install gets its updates.
enum UpdateChannel {
  /// Google Play's in-app update.
  play,

  /// The GitHub release notice: iOS, and Android installs not from Play.
  github,

  /// None: desktop and web.
  none,
}

/// The channel of an install on [platform] that [installerStore]
/// (`PackageInfo.installerStore`) put there.
UpdateChannel updateChannelFor({
  required TargetPlatform platform,
  required String? installerStore,
  bool isWeb = kIsWeb,
}) {
  if (isWeb) return UpdateChannel.none;
  return switch (platform) {
    // iOS reports "com.apple" even for a sideloaded app.
    TargetPlatform.iOS => UpdateChannel.github,
    // Anything but Play (null, the package installer, a browser) is an APK
    // from GitHub.
    TargetPlatform.android => installerStore == AppDistribution.playInstaller
        ? UpdateChannel.play
        : UpdateChannel.github,
    _ => UpdateChannel.none,
  };
}

/// This install's channel ([updateChannelFor]), reading the installer from
/// PackageInfo where it matters (Android). [UpdateChannel.none] when it
/// can't be read. Never throws.
Future<UpdateChannel> readUpdateChannel() async {
  try {
    final platform = defaultTargetPlatform;
    final installer = !kIsWeb && platform == TargetPlatform.android
        ? (await PackageInfo.fromPlatform()).installerStore
        : null;
    return updateChannelFor(platform: platform, installerStore: installer);
  } catch (_) {
    return UpdateChannel.none;
  }
}

/// A release version: `1.0.12`, `v1.0.12`, `1.0.12-rc.1`, `1.0.12+19`.
/// Numbers compare numerically, a missing one counting as 0, and a
/// pre-release is lower than the same version without one. Build metadata
/// (`+19`) doesn't count.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.numbers, this.preRelease);

  // At most nine digits per number, so none overflows.
  static final _pattern = RegExp(
      r'^[vV]?(\d{1,9}(?:\.\d{1,9})*)(?:-([\w.-]+))?(?:\+[\w.-]+)?$');

  /// The dot-separated numbers.
  final List<int> numbers;

  /// What follows the `-`, like `rc.1`; null for a stable version.
  final String? preRelease;

  bool get isPreRelease => preRelease != null;

  /// [raw], trimmed, as a version; null when it isn't one.
  static AppVersion? tryParse(String? raw) {
    final match = _pattern.firstMatch(raw?.trim() ?? '');
    if (match == null) return null;
    return AppVersion._(
      [for (final n in match[1]!.split('.')) int.parse(n)],
      match[2],
    );
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < math.max(numbers.length, other.numbers.length); i++) {
      final a = i < numbers.length ? numbers[i] : 0;
      final b = i < other.numbers.length ? other.numbers[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return switch ((preRelease, other.preRelease)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final a?, final b?) => _comparePreRelease(a, b),
    };
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;

  /// Semantic Versioning's order: identifier by identifier, numbers
  /// numerically and below words; more identifiers win a tie.
  static int _comparePreRelease(String a, String b) {
    final x = a.split('.'), y = b.split('.');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final m = int.tryParse(x[i]), n = int.tryParse(y[i]);
      final order = m != null && n != null
          ? m.compareTo(n)
          : m != null
              ? -1
              : n != null
                  ? 1
                  : x[i].compareTo(y[i]);
      if (order != 0) return order;
    }
    return x.length.compareTo(y.length);
  }

  @override
  String toString() =>
      numbers.join('.') + (preRelease == null ? '' : '-$preRelease');
}

/// A release newer than this install.
@immutable
class AvailableUpdate {
  const AvailableUpdate({required this.tag, required this.url});

  /// The release's tag, like `v1.0.12`.
  final String tag;

  /// The release's page on GitHub, which lists its files.
  final Uri url;

  /// [tag] without its `v`, as the notice shows it: `1.0.12`.
  String get version => tag.startsWith(RegExp('[vV]')) ? tag.substring(1) : tag;

  @override
  bool operator ==(Object other) =>
      other is AvailableUpdate && other.tag == tag && other.url == url;

  @override
  int get hashCode => Object.hash(tag, url);

  @override
  String toString() => 'AvailableUpdate($tag, $url)';
}

/// What a manual check ([ReleaseUpdateService.checkNow]) found.
sealed class ManualCheck {
  const ManualCheck();
}

/// A newer release.
final class Available extends ManualCheck {
  const Available(this.update);

  final AvailableUpdate update;
}

/// This install is the latest release.
final class UpToDate extends ManualCheck {
  const UpToDate();
}

/// GitHub couldn't be asked, and no earlier answer is remembered.
final class CheckFailed extends ManualCheck {
  const CheckFailed();
}

/// Asks GitHub for the latest release and decides whether to show it.
///
/// A release counts when it is stable (not a draft or a pre-release, a tag
/// that parses without a pre-release part) and carries this platform's file:
/// an `.ipa` on iOS, an `.apk` on Android. Its page must be in this
/// repository, or the releases page is offered instead.
///
/// GitHub's answers: a release is remembered, and a 404 (no release) or one
/// that doesn't count forgets the last one. A rate limit (403, 429), a server
/// error, a timeout, no connection or a body that isn't JSON keeps what was
/// remembered, silently.
class ReleaseUpdateService {
  /// [installedVersion] is this install's (`PackageInfo.version`), and
  /// [platform] decides which file a release must carry. GitHub is asked at
  /// most once per [throttle], and a request gives up after [timeout].
  ReleaseUpdateService({
    required this._client,
    required this._prefs,
    required this._installedVersion,
    required this._platform,
    this._now = DateTime.now,
    this._throttle = const Duration(hours: 24),
    this._timeout = const Duration(seconds: 10),
  }) : _installed = AppVersion.tryParse(_installedVersion);

  // Per-device keys; Settings never exports them.
  static const _keyCheckedAt = 'update_notice_checked_at';
  static const _keyLatestTag = 'update_notice_latest_tag';
  static const _keyLatestUrl = 'update_notice_latest_url';
  static const _keySnoozedTag = 'update_notice_snoozed_tag';

  final http.Client _client;
  final SharedPreferences _prefs;
  final String _installedVersion;
  final AppVersion? _installed;
  final TargetPlatform _platform;
  final DateTime Function() _now;
  final Duration _throttle;
  final Duration _timeout;

  /// The request under way, shared by calls made meanwhile.
  Future<bool>? _inFlight;

  /// The release the notice shows, if any: the remembered latest release
  /// when it is newer than this install and wasn't dismissed. Asks GitHub
  /// only once [throttle] has passed since the last attempt (or the clock
  /// was moved back), sharing a request already under way. Never throws.
  Future<AvailableUpdate?> check() async {
    try {
      if (_inFlight != null || _isDue) await _fetch();
      return notice;
    } catch (_) {
      return null;
    }
  }

  /// Settings' "Check for updates": asks GitHub now, whatever the throttle,
  /// and offers a dismissed release too. Fails only when GitHub couldn't be
  /// asked and no earlier answer is remembered. Never throws.
  Future<ManualCheck> checkNow() async {
    try {
      final answered = await _fetch();
      final latest = _latest;
      if (!answered && latest == null) return const CheckFailed();
      return latest != null && _isNewer(latest)
          ? Available(latest)
          : const UpToDate();
    } catch (_) {
      return const CheckFailed();
    }
  }

  /// Hides the notice for [tag] until a newer release comes out.
  Future<void> snooze(String tag) async {
    try {
      await _prefs.setString(_keySnoozedTag, tag);
    } catch (_) {
      // Not remembered: the notice comes back next time.
    }
  }

  /// What [check] answers, without asking GitHub.
  AvailableUpdate? get notice {
    final latest = _latest;
    if (latest == null || !_isNewer(latest)) return null;
    return _prefs.get(_keySnoozedTag) == latest.tag ? null : latest;
  }

  /// The remembered latest release.
  AvailableUpdate? get _latest {
    final tag = _prefs.get(_keyLatestTag);
    final url = _prefs.get(_keyLatestUrl);
    if (tag is! String || AppVersion.tryParse(tag) == null) return null;
    return AvailableUpdate(
      tag: tag,
      url: (url is String ? Uri.tryParse(url) : null) ??
          AppDistribution.releasesPage,
    );
  }

  bool _isNewer(AvailableUpdate update) {
    final installed = _installed;
    final latest = AppVersion.tryParse(update.tag);
    return installed != null && latest != null && latest > installed;
  }

  /// No attempt yet, [_throttle] since the last one, or the last one is in
  /// the future: the clock was moved back.
  bool get _isDue {
    final stamp = _prefs.get(_keyCheckedAt);
    if (stamp is! int) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(stamp);
    final now = _now();
    return last.isAfter(now) || now.difference(last) >= _throttle;
  }

  Future<bool> _fetch() =>
      _inFlight ??= _request().whenComplete(() => _inFlight = null);

  /// Asks GitHub for its latest release and remembers the answer. True when
  /// GitHub answered (a release or none), false when it couldn't be asked,
  /// which keeps the last answer. Every attempt is stamped, so a failing one
  /// waits for the throttle too.
  Future<bool> _request() async {
    try {
      await _prefs.setInt(_keyCheckedAt, _now().millisecondsSinceEpoch);
      final response = await _client.get(
        AppDistribution.latestReleaseApi,
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'MicroSeller/$_installedVersion',
        },
      ).timeout(_timeout);
      switch (response.statusCode) {
        case 200:
          final release = _release(jsonDecode(utf8.decode(response.bodyBytes)));
          await (release == null ? _forget() : _remember(release));
          return true;
        case 404:
          // No release at all.
          await _forget();
          return true;
        default:
          // Rate-limited (403, 429) or a server error: next time.
          return false;
      }
    } catch (_) {
      // Offline, timed out, or not JSON.
      return false;
    }
  }

  /// The release in GitHub's [json], if it counts; throws when [json] isn't
  /// a release at all.
  AvailableUpdate? _release(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Not a release');
    }
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null || version.isPreRelease) return null;
    final file = _platform == TargetPlatform.iOS ? '.ipa' : '.apk';
    final assets = json['assets'];
    final hasFile = assets is List &&
        assets.any((asset) =>
            asset is Map &&
            asset['name'] is String &&
            (asset['name'] as String).toLowerCase().endsWith(file));
    if (!hasFile) return null;
    final page = json['html_url'];
    final ownPage = page is String &&
            page.startsWith('${AppDistribution.releasesPage}/')
        ? Uri.tryParse(page)
        : null;
    return AvailableUpdate(
      tag: tag.trim(),
      url: ownPage ?? AppDistribution.releasesPage,
    );
  }

  Future<void> _remember(AvailableUpdate release) async {
    await _prefs.setString(_keyLatestTag, release.tag);
    await _prefs.setString(_keyLatestUrl, release.url.toString());
  }

  Future<void> _forget() async {
    await _prefs.remove(_keyLatestTag);
    await _prefs.remove(_keyLatestUrl);
  }
}
