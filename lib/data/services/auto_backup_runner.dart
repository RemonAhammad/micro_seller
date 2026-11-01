import 'dart:async';
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

const String kAutoBackupErrorKey = 'autoBackupError';

const String _autoBackupTaskName = 'auto-backup-daily';

const int _scheduledHour = 0;
const int _scheduledMinute = 5;

const Duration _minInterval = Duration(hours: 12);

Duration _durationUntilNextScheduledTime() {
  final now = DateTime.now();
  var next =
      DateTime(now.year, now.month, now.day, _scheduledHour, _scheduledMinute);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

class AutoBackupRunner {

  AutoBackupRunner(this._ref, {DriveService Function()? driveService})
      : _driveService = driveService ?? DriveService.new;

  final Ref _ref;
  final DriveService Function() _driveService;

  static bool get isSupported =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  bool _ranThisProcess = false;

  Future<void> runIfDue() async {
    if (!isSupported) return;
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

      final drive = _driveService();

      if (!await drive.hasDriveAccess()) {
        developer.log('skipped — not signed in to Drive', name: 'AutoBackup');
        return;
      }

      final isar = await _ref.read(isarProvider.future);
      final settingsSnapshot = settings.exportSettings();
      await drive.backupToDrive(isar, settings: settingsSnapshot);
      await settings.updateLastBackupTime(DateTime.now());

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

      _ranThisProcess = false;
    }
  }

  static Future<void> scheduleAutoBackup({bool replace = true}) async {
    if (!Platform.isAndroid) return;
    try {
      final delay = _durationUntilNextScheduledTime();
      await Workmanager().registerOneOffTask(
        _autoBackupTaskName,
        _autoBackupTaskName,
        initialDelay: delay,
        existingWorkPolicy:
            replace ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
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

final autoBackupRunnerProvider = Provider<AutoBackupRunner>((ref) {
  return AutoBackupRunner(ref);
});

@pragma('vm:entry-point')
void autoBackupCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return _runBackgroundBackup();
  });
}

Future<bool> _runBackgroundBackup() async {
  developer.log('worker fired', name: 'AutoBackup.worker');

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();

  final autoBackupOn = prefs.getBool('autoBackup') ?? false;
  if (!autoBackupOn) {
    developer.log('worker skipped — autoBackup disabled',
        name: 'AutoBackup.worker');
    return true;
  }

  bool rescheduleNext = true;

  Isar? isar;
  try {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(

      kIsarSchemas,
      directory: dir.path,
      name: 'sellerbook_db',
    );

    final drive = DriveService();

    final settingsSnapshot = Settings.exportFromPrefs(prefs);
    await drive.backupToDrive(
      isar,
      settings: settingsSnapshot,
      interactive: false,

      encodeOnWorker: false,
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

      final alreadyFlagged = prefs.getString(kAutoBackupErrorKey) != null;
      await prefs.setString(kAutoBackupErrorKey, e.message);
      if (!alreadyFlagged) {
        try {
          await NotificationService.showAutoBackupPaused();
        } catch (_) {}
      }
      rescheduleNext = false;
      return true;
    }

    return true;
  } catch (e, st) {
    developer.log('worker failed (other)',
        name: 'AutoBackup.worker', error: e, stackTrace: st);
    return true;
  } finally {
    try {
      await isar?.close();
    } catch (_) {}

    if (rescheduleNext) {
      try {
        await AutoBackupRunner.scheduleAutoBackup();
      } catch (_) {}
    }
  }
}
