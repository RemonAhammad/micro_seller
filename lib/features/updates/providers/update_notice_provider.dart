

library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/services/release_update_service.dart';

part 'update_notice_provider.g.dart';

@Riverpod(keepAlive: true)
Future<UpdateChannel> updateChannel(Ref ref) => readUpdateChannel();

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

  Future<void> dismiss() async {
    final update = state.value;
    state = const AsyncData(null);
    if (update == null) return;
    try {
      final service = await ref.read(releaseUpdateServiceProvider.future);
      await service?.snooze(update.tag);
    } catch (_) {

    }
  }

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
