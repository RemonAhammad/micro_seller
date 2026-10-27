/// The update notice's providers: the channel this install updates through,
/// the GitHub release check, and the notice the Dashboard shows.
///
/// Each one catches everything: Riverpod 3 retries a failing provider by
/// itself, which would ask GitHub again and again.
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/services/release_update_service.dart';

part 'update_notice_provider.g.dart';

/// How this install gets its updates: Play's in-app update, the GitHub
/// notice, or none. Tests override it (`UpdateChannel.none`), so they never
/// ask GitHub.
@Riverpod(keepAlive: true)
Future<UpdateChannel> updateChannel(Ref ref) => readUpdateChannel();

/// The GitHub release check, on the github channel only; null elsewhere, or
/// when it couldn't be set up.
@Riverpod(keepAlive: true)
Future<ReleaseUpdateService?> releaseUpdateService(Ref ref) async {
  try {
    final channel = await ref.watch(updateChannelProvider.future);
    if (channel != UpdateChannel.github) return null;
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    if (!ref.mounted) return null;
    final client = http.Client();
    ref.onDispose(client.close);
    return ReleaseUpdateService(
      client: client,
      prefs: prefs,
      installedVersion: info.version,
      platform: defaultTargetPlatform,
    );
  } catch (_) {
    return null;
  }
}

/// The newer release the Dashboard's notice offers, or null. Asks GitHub at
/// most once a day (`ReleaseUpdateService.check`). Never an error.
@Riverpod(keepAlive: true)
class UpdateNotice extends _$UpdateNotice {
  @override
  Future<AvailableUpdate?> build() async {
    try {
      final service = await ref.watch(releaseUpdateServiceProvider.future);
      return await service?.check();
    } catch (_) {
      return null;
    }
  }

  /// Hides the notice, and its release's notice until a newer release
  /// comes out.
  Future<void> dismiss() async {
    final update = state.value;
    state = const AsyncData(null);
    if (update == null) return;
    try {
      final service = await ref.read(releaseUpdateServiceProvider.future);
      await service?.snooze(update.tag);
    } catch (_) {
      // Not remembered: the notice comes back next time.
    }
  }

  /// Settings' "Check for updates": asks GitHub now, whatever the throttle,
  /// offering a dismissed release too, and brings the notice up to date.
  Future<ManualCheck> checkNow() async {
    try {
      final service = await ref.read(releaseUpdateServiceProvider.future);
      if (service == null) return const CheckFailed();
      final result = await service.checkNow();
      if (ref.mounted) state = AsyncData(service.notice);
      return result;
    } catch (_) {
      return const CheckFailed();
    }
  }
}
