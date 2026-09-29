import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'drive_service.dart';
import 'isar_service.dart';
import 'notification_service.dart';

/// SharedPreferences key holding a non-null human-readable string when the
/// background worker last failed because Drive access was revoked or the
/// silent sign-in returned null. Settings UI watches this to show a banner
/// and the user can clear it by signing back in.
const String kAutoBackupErrorKey = 'autoBackupError';

/// Workmanager unique-name for the daily backup task. Re-using the same
/// name with `existingWorkPolicy: replace` makes "schedule" idempotent —
/// toggling Auto Backup off and on again, or re-registering from main()
/// on every cold start, won't queue duplicates.
const String _autoBackupTaskName = 'auto-backup-daily';

/// Target wall-clock time. The worker fires once per day at 00:05 local
/// time (giving the device a few minutes past midnight to settle into the
/// new day before kicking the network). Implemented as a chain of
/// `registerOneOffTask` calls — at the end of each run the worker
/// computes "next 00:05" and re-registers itself.
const int _scheduledHour = 0;
const int _scheduledMinute = 5;

/// Soft de-dupe — the on-app-start runner skips if a backup finished less
/// than this ago. The daily 00:05 worker doesn't need this guard (it only
/// fires once per day) but the foreground catch-up does, so app reopens
/// don't spam Drive.
const Duration _minInterval = Duration(hours: 12);

/// Returns the wall-clock duration from now until the next [_scheduledHour]:
/// [_scheduledMinute] in local time. If that time today has already passed,
/// rolls forward to tomorrow.
Duration _durationUntilNextScheduledTime() {
  final now = DateTime.now();
  var next =
      DateTime(now.year, now.month, now.day, _scheduledHour, _scheduledMinute);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

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
      // A successful foreground backup also clears any "needs attention"
      // flag the worker may have set.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kAutoBackupErrorKey);

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

  /// Schedule the next backup for the upcoming 00:05 local time. Idempotent —
  /// reusing the same uniqueName with `replace` cancels any pending instance
  /// (e.g. user toggled off and on, app re-launched). Android-only.
  ///
  /// Implemented as a one-off + self-rescheduling chain rather than
  /// `registerPeriodicTask` because WorkManager's periodic API can only
  /// promise an *interval* (every 24 h from registration time), not a
  /// specific clock time. The chain pattern lets us land on 00:05 every day
  /// regardless of when Auto Backup was switched on.
  static Future<void> scheduleAutoBackup() async {
    if (!Platform.isAndroid) return;
    try {
      final delay = _durationUntilNextScheduledTime();
      await Workmanager().registerOneOffTask(
        _autoBackupTaskName,
        _autoBackupTaskName,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
      developer.log(
        'scheduled — next at ${DateTime.now().add(delay).toIso8601String()}',
        name: 'AutoBackup',
      );
    } catch (e, st) {
      developer.log('schedule failed',
          name: 'AutoBackup', error: e, stackTrace: st);
    }
  }

  /// Cancel the periodic backup. Called when the user turns off Auto Backup.
  static Future<void> cancelAutoBackup() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().cancelByUniqueName(_autoBackupTaskName);
      developer.log('cancelled', name: 'AutoBackup');
    } catch (e, st) {
      developer.log('cancel failed',
          name: 'AutoBackup', error: e, stackTrace: st);
    }
  }
}

/// Process-scoped singleton. KeepAlive so it survives auto-dispose.
final autoBackupRunnerProvider = Provider<AutoBackupRunner>((ref) {
  return AutoBackupRunner(ref);
});

// ─────────────────────────────────────────────────────────────────────────
// Background isolate entry point.
//
// Workmanager spins up a *separate* Dart isolate to run the dispatcher —
// no Riverpod, no Flutter widgets, no MaterialApp. Anything stateful must
// be re-built here from durable storage (SharedPreferences + Isar on disk).
// ─────────────────────────────────────────────────────────────────────────

/// Top-level entry-point invoked by Workmanager. Must be `vm:entry-point`
/// so AOT compilation doesn't tree-shake it away in release builds.
@pragma('vm:entry-point')
void autoBackupCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return _runBackgroundBackup();
  });
}

Future<bool> _runBackgroundBackup() async {
  developer.log('worker fired', name: 'AutoBackup.worker');

  // Load .env so DriveService can resolve OAuth client IDs (currently used
  // only for documentation, but harmless to load and keeps parity with the
  // foreground path).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {/* missing .env is fine */}

  final prefs = await SharedPreferences.getInstance();

  // Defensive: re-check the user's preference. Worker shouldn't be running
  // if Auto Backup is off, but the schedule could outlive a settings change.
  final autoBackupOn = prefs.getBool('autoBackup') ?? false;
  if (!autoBackupOn) {
    developer.log('worker skipped — autoBackup disabled',
        name: 'AutoBackup.worker');
    return true;
  }

  // Will the worker re-arm itself for tomorrow's 00:05? Default yes; we set
  // this to false only when we hit a revoked-access state, so the chain
  // doesn't spam-fire failures the user can't recover from automatically.
  // The Settings → Drive banner re-arms it after the user signs back in.
  bool rescheduleNext = true;

  Isar? isar;
  try {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      // Must be the app's full schema list — this list used to be a hand-kept
      // copy that had fallen behind (missing TrashEntrySchema).
      kIsarSchemas,
      directory: dir.path,
      name: 'sellerbook_db',
    );

    final drive = DriveService();
    final settingsSnapshot = _exportSettingsFromPrefs(prefs);
    await drive.backupToDrive(
      isar,
      settings: settingsSnapshot,
      interactive: false,
    );

    await prefs.setString(
        'lastBackupTime', DateTime.now().toIso8601String());
    await prefs.remove(kAutoBackupErrorKey);

    developer.log('worker completed', name: 'AutoBackup.worker');
    return true;
  } on DriveBackupException catch (e, st) {
    developer.log('worker failed (drive)',
        name: 'AutoBackup.worker', error: e, stackTrace: st);
    if (e.code == DriveErrorCode.notSignedIn ||
        e.code == DriveErrorCode.signInFailed ||
        e.code == DriveErrorCode.developerError) {
      // These are the failure modes that *won't* recover on their own —
      // tell the user once and stop chaining. The user fixes it via the
      // banner, which calls scheduleAutoBackup() again.
      final alreadyFlagged = prefs.getString(kAutoBackupErrorKey) != null;
      await prefs.setString(kAutoBackupErrorKey, e.message);
      if (!alreadyFlagged) {
        try {
          await NotificationService.showAutoBackupPaused();
        } catch (_) {/* notification failure shouldn't break the worker */}
      }
      rescheduleNext = false;
      return true;
    }
    // Transient (network etc.) — give up this run and try again tomorrow.
    return true;
  } catch (e, st) {
    developer.log('worker failed (other)',
        name: 'AutoBackup.worker', error: e, stackTrace: st);
    return true;
  } finally {
    try {
      await isar?.close();
    } catch (_) {/* ignore */}
    // Re-arm for the next 00:05 unless we're in a fail-loud revoked state.
    // Doing this in `finally` (rather than per-branch) means a thrown
    // exception we didn't anticipate still keeps the chain alive.
    if (rescheduleNext) {
      try {
        await AutoBackupRunner.scheduleAutoBackup();
      } catch (_) {/* schedule failure logged inside */}
    }
  }
}

/// Mirrors `Settings.exportSettings()` but reads raw prefs so it can run
/// in a background isolate (no Riverpod available there). Keys must match
/// `Settings._key*` in `settings_provider.dart`.
Map<String, dynamic> _exportSettingsFromPrefs(SharedPreferences prefs) {
  List<String> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {/* corrupt — fall through */}
    return const [];
  }

  return {
    'shopName': prefs.getString('shopName') ?? 'My Shop',
    'currencySymbol': prefs.getString('currencySymbol') ?? '\$',
    'lowStockThreshold': prefs.getInt('lowStockThreshold') ?? 10,
    'themeMode': prefs.getString('themeMode') ?? 'system',
    'taxRate': prefs.getDouble('taxRate') ?? 0.0,
    'language': prefs.getString('language') ?? 'en',
    'downloadDirectory': prefs.getString('downloadDirectory') ?? '',
    'sidebarOrder': decodeList(prefs.getString('sidebarOrder')),
    'sidebarPosition': prefs.getString('sidebarPosition') ?? 'left',
    'hiddenSidebarItems':
        decodeList(prefs.getString('hiddenSidebarItems')),
    'autoBackup': prefs.getBool('autoBackup') ?? false,
    'securityFingerprintEnabled':
        prefs.getBool('securityFingerprintEnabled') ?? true,
    'securityPinEnabled': prefs.getBool('securityPinEnabled') ?? true,
  };
}
