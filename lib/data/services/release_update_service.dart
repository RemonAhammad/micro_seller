

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_distribution.dart';

enum UpdateChannel {

  play,

  github,

  none,
}

UpdateChannel updateChannelFor({
  required TargetPlatform platform,
  required String? installerStore,
  bool isWeb = kIsWeb,
}) {
  if (isWeb) return UpdateChannel.none;
  return switch (platform) {

    TargetPlatform.iOS => UpdateChannel.github,

    TargetPlatform.android => installerStore == AppDistribution.playInstaller
        ? UpdateChannel.play
        : UpdateChannel.github,
    _ => UpdateChannel.none,
  };
}

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

class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.numbers, this.preRelease);

  static final _pattern = RegExp(
      r'^[vV]?(\d{1,9}(?:\.\d{1,9})*)(?:-([\w.-]+))?(?:\+[\w.-]+)?$');

  final List<int> numbers;

  final String? preRelease;

  bool get isPreRelease => preRelease != null;

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

@immutable
class AvailableUpdate {
  const AvailableUpdate({required this.tag, required this.url});

  final String tag;

  final Uri url;

  String get version => tag.startsWith(RegExp('[vV]')) ? tag.substring(1) : tag;

  @override
  bool operator ==(Object other) =>
      other is AvailableUpdate && other.tag == tag && other.url == url;

  @override
  int get hashCode => Object.hash(tag, url);

  @override
  String toString() => 'AvailableUpdate($tag, $url)';
}

sealed class ManualCheck {
  const ManualCheck();
}

final class Available extends ManualCheck {
  const Available(this.update);

  final AvailableUpdate update;
}

final class UpToDate extends ManualCheck {
  const UpToDate();
}

final class CheckFailed extends ManualCheck {
  const CheckFailed();
}

class ReleaseUpdateService {

  ReleaseUpdateService({
    required this._client,
    required this._prefs,
    required this._installedVersion,
    required this._platform,
    this._now = DateTime.now,
    this._throttle = const Duration(hours: 24),
    this._timeout = const Duration(seconds: 10),
  }) : _installed = AppVersion.tryParse(_installedVersion);

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

  Future<bool>? _inFlight;

  Future<AvailableUpdate?> check() async {
    try {
      if (_inFlight != null || _isDue) await _fetch();
      return notice;
    } catch (_) {
      return null;
    }
  }

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

  Future<void> snooze(String tag) async {
    try {
      await _prefs.setString(_keySnoozedTag, tag);
    } catch (_) {

    }
  }

  AvailableUpdate? get notice {
    final latest = _latest;
    if (latest == null || !_isNewer(latest)) return null;
    return _prefs.get(_keySnoozedTag) == latest.tag ? null : latest;
  }

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

  bool get _isDue {
    final stamp = _prefs.get(_keyCheckedAt);
    if (stamp is! int) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(stamp);
    final now = _now();
    return last.isAfter(now) || now.difference(last) >= _throttle;
  }

  Future<bool> _fetch() =>
      _inFlight ??= _request().whenComplete(() => _inFlight = null);

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

          await _forget();
          return true;
        default:

          return false;
      }
    } catch (_) {

      return false;
    }
  }

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
