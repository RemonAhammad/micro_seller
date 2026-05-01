import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'drive_service.dart';
import 'isar_service.dart';

/// Fires once per app process when:
///   1. The user has enabled the **Auto Backup** toggle in Settings, AND
///   2. They are signed in to Google Drive (we never trigger sign-in
///      ourselves on startup — that would be a UX assault), AND
///   3. The last successful backup was more than [_minInterval] ago (so
///      reopening the app many times in a day doesn't spam Drive).
///
/// Runs on a fire-and-forget basis — never blocks app startup, never
/// shows UI, fails silently and logs via `dart:developer`.
class AutoBackupRunner {
  AutoBackupRunner(this._ref);

  final Ref _ref;

  /// Don't run more often than this. Reset on every successful run by
  /// updating `Settings.lastBackupTime`.
  static const _minInterval = Duration(hours: 12);

  /// Single-flight guard — even if the runner is invoked multiple times
  /// (e.g. settings being toggled and back, hot reloads in dev), we only
  /// execute one backup per process lifetime.
  bool _ranThisProcess = false;

  Future<void> runIfDue() async {
    if (_ranThisProcess) return;
    _ranThisProcess = true;

    try {
      final settings = _ref.read(settingsProvider.notifier);
      if (!settings.autoBackup) {
        developer.log('skipped — disabled', name: 'AutoBackup');
        return;
      }

      final last = settings.lastBackupTime;
      if (last != null && DateTime.now().difference(last) < _minInterval) {
        developer.log(
          'skipped — last run was ${DateTime.now().difference(last).inHours}h ago',
          name: 'AutoBackup',
        );
        return;
      }

      // Only run if a Drive account is already signed in. Triggering the
      // sign-in flow on cold start would be a hostile UX.
      final drive = DriveService();
      final user = await drive.getCurrentUser();
      if (user == null) {
        developer.log('skipped — not signed in to Drive', name: 'AutoBackup');
        return;
      }

      final isar = await _ref.read(isarProvider.future);
      final settingsSnapshot = settings.exportSettings();
      await drive.backupToDrive(isar, settings: settingsSnapshot);
      await settings.updateLastBackupTime(DateTime.now());

      developer.log('completed', name: 'AutoBackup');
      if (kDebugMode) {
        debugPrint('[AutoBackup] completed at ${DateTime.now().toIso8601String()}');
      }
    } catch (e, st) {
      developer.log('failed', name: 'AutoBackup', error: e, stackTrace: st);
      if (kDebugMode) {
        debugPrint('[AutoBackup] failed: $e');
        debugPrintStack(stackTrace: st, label: 'AutoBackup');
      }
      // Reset the single-flight guard on failure so a settings change
      // (toggling auto-backup off/on) can retry without an app restart.
      _ranThisProcess = false;
    }
  }
}

/// Process-scoped singleton. KeepAlive so it survives auto-dispose.
final autoBackupRunnerProvider = Provider<AutoBackupRunner>((ref) {
  return AutoBackupRunner(ref);
});
