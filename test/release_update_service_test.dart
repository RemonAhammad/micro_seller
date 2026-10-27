// The update notice for the iPhone app and Android APKs installed from
// GitHub: which installs get it, how release versions compare, how often
// GitHub is asked, which releases count, that every failure is silent and
// keeps the last answer, and that nothing it remembers reaches a backup.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:micro_seller/core/constants/app_distribution.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _page = 'https://github.com/RemonAhammad/micro_seller/releases/tag/';

/// GitHub's latest release, as its API answers.
Map<String, Object?> _release({
  String tag = 'v1.0.12',
  bool draft = false,
  bool prerelease = false,
  String? htmlUrl,
  List<String>? files,
}) =>
    {
      'tag_name': tag,
      'name': 'Micro Seller $tag',
      'draft': draft,
      'prerelease': prerelease,
      'html_url': htmlUrl ?? '$_page$tag',
      'assets': [
        for (final name in files ??
            [
              'micro-seller-$tag-universal.apk',
              'micro-seller-$tag-arm64-v8a.apk',
              'micro-seller-$tag-unsigned.ipa',
              'SHA256SUMS.txt',
            ])
          {'name': name, 'browser_download_url': 'https://example.com/$name'},
      ],
    };

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

AppVersion _v(String raw) => AppVersion.tryParse(raw)!;

void main() {
  group('AppVersion', () {
    test('reads a v prefix, spaces, build metadata and a pre-release', () {
      expect(_v('v1.0.12').numbers, [1, 0, 12]);
      expect(_v('V2.3').numbers, [2, 3]);
      expect(_v(' 1.0.12\n').numbers, [1, 0, 12]);
      expect(_v('1.0.11+19').numbers, [1, 0, 11]);
      expect(_v('1.0.11+19').isPreRelease, isFalse);
      expect(_v('v1.0.12-rc.1').preRelease, 'rc.1');
      expect(_v('1.0.12.1').numbers, [1, 0, 12, 1]);
      expect(_v('7').numbers, [7]);
    });

    test('equal versions, whatever their spelling', () {
      expect(_v('v1.0.12').compareTo(_v('1.0.12')), 0);
      expect(_v('1.0').compareTo(_v('1.0.0')), 0);
      expect(_v('1.0.11+19').compareTo(_v('1.0.11+20')), 0);
    });

    test('numbers compare as numbers', () {
      expect(_v('1.0.9') < _v('1.0.10'), isTrue);
      expect(_v('1.1') > _v('1.0.12'), isTrue);
      expect(_v('2.0.0') > _v('1.99.99'), isTrue);
      expect(_v('1.0.12.1') > _v('1.0.12'), isTrue);
      expect(_v('1.0.12') < _v('1.0.12.1'), isTrue);
    });

    test('a pre-release is lower than its stable version', () {
      expect(_v('1.0.12-rc.1') < _v('1.0.12'), isTrue);
      expect(_v('1.0.12-rc.1') > _v('1.0.11'), isTrue);
      expect(_v('1.0.12-rc.2') < _v('1.0.12-rc.10'), isTrue);
      expect(_v('1.0.12-alpha') < _v('1.0.12-beta'), isTrue);
      expect(_v('1.0.12-rc') < _v('1.0.12-rc.1'), isTrue);
      expect(_v('1.0.12-1') < _v('1.0.12-rc'), isTrue);
    });

    test('garbage and numbers too long to hold are not versions', () {
      for (final raw in [
        null,
        '',
        '   ',
        'v',
        'latest',
        '1.',
        '.1',
        '1..2',
        '1.0.x',
        'v-1.0',
        '1.0 beta',
        'version 1.0.12',
        '1.0.12-',
        '1.0.12+',
        '1234567890.0.0',
        '1.0.99999999999999999999',
      ]) {
        expect(AppVersion.tryParse(raw), isNull, reason: '"$raw"');
      }
      // Nine digits still fit.
      expect(_v('999999999.0.1').numbers.first, 999999999);
    });
  });

  group('updateChannelFor', () {
    test('iOS installs get the GitHub notice, whatever iOS reports', () {
      for (final installer in [null, 'com.apple', 'com.android.vending']) {
        expect(
          updateChannelFor(
              platform: TargetPlatform.iOS,
              installerStore: installer,
              isWeb: false),
          UpdateChannel.github,
          reason: '$installer',
        );
      }
    });

    test('Android: Play installs update through Play, the rest from GitHub',
        () {
      expect(
        updateChannelFor(
            platform: TargetPlatform.android,
            installerStore: AppDistribution.playInstaller,
            isWeb: false),
        UpdateChannel.play,
      );
      for (final installer in [
        null,
        'com.google.android.packageinstaller',
        'com.android.packageinstaller',
        'com.android.chrome',
        'org.mozilla.firefox',
      ]) {
        expect(
          updateChannelFor(
              platform: TargetPlatform.android,
              installerStore: installer,
              isWeb: false),
          UpdateChannel.github,
          reason: '$installer',
        );
      }
    });

    test('desktop and the web get none', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          updateChannelFor(
              platform: platform, installerStore: null, isWeb: false),
          UpdateChannel.none,
          reason: platform.name,
        );
      }
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          updateChannelFor(
              platform: platform,
              installerStore: AppDistribution.playInstaller,
              isWeb: true),
          UpdateChannel.none,
          reason: 'web on ${platform.name}',
        );
      }
    });
  });

  group('ReleaseUpdateService', () {
    late SharedPreferences prefs;
    late DateTime now;
    late List<http.Request> requests;

    /// GitHub's answer to the next request.
    late Future<http.Response> Function() github;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 27, 9);
      requests = [];
      github = () async => _json(_release());
    });

    ReleaseUpdateService service({
      String installed = '1.0.11',
      TargetPlatform platform = TargetPlatform.iOS,
      Duration timeout = const Duration(seconds: 10),
    }) =>
        ReleaseUpdateService(
          client: MockClient((request) {
            requests.add(request);
            return github();
          }),
          prefs: prefs,
          installedVersion: installed,
          platform: platform,
          now: () => now,
          timeout: timeout,
        );

    final latest = AvailableUpdate(
      tag: 'v1.0.12',
      url: Uri.parse('${_page}v1.0.12'),
    );

    test('a newer release is offered, by its version without the v',
        () async {
      final update = await service().check();
      expect(update, latest);
      expect(update!.version, '1.0.12');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url, AppDistribution.latestReleaseApi);
      expect(request.headers['Accept'], 'application/vnd.github+json');
      expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
      expect(request.headers['User-Agent'], contains('1.0.11'));
    });

    test('the same or an older release is not offered', () async {
      expect(await service(installed: '1.0.12').check(), isNull);
      now = now.add(const Duration(days: 2));
      expect(await service(installed: '1.0.13').check(), isNull);
      // An iOS rc build reports four numbers (1.0.12.1): above v1.0.12.
      now = now.add(const Duration(days: 2));
      expect(await service(installed: '1.0.12.1').check(), isNull);
      // A version that can't be read is never told it's out of date.
      now = now.add(const Duration(days: 2));
      expect(await service(installed: 'dev').check(), isNull);
      expect(requests, hasLength(4));
    });

    group('throttle', () {
      test('GitHub is asked at most once a day', () async {
        final s = service();
        expect(await s.check(), latest);
        now = now.add(const Duration(hours: 23));
        expect(await s.check(), latest, reason: 'from what it remembers');
        expect(requests, hasLength(1), reason: 'at +23 h');
        now = now.add(const Duration(hours: 2));
        expect(await s.check(), latest);
        expect(requests, hasLength(2), reason: 'at +25 h');
      });

      test('the throttle survives a restart (another service)', () async {
        await service().check();
        now = now.add(const Duration(hours: 1));
        expect(await service().check(), latest);
        expect(requests, hasLength(1));
      });

      test('a clock moved back asks again', () async {
        await service().check();
        now = now.subtract(const Duration(minutes: 5));
        await service().check();
        expect(requests, hasLength(2));
      });

      test('a failed attempt waits for the throttle too', () async {
        github = () async => http.Response('', 500);
        final s = service();
        expect(await s.check(), isNull);
        expect(await s.check(), isNull);
        expect(requests, hasLength(1));
      });

      test('two checks at the same time share one request', () async {
        final answer = Completer<http.Response>();
        github = () => answer.future;
        final s = service();
        final first = s.check();
        final second = s.check();
        final manual = s.checkNow();
        answer.complete(_json(_release()));
        expect(await first, latest);
        expect(await second, latest);
        expect(await manual, isA<Available>());
        expect(requests, hasLength(1));
      });
    });

    group('snooze', () {
      test('hides only that version; a newer one shows', () async {
        final s = service();
        expect(await s.check(), latest);
        await s.snooze('v1.0.12');
        expect(s.notice, isNull);
        now = now.add(const Duration(days: 2));
        expect(await service().check(), isNull, reason: 'after a restart');

        github = () async => _json(_release(tag: 'v1.0.13'));
        now = now.add(const Duration(days: 2));
        final newer = await service().check();
        expect(newer?.tag, 'v1.0.13');
      });

      test('the manual check offers a dismissed release', () async {
        final s = service();
        await s.check();
        await s.snooze('v1.0.12');
        final result = await s.checkNow();
        expect(result, isA<Available>());
        expect((result as Available).update, latest);
        expect(requests, hasLength(2), reason: 'whatever the throttle');
        expect(s.notice, isNull, reason: 'the notice stays dismissed');
      });
    });

    group('silent failures keep the last answer', () {
      final failures = <String, Future<http.Response> Function()>{
        'a rate-limited 403': () async => _json(
            {'message': 'API rate limit exceeded'}, HttpStatus.forbidden),
        '429': () async => http.Response('', HttpStatus.tooManyRequests),
        '500': () async => http.Response('', HttpStatus.internalServerError),
        '503': () async => http.Response('', HttpStatus.serviceUnavailable),
        'no connection': () async =>
            throw const SocketException('Failed host lookup'),
        'a client error': () async => throw http.ClientException('reset'),
        'bad JSON': () async => http.Response('<html>oops</html>', 200),
        'JSON that is not a release': () async => _json([1, 2, 3]),
        'a timeout': () => Completer<http.Response>().future,
      };

      for (final MapEntry(key: what, value: failure) in failures.entries) {
        test(what, () async {
          expect(await service().check(), latest);
          now = now.add(const Duration(days: 2));
          github = failure;
          final s = service(timeout: const Duration(milliseconds: 10));
          expect(await s.check(), latest, reason: 'served offline');
          final manual = await s.checkNow();
          expect(manual, isA<Available>(), reason: 'from what it remembers');
          expect(requests, hasLength(3));
        });

        test('$what, with nothing remembered', () async {
          github = failure;
          final s = service(timeout: const Duration(milliseconds: 10));
          expect(await s.check(), isNull);
          expect(await s.checkNow(), isA<CheckFailed>());
        });
      }

      test('a 404 (no release) forgets the last one', () async {
        expect(await service().check(), latest);
        now = now.add(const Duration(days: 2));
        github = () async => _json({'message': 'Not Found'}, 404);
        final s = service();
        expect(await s.check(), isNull);
        expect(await s.checkNow(), isA<UpToDate>());
      });
    });

    group('which releases count', () {
      Future<AvailableUpdate?> offered(Map<String, Object?> release,
          {TargetPlatform platform = TargetPlatform.iOS}) async {
        // Remember v1.0.12 first: a release that doesn't count forgets it.
        github = () async => _json(_release());
        await service(platform: platform).check();
        now = now.add(const Duration(days: 2));
        github = () async => _json(release);
        return service(platform: platform).check();
      }

      test('not a draft', () async {
        expect(await offered(_release(tag: 'v1.0.13', draft: true)), isNull);
      });

      test('not a pre-release, flagged or by its tag', () async {
        expect(
            await offered(_release(tag: 'v1.0.13', prerelease: true)), isNull);
        expect(await offered(_release(tag: 'v1.0.13-rc.1')), isNull);
      });

      test('a tag that reads as a version', () async {
        expect(await offered(_release(tag: 'nightly')), isNull);
        expect(await offered({..._release(), 'tag_name': null}), isNull);
      });

      test("carrying this platform's file", () async {
        final apkOnly = _release(tag: 'v1.0.13', files: [
          'micro-seller-v1.0.13-universal.apk',
          'micro-seller-v1.0.13-arm64-v8a.apk',
        ]);
        expect(await offered(apkOnly), isNull, reason: 'no .ipa for iOS');
        expect(
          (await offered(apkOnly, platform: TargetPlatform.android))?.tag,
          'v1.0.13',
        );
        final ipaOnly = _release(
            tag: 'v1.0.13', files: ['micro-seller-v1.0.13-unsigned.IPA']);
        expect((await offered(ipaOnly))?.tag, 'v1.0.13');
        expect(await offered(ipaOnly, platform: TargetPlatform.android),
            isNull,
            reason: 'no .apk for Android');
        expect(await offered({..._release(), 'assets': null}), isNull);
      });

      test('a page outside this repository is replaced by its releases',
          () async {
        for (final page in [
          'https://evil.example.com/RemonAhammad/micro_seller/releases/tag/v1.0.13',
          'https://github.com/someone/micro_seller/releases/tag/v1.0.13',
          'http://github.com/RemonAhammad/micro_seller/releases/tag/v1.0.13',
          'https://github.com/RemonAhammad/micro_seller/releasesX',
        ]) {
          final update =
              await offered(_release(tag: 'v1.0.13', htmlUrl: page));
          expect(update?.tag, 'v1.0.13', reason: page);
          expect(update?.url, AppDistribution.releasesPage, reason: page);
        }
      });
    });

    test('nothing it remembers reaches a backup', () async {
      final s = service();
      await s.check();
      await s.snooze('v1.0.12');
      expect(
        prefs.getKeys(),
        containsAll(<String>[
          'update_notice_checked_at',
          'update_notice_latest_tag',
          'update_notice_latest_url',
          'update_notice_snoozed_tag',
        ]),
      );
      final exported = Settings.exportFromPrefs(prefs);
      expect(exported.keys.where((k) => k.startsWith('update_notice')),
          isEmpty);
      expect(jsonEncode(exported), isNot(contains('v1.0.12')));
    });
  });

  group('providers', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    void installedFrom(String? installer) => PackageInfo.setMockInitialValues(
          appName: 'Micro Seller',
          packageName: 'com.blackshadowsoftware.micro_seller',
          version: '1.0.11',
          buildNumber: '19',
          buildSignature: '',
          installerStore: installer,
        );

    Future<UpdateChannel> channelOn(TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container.read(updateChannelProvider.future);
    }

    test('the channel follows the platform and the installer', () async {
      installedFrom(AppDistribution.playInstaller);
      expect(await channelOn(TargetPlatform.android), UpdateChannel.play);
      expect(await channelOn(TargetPlatform.iOS), UpdateChannel.github);
      expect(await channelOn(TargetPlatform.macOS), UpdateChannel.none);
      installedFrom(null);
      expect(await channelOn(TargetPlatform.android), UpdateChannel.github);
      installedFrom('com.google.android.packageinstaller');
      expect(await channelOn(TargetPlatform.android), UpdateChannel.github);
    });

    test('the release check exists on the github channel only', () async {
      SharedPreferences.setMockInitialValues({});
      installedFrom(null);
      for (final channel in UpdateChannel.values) {
        final container = ProviderContainer(overrides: [
          updateChannelProvider.overrideWithValue(AsyncData(channel)),
        ]);
        addTearDown(container.dispose);
        final service =
            await container.read(releaseUpdateServiceProvider.future);
        expect(service != null, channel == UpdateChannel.github,
            reason: channel.name);
      }
    });

    group('UpdateNotice', () {
      late SharedPreferences prefs;
      late int requests;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
        requests = 0;
      });

      ProviderContainer app() {
        final container = ProviderContainer(overrides: [
          updateChannelProvider
              .overrideWithValue(const AsyncData(UpdateChannel.github)),
          releaseUpdateServiceProvider.overrideWith((ref) async {
            return ReleaseUpdateService(
              client: MockClient((_) async {
                requests++;
                return _json(_release());
              }),
              prefs: prefs,
              installedVersion: '1.0.11',
              platform: TargetPlatform.iOS,
            );
          }),
        ]);
        addTearDown(container.dispose);
        return container;
      }

      test('offers the newer release; dismissing it snoozes it', () async {
        final container = app();
        final update = await container.read(updateNoticeProvider.future);
        expect(update?.tag, 'v1.0.12');

        await container.read(updateNoticeProvider.notifier).dismiss();
        expect(container.read(updateNoticeProvider).value, isNull);
        expect(prefs.getString('update_notice_snoozed_tag'), 'v1.0.12');

        // A restart: still dismissed, and no new request within the day.
        expect(await app().read(updateNoticeProvider.future), isNull);
        expect(requests, 1);
      });

      test('the manual check asks now and refreshes the notice', () async {
        final container = app();
        await container.read(updateNoticeProvider.future);
        final notice = container.read(updateNoticeProvider.notifier);
        await notice.dismiss();

        final result = await notice.checkNow();
        expect(result, isA<Available>());
        expect(requests, 2);
        // Dismissed stays dismissed on the Dashboard.
        expect(container.read(updateNoticeProvider).value, isNull);
      });

      test('never an error, and no retries', () async {
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            updateChannelProvider
                .overrideWithValue(const AsyncData(UpdateChannel.github)),
            releaseUpdateServiceProvider
                .overrideWith((ref) async => throw StateError('broken')),
          ],
        );
        addTearDown(container.dispose);
        expect(await container.read(updateNoticeProvider.future), isNull);
        expect(container.read(updateNoticeProvider).hasError, isFalse);
        final notice = container.read(updateNoticeProvider.notifier);
        expect(await notice.checkNow(), isA<CheckFailed>());
        await notice.dismiss();
      });

      test('the play and none channels make no request', () async {
        for (final channel in [UpdateChannel.play, UpdateChannel.none]) {
          final container = ProviderContainer(overrides: [
            updateChannelProvider.overrideWithValue(AsyncData(channel)),
          ]);
          addTearDown(container.dispose);
          expect(await container.read(updateNoticeProvider.future), isNull);
          expect(
            await container.read(updateNoticeProvider.notifier).checkNow(),
            isA<CheckFailed>(),
          );
        }
        expect(prefs.getKeys(), isEmpty);
      });
    });
  });
}
