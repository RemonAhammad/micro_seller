import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/display_scale_provider.dart';
import '../providers/settings_provider.dart';
import 'color_theme_screen.dart';
import 'widgets/display_size_sheets.dart';
import '../../../data/services/auto_backup_runner.dart';
import '../../../data/services/drive_service.dart';
import '../../../data/services/local_backup_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_color_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/dynamic_color_support.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/auth_gate.dart';
import '../../../shared/widgets/app_zoom.dart';
import '../../../shared/widgets/pdf_saved_sheet.dart';
import '../../../data/services/auth_gate_service.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../data/services/review_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.driveService});

  /// Replaces the Google Drive service, so a test can list backups without
  /// signing in. The app passes none.
  @visibleForTesting
  final DriveService? driveService;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  late final _driveService = widget.driveService ?? DriveService();
  final _localBackupService = LocalBackupService();
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLocalExporting = false;
  bool _isLocalImporting = false;
  String? _googleAccountEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccount();
    // The auto-backup worker writes `autoBackupError` to SharedPreferences
    // from a separate isolate, so the in-memory provider state can be stale
    // when this screen builds. Pull it once on entry.
    ref.read(settingsProvider.notifier).refreshAutoBackupError();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the app after the worker fired in the background should
    // surface the banner without requiring a navigation away and back.
    if (state == AppLifecycleState.resumed) {
      ref.read(settingsProvider.notifier).refreshAutoBackupError();
    }
  }

  Future<void> _loadAccount() async {
    final account = await _driveService.getCurrentUser();
    if (mounted) {
      setState(() => _googleAccountEmail = account?.email);
    }
  }

  /// [e] in the app's language. The exception's own message is English
  /// detail for the log (_logFailure), never shown.
  String _driveErrorMessage(DriveBackupException e) {
    final s = AppStrings.of(context);
    switch (e.code) {
      case DriveErrorCode.notSignedIn:
        return s.driveErrorNotSignedIn;
      case DriveErrorCode.signInCancelled:
        return s.driveErrorSignInCancelled;
      case DriveErrorCode.signInFailed:
        return s.driveErrorSignInFailed;
      case DriveErrorCode.developerError:
        return s.driveErrorNotConfigured;
      case DriveErrorCode.network:
        return s.driveErrorNetwork;
      case DriveErrorCode.uploadFailed:
        return s.driveErrorUploadFailed;
      case DriveErrorCode.downloadFailed:
        return s.driveErrorDownloadFailed;
      case DriveErrorCode.invalidBackup:
        return s.driveErrorInvalidBackup;
      case DriveErrorCode.rolledBack:
        return s.driveErrorRolledBack;
      case DriveErrorCode.restoreFailed:
        return s.driveErrorRestoreFailed;
      case DriveErrorCode.unknown:
        return s.errorOccurred;
    }
  }

  /// Shows [e] as a red snackbar: [_driveErrorMessage], and on iOS, when
  /// Google sign-in failed, a hint that a sideloaded install may not be able
  /// to sign in. AltStore, SideStore or Sideloadly can re-sign the app under
  /// another app ID, which the app's iOS OAuth client doesn't know; Local
  /// Backup works there.
  void _showDriveError(DriveBackupException e) {
    final message = _driveErrorMessage(e);
    final signInFailed = e.code == DriveErrorCode.signInFailed ||
        e.code == DriveErrorCode.developerError;
    final iosApp = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final hint = signInFailed && iosApp
        ? AppStrings.of(context).googleSignInSideloadHint(AppStrings.appName)
        : null;
    ScaffoldMessenger.of(context).showSnackBar(
      hint == null
          ? SnackBar(content: Text(message), backgroundColor: Colors.red)
          : SnackBar(
              content: Text('$message\n$hint'),
              backgroundColor: Colors.red,
              // Two messages to read.
              duration: const Duration(seconds: 8),
            ),
    );
  }

  void _logFailure(String tag, Object error, StackTrace stack) {
    developer.log(tag, name: 'SettingsScreen', error: error, stackTrace: stack);
    if (kDebugMode) {
      debugPrint('[SettingsScreen] $tag: $error');
      debugPrintStack(stackTrace: stack, label: 'SettingsScreen.$tag');
    }
  }

  Future<void> _backup() async {
    setState(() => _isBackingUp = true);
    try {
      final isar = await ref.read(isarProvider.future);
      final settingsSnapshot = ref.read(settingsProvider.notifier).exportSettings();
      await _driveService.backupToDrive(isar, settings: settingsSnapshot);
      ref.read(settingsProvider.notifier).updateLastBackupTime(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).backupSuccess), backgroundColor: Colors.green));
      }
    } on DriveBackupException catch (e, st) {
      _logFailure('backup', e, st);
      if (mounted) _showDriveError(e);
    } catch (e, st) {
      _logFailure('backup.unexpected', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    try {
      final backups = await _driveService.listBackups();
      if (!mounted) return;

      if (backups.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).tr('noBackupsFound'))));
        return;
      }

      final selected = await showModalBottomSheet<DriveBackupInfo>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _BackupPickerSheet(backups: backups),
      );

      if (selected == null || !mounted) return;

      final confirmed = await ConfirmDialog.show(
        context,
        title: AppStrings.of(context).tr('restoreData'),
        message: AppStrings.of(context).tr('restoreDataConfirm'),
        confirmText: AppStrings.of(context).restoreFromDrive,
        isDestructive: true,
        icon: tabler.Restore.new,
      );

      if (confirmed != true || !mounted) return;

      final isar = await ref.read(isarProvider.future);
      await _driveService.restoreFromDrive(
        isar,
        selected.fileId,
        currentSettings: ref.read(settingsProvider.notifier).exportSettings(),
        onSettingsRestored: (map) => ref.read(settingsProvider.notifier).importSettings(map),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).restoreSuccess), backgroundColor: Colors.green));
      }
    } on DriveBackupException catch (e, st) {
      _logFailure('restore', e, st);
      if (mounted) _showDriveError(e);
    } catch (e, st) {
      _logFailure('restore.unexpected', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  /// Verifies fingerprint only. Used when the user toggles the fingerprint
  /// switch — separate from PIN. Returns true if there's nothing to verify
  /// against (fingerprint isn't currently active) or biometric succeeds.
  Future<bool> _verifyFingerprint(String reason) async {
    final settings = ref.read(settingsProvider.notifier);
    if (!settings.securityFingerprintEnabled) return true;
    final svc = AuthGateService();
    if (!await svc.isBiometricAvailable()) return true;
    if (!mounted) return false;
    return runAuthGate(
      context,
      reason: reason,
      fingerprintEnabled: true,
      pinEnabled: false,
      service: svc,
    );
  }

  /// Verifies PIN only. Used when the user toggles the PIN switch — separate
  /// from fingerprint. Returns true if there's no stored PIN to verify.
  Future<bool> _verifyPin(String reason) async {
    final settings = ref.read(settingsProvider.notifier);
    if (!settings.securityPinEnabled) return true;
    final svc = AuthGateService();
    if (!await svc.hasPin()) return true;
    if (!mounted) return false;
    return runAuthGate(
      context,
      reason: reason,
      fingerprintEnabled: false,
      pinEnabled: true,
      service: svc,
    );
  }

  Future<void> _toggleFingerprint(bool target) async {
    final s = AppStrings.of(context);
    final passed = await _verifyFingerprint(s.tr('changeSecurity'));
    if (!passed || !mounted) return;
    await ref
        .read(settingsProvider.notifier)
        .updateSecurityFingerprintEnabled(target);
  }

  Future<void> _togglePin(bool target) async {
    final s = AppStrings.of(context);
    final passed = await _verifyPin(s.tr('changeSecurity'));
    if (!passed || !mounted) return;
    final svc = AuthGateService();
    if (target) {
      // Enable: force a fresh PIN setup so we know one exists going forward.
      final ok = await runPinSetup(
        context,
        reason: s.tr('createPin'),
        service: svc,
      );
      if (!ok || !mounted) return;
      await ref.read(settingsProvider.notifier).updateSecurityPinEnabled(true);
    } else {
      // Disable: clear the stored PIN so re-enabling forces a fresh setup.
      await svc.clearPin();
      await ref.read(settingsProvider.notifier).updateSecurityPinEnabled(false);
    }
  }

  Future<void> _clearData() async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.of(context).clearAllData,
      message: AppStrings.of(context).clearDataConfirmation,
      confirmText: AppStrings.of(context).clearAllData,
      isDestructive: true,
      icon: tabler.AlertTriangle.new,
    );
    if (ok != true || !mounted) return;

    // Security gate: biometric prompt if available, otherwise a 4-digit PIN
    // (set up on first use). User must pass before any data is wiped.
    final settings = ref.read(settingsProvider.notifier);
    final passed = await runAuthGate(
      context,
      reason: AppStrings.of(context).clearAllData,
      fingerprintEnabled: settings.securityFingerprintEnabled,
      pinEnabled: settings.securityPinEnabled,
    );
    if (!passed || !mounted) return;

    final isar = await ref.read(isarProvider.future);
    // "Clear all" has to mean all: every collection, the recycle bin
    // included (leaving it would both retain data the user asked to wipe and
    // leave entries pointing at ids that no longer exist). The same clear as
    // a restore, in one transaction on a worker isolate.
    await _localBackupService.clearAll(isar);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).allDataCleared)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme: Light / Dark / System, and the color theme.
          _SectionHeader(s.theme),
          _SettingsCard(
            children: [
              _ThemeModeSelector(
                currentMode: ref.read(settingsProvider.notifier).themeMode,
                onChanged: (mode) => ref.read(settingsProvider.notifier).updateThemeMode(mode),
              ),
              const Divider(height: 1),
              const _ColorThemeTile(),
            ],
          ),
          const SizedBox(height: 16),

          // Display — Display size (whole-app zoom) and Text size. Per
          // device, so never part of a backup (displayScaleProvider).
          _SectionHeader(s.display),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ThinIcon(tabler.ZoomIn.new, color: brand.primary, size: 20),
                ),
                title: Text(s.displaySize),
                subtitle: const _DisplaySizeValue(),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => showDisplaySizeSheet(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ThinIcon(tabler.TextSize.new, color: brand.primary, size: 20),
                ),
                title: Text(s.textSize),
                subtitle: const _TextSizeValue(),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => showTextSizeSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Language
          _SectionHeader(s.language),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ThinIcon(tabler.Language.new, color: brand.primary, size: 20),
                ),
                title: Text(s.language),
                subtitle: Text(
                  AppLocalizations.languageNames[ref.read(settingsProvider.notifier).language] ?? 'English',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () async {
                  final currentLang = ref.read(settingsProvider.notifier).language;
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (_) => _LanguagePickerSheet(currentCode: currentLang),
                  );
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).updateLanguage(selected);
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sidebar customization
          _SectionHeader(s.sidebar),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ThinIcon(tabler.LayoutSidebar.new, color: brand.primary, size: 20),
                ),
                title: Text(s.sidebarOrder),
                subtitle: Text(
                  s.sidebarOrderDesc,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => context.push('/settings/sidebar-order'),
              ),
              const Divider(height: 1, indent: 56),
              Builder(
                builder: (_) {
                  final currentPos = ref.read(settingsProvider.notifier).sidebarPosition;
                  final isLeft = currentPos == Settings.sidebarPositionLeft;
                  return _EndControl(
                    tile: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: brand.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ThinIcon(tabler.ArrowsExchange.new, color: brand.primary, size: 20),
                      ),
                      title: Text(s.sidebarPosition),
                    ),
                    control: _SidebarPositionToggle(
                      isLeft: isLeft,
                      onChanged: (toLeft) async {
                        if (toLeft == isLeft) return;
                        await ref
                            .read(settingsProvider.notifier)
                            .updateSidebarPosition(
                              toLeft ? Settings.sidebarPositionLeft : Settings.sidebarPositionRight,
                            );
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
          const SizedBox(height: 16),

          // Shop
          _SectionHeader(s.shop),
          _SettingsCard(
            children: [
              _EditableTile(
                icon: tabler.BuildingStore.new,
                label: s.shopName,
                value: ref.read(settingsProvider.notifier).shopName,
                onEdit: (val) => ref.read(settingsProvider.notifier).updateShopName(val),
              ),
              const Divider(height: 1),
              // Printed on the shared product catalog so buyers know where to
              // order from. Optional — blank simply omits the line.
              _EditableTile(
                icon: tabler.Phone.new,
                label: s.shopPhone,
                value: ref.read(settingsProvider.notifier).shopPhone,
                onEdit: (val) =>
                    ref.read(settingsProvider.notifier).updateShopPhone(val),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ThinIcon(tabler.CurrencyDollar.new, color: brand.primary, size: 20),
                ),
                title: Text(s.currencySymbol),
                subtitle: Text(
                  ref.read(settingsProvider.notifier).currencySymbol,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () async {
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (_) =>
                        _CurrencyPickerSheet(currentSymbol: ref.read(settingsProvider.notifier).currencySymbol),
                  );
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).updateCurrencySymbol(selected);
                    setState(() {});
                  }
                },
              ),
              const Divider(height: 1),
              _EditableTile(
                icon: tabler.Package.new,
                label: s.defaultLowStockThreshold,
                value: ref.read(settingsProvider.notifier).lowStockThreshold.toString(),
                onEdit: (val) {
                  final n = int.tryParse(val);
                  if (n != null) {
                    ref.read(settingsProvider.notifier).updateLowStockThreshold(n);
                  }
                },
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const Divider(height: 1),
              _EditableTile(
                icon: tabler.Percentage.new,
                label: s.taxRate,
                value: ref.read(settingsProvider.notifier).taxRate.toString(),
                onEdit: (val) {
                  final rate = double.tryParse(val);
                  if (rate != null) {
                    ref.read(settingsProvider.notifier).updateTaxRate(rate);
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Downloads. Not on iOS, where Download PDF asks where to save
          // each time (pdfDownloadAsksWhereToSave).
          if (!pdfDownloadAsksWhereToSave) ...[
            _SectionHeader(s.downloads),
            _SettingsCard(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: brand.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ThinIcon(tabler.Folder.new, color: brand.primary, size: 20),
                  ),
                  title: Text(s.pdfDownloadFolder),
                  subtitle: Text(
                    ref.read(settingsProvider.notifier).downloadDirectory.isEmpty
                        ? s.tr('notSetWillAsk')
                        : ref.read(settingsProvider.notifier).downloadDirectory,
                    style: TextStyle(
                      fontSize: 12,
                      color: ref.read(settingsProvider.notifier).downloadDirectory.isEmpty
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const ThinIcon(tabler.Pencil.new, size: 18),
                  onTap: () async {
                    final dir = await FilePicker.getDirectoryPath();
                    if (dir != null) {
                      ref.read(settingsProvider.notifier).updateDownloadDirectory(dir);
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Recycle Bin — deleted records, recoverable for 30 days.
          _SectionHeader(s.recycleBin),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const ThinIcon(tabler.Trash.new,
                      color: Colors.blueGrey, size: 20),
                ),
                title: Text(s.recycleBin),
                subtitle: Text(
                  s.recycleBinRetentionNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: () => context.push('/settings/recycle-bin'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Local Backup
          _SectionHeader(s.localBackup),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isLocalExporting
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                      : const ThinIcon(tabler.FileUpload.new, color: Colors.blue, size: 20),
                ),
                title: Text(s.exportBackup),
                subtitle: Text(s.exportBackupDesc, style: TextStyle(fontSize: 12)),
                onTap: _isLocalExporting
                    ? null
                    : () async {
                        setState(() => _isLocalExporting = true);
                        try {
                          final isar = await ref.read(isarProvider.future);
                          final settingsSnapshot = ref.read(settingsProvider.notifier).exportSettings();
                          await _localBackupService.exportBackup(isar, settings: settingsSnapshot);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${s.tr("exportFailed")}: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLocalExporting = false);
                          }
                        }
                      },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isLocalImporting
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                      : const ThinIcon(tabler.Download.new, color: Colors.orange, size: 20),
                ),
                title: Text(s.importBackup),
                subtitle: Text(s.importBackupDesc, style: const TextStyle(fontSize: 12)),
                onTap: _isLocalImporting
                    ? null
                    : () async {
                        final ok = await ConfirmDialog.show(
                          context,
                          title: s.importBackup,
                          message: s.importBackupConfirm,
                          confirmText: s.importBackup,
                          isDestructive: true,
                          icon: tabler.AlertTriangle.new,
                        );
                        if (ok != true) return;
                        setState(() => _isLocalImporting = true);
                        try {
                          final isar = await ref.read(isarProvider.future);
                          final restoredSettings = await _localBackupService.importBackup(isar);
                          // null = user cancelled the picker; non-null map (even
                          // empty) = backup was decoded successfully.
                          final success = restoredSettings != null;
                          if (success) {
                            await ref.read(settingsProvider.notifier).importSettings(restoredSettings);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? s.tr('dataRestoredSuccess') : s.tr('noFileSelected')),
                                backgroundColor: success ? Colors.green : null,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${s.tr("importFailed")}: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLocalImporting = false);
                          }
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Google Drive. iOS has no Auto Backup, so no paused banner and no
          // switch there (AutoBackupRunner.isSupported).
          _SectionHeader(s.googleDriveBackup),
          if (AutoBackupRunner.isSupported &&
              ref.watch(settingsProvider)['autoBackupError'] != null)
            _AutoBackupErrorBanner(
              message: ref
                      .watch(settingsProvider)['autoBackupError']
                      as String? ??
                  '',
              onSignIn: () async {
                try {
                  // Interactive sign-in — re-issues the OAuth grant.
                  final user = await _driveService.signIn();
                  if (user == null) return; // user cancelled
                  await ref
                      .read(settingsProvider.notifier)
                      .clearAutoBackupError();
                  // Re-schedule so the next backup attempt runs soon.
                  await AutoBackupRunner.scheduleAutoBackup();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(s.tr('autoBackupResumed')),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${s.tr('signInFailed')}: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              onDismiss: () => ref
                  .read(settingsProvider.notifier)
                  .clearAutoBackupError(),
            ),
          _SettingsCard(
            children: [
              _EndControl(
                tile: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: brand.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ThinIcon(tabler.UserCircle.new, color: brand.primary, size: 20),
                  ),
                  title: Text(s.googleAccount),
                  subtitle: Text(
                    _googleAccountEmail ?? s.signIn,
                    style: TextStyle(
                      color: _googleAccountEmail != null
                          ? brand.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                control: TextButton(
                  onPressed: () async {
                    if (_googleAccountEmail != null) {
                      await _driveService.signOut();
                      setState(() => _googleAccountEmail = null);
                    } else {
                      try {
                        final account = await _driveService.signIn();
                        if (!mounted) return;
                        setState(() => _googleAccountEmail = account?.email);
                      } on DriveBackupException catch (e, st) {
                        // A failure used to escape the button unseen.
                        _logFailure('signIn', e, st);
                        if (mounted) _showDriveError(e);
                      }
                    }
                  },
                  child: Text(_googleAccountEmail != null ? s.signOut : s.signIn),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isBackingUp
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                      : const ThinIcon(tabler.CloudUpload.new, color: Colors.blue, size: 20),
                ),
                title: Text(s.backupToDrive),
                subtitle: ref.read(settingsProvider.notifier).lastBackupTime != null
                    ? Text(
                        '${s.lastBackup}: ${DateFormatter.format(ref.read(settingsProvider.notifier).lastBackupTime)}',
                      )
                    : null,
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: _isBackingUp ? null : _backup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isRestoring
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                      : const ThinIcon(tabler.CloudDownload.new, color: Colors.green, size: 20),
                ),
                title: Text(s.restoreFromDrive),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                onTap: _isRestoring ? null : _restore,
              ),
              // Not on iOS (AutoBackupRunner.isSupported).
              if (AutoBackupRunner.isSupported) ...[
                const Divider(height: 1),
                // Auto-backup switch — when enabled and the user is signed
                // into Drive, AutoBackupRunner kicks off a backup on app
                // startup (throttled to ≥12h between runs).
                SwitchListTile(
                  secondary: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const ThinIcon(tabler.Refresh.new,
                        color: Colors.indigo, size: 20),
                  ),
                  title: Text(s.tr('autoBackup')),
                  subtitle: Text(
                    s.tr('autoBackupDesc'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  value: ref.watch(settingsProvider)['autoBackup'] as bool? ??
                      false,
                  onChanged: (v) async {
                    await ref
                        .read(settingsProvider.notifier)
                        .updateAutoBackup(v);
                    // Schedule / cancel the WorkManager periodic worker so
                    // background backups follow the toggle. No-op on
                    // desktop — the helpers already early-return there.
                    if (v) {
                      await AutoBackupRunner.scheduleAutoBackup();
                    } else {
                      await AutoBackupRunner.cancelAutoBackup();
                      // Clearing the error too: with auto-backup off the
                      // banner is meaningless.
                      await ref
                          .read(settingsProvider.notifier)
                          .clearAutoBackupError();
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // About
          _SectionHeader(s.about),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ThinIcon(tabler.Star.new, color: Colors.amber.shade700, size: 20),
                ),
                title: Text(s.rateThisApp),
                subtitle: Text(s.rateThisAppSubtitle(AppStrings.appName)),
                trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
                // The tap is already an opt-in, so skip the gate dialog.
                onTap: () async {
                  await ReviewService.requestReview();
                  await ReviewService.markRated();
                },
              ),
              const Divider(height: 1, indent: 56),
              _EndControl(
                tile: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: brand.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ThinIcon(tabler.InfoCircle.new, color: brand.primary, size: 20),
                  ),
                  title: Text(s.appVersion),
                ),
                // Was a hardcoded '1.0.0' — read the real version + build.
                control: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Text(
                    snap.hasData
                        ? '${snap.data!.version} (${snap.data!.buildNumber})'
                        : '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Security — each row is visibility-gated by its `.env` flag.
          // ENABLE_FINGERPRINT_GATE / ENABLE_PIN_GATE control whether the
          // toggle is shown at all; user setting controls whether that path
          // is active. Section is hidden entirely when both .env flags off.
          if (isFingerprintFeatureEnabled || isPinFeatureEnabled) ...[
            _SectionHeader(s.tr('security')),
            _SettingsCard(
              children: [
                if (isFingerprintFeatureEnabled)
                  FutureBuilder<bool>(
                    future: AuthGateService().isBiometricAvailable(),
                    builder: (context, snapshot) {
                      final available = snapshot.data ?? false;
                      return SwitchListTile(
                        secondary: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: brand.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ThinIcon(
                            tabler.Fingerprint.new,
                            color: available
                                ? brand.primary
                                : theme.colorScheme.onSurface.withOpacity(0.4),
                            size: 20,
                          ),
                        ),
                        title: Text(s.tr('securityFingerprint')),
                        subtitle: Text(
                          available
                              ? s.tr('securityFingerprintDesc')
                              : s.tr('biometricNotAvailable'),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                        value: available &&
                            ref
                                .watch(settingsProvider.notifier)
                                .securityFingerprintEnabled,
                        onChanged: available
                            ? (v) => _toggleFingerprint(v)
                            : null,
                      );
                    },
                  ),
                if (isFingerprintFeatureEnabled && isPinFeatureEnabled)
                  const Divider(height: 1),
                if (isPinFeatureEnabled)
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: brand.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ThinIcon(tabler.Password.new,
                          color: brand.primary, size: 20),
                    ),
                    title: Text(s.tr('securityPin')),
                    subtitle: Text(
                      s.tr('securityPinDesc'),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    value: ref
                        .watch(settingsProvider.notifier)
                        .securityPinEnabled,
                    onChanged: (v) => _togglePin(v),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Danger zone
          _SectionHeader(s.dangerZone),
          _SettingsCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const ThinIcon(tabler.TrashX.new, color: Colors.red, size: 20),
                ),
                title: Text(s.clearAllData, style: const TextStyle(color: Colors.red)),
                onTap: _clearData,
                trailing: const ThinIcon(tabler.ChevronRight.new, color: Colors.red, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Compact two-icon segmented toggle for picking sidebar Left vs Right.
/// Each side is a 36×32 rounded square; the active one fills with the
/// primary colour, the other ghosts to onSurface-medium. Tapping the
/// inactive side flips. Designed to fit at the end of a Settings row
/// ([_EndControl]) without pushing the title onto a second line.
class _SidebarPositionToggle extends StatelessWidget {
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _SidebarPositionToggle({required this.isLeft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(cs, icon: tabler.LayoutSidebar.new, active: isLeft, onTap: () => onChanged(true)),
          _segment(cs, icon: tabler.LayoutSidebarRight.new, active: !isLeft, onTap: () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(ColorScheme cs, {required ThinIconBuilder icon, required bool active, required VoidCallback onTap}) {
    return Material(
      color: active ? cs.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 30,
          // Centered: the box's tight size would stretch the icon to fill it.
          child: Center(
            child: ThinIcon(icon, size: 18, color: active ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.55)),
          ),
        ),
      ),
    );
  }
}

/// Settings → Display size's value: the size in effect, which a narrow
/// window can hold below the saved one. A widget of its own because
/// AppZoomScope also changes with the window's MediaQuery (on every keyboard
/// frame), and only this text needs to rebuild then.
class _DisplaySizeValue extends ConsumerWidget {
  const _DisplaySizeValue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(displayScaleProvider.select((s) => s.displayPercent));
    final percent = AppZoomScope.maybeOf(context)?.displayPercent ?? saved;
    return Text('$percent%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }
}

/// Settings → Text size's value: the custom size, or the phone's font size
/// while following it. Its own widget for the same reason as
/// [_DisplaySizeValue].
class _TextSizeValue extends ConsumerWidget {
  const _TextSizeValue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(displayScaleProvider.select((s) => s.textPercent));
    return Text(
      custom == null ? AppStrings.of(context).phoneTextSize('${phoneTextPercent(context)}%') : '$custom%',
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

/// Amber warning card surfaced under the "Google Drive" section header
/// when the background worker has detected revoked / failed Drive access.
/// Tapping the primary button re-runs interactive sign-in; tapping the X
/// dismisses the banner without fixing it.
class _AutoBackupErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onSignIn;
  final VoidCallback onDismiss;

  const _AutoBackupErrorBanner({
    required this.message,
    required this.onSignIn,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ThinIcon(tabler.AlertTriangle.new,
              color: Colors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tr('autoBackupPaused'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(s.tr('signInToFix')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.tr('dismiss'),
            icon: const ThinIcon(tabler.X.new, size: 20),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      // The rows' own Material: a ListTile paints its ink (tap ripple,
      // highlight) on the nearest Material, which was the screen's, under
      // this card's colour. Transparent, and clipped to the card's corners.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

/// A Settings row with a control at its end (a button, a toggle, a value),
/// where `ListTile.trailing` would put it. ListTile gives its title only the
/// width the icon box and the trailing leave, and breaks a longer word across
/// lines: down to a letter a line beside a wide button, in a long
/// translation, at a large text size or in a narrow layout. So when a word of
/// the row's title or subtitle wouldn't fit beside [control], the control
/// goes under them instead, in line with the title.
///
/// [tile] is the row's ListTile, without a trailing widget. Beside it, the
/// control sits exactly where ListTile's trailing would.
class _EndControl extends MultiChildRenderObjectWidget {
  _EndControl({required Widget tile, required Widget control})
      : super(children: [tile, control]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEndControl(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderEndControl).textDirection =
        Directionality.of(context);
  }
}

class _EndControlParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEndControl extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EndControlParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EndControlParentData> {
  _RenderEndControl(this._textDirection);

  /// The theme's ListTile end padding, which is also its title gap: between
  /// the title and the control, and after the control.
  static const double _end = 16;

  /// Where the ListTile's texts start: its padding, the 40 dp icon box and
  /// the title gap.
  static const double _textStart = 72;

  /// How far a control under the texts reaches into the ListTile's bottom
  /// padding, and the space left under it.
  static const double _tuck = 4;
  static const double _below = 8;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _tile => firstChild!;
  RenderBox get _control => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EndControlParentData) {
      child.parentData = _EndControlParentData();
    }
  }

  /// Whether the control fits beside the texts in [width]. A ListTile's
  /// minimum intrinsic width is its padding and icon box plus the longest
  /// word of its title and subtitle.
  bool _beside(double width) =>
      _tile.getMinIntrinsicWidth(double.infinity) +
          _end +
          _control.getMaxIntrinsicWidth(double.infinity) <=
      width;

  /// Sizes the children with [layoutChild]: the row's size and where each
  /// child goes.
  ({Size size, Offset tile, Offset control}) _arrange(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final width = constraints.maxWidth;
    final rtl = textDirection == TextDirection.rtl;
    if (_beside(width)) {
      // As ListTile lays out its trailing: centered across the row.
      final control = layoutChild(_control, BoxConstraints(maxWidth: width));
      final tile = layoutChild(
        _tile,
        BoxConstraints.tightFor(width: width - control.width - _end),
      );
      final size = constraints.constrain(
        Size(width, math.max(tile.height, control.height)),
      );
      return (
        size: size,
        tile: Offset(
          rtl ? control.width + _end : 0,
          (size.height - tile.height) / 2,
        ),
        control: Offset(
          rtl ? _end : width - _end - control.width,
          (size.height - control.height) / 2,
        ),
      );
    }
    final tile = layoutChild(_tile, BoxConstraints.tightFor(width: width));
    final control = layoutChild(
      _control,
      BoxConstraints(maxWidth: math.max(0, width - _textStart - _end)),
    );
    final top = math.max(0.0, tile.height - _tuck);
    return (
      size: constraints.constrain(
        Size(width, top + control.height + _below),
      ),
      tile: Offset.zero,
      control: Offset(rtl ? width - _textStart - control.width : _textStart, top),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _tile.getMinIntrinsicWidth(height),
    _textStart + _control.getMinIntrinsicWidth(height) + _end,
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _tile.getMaxIntrinsicWidth(height) +
      _end +
      _control.getMaxIntrinsicWidth(height);

  double _intrinsicHeight(double width) => width.isFinite
      ? _arrange(
          BoxConstraints(maxWidth: width),
          ChildLayoutHelper.dryLayoutChild,
        ).size.height
      : math.max(
          _tile.getMaxIntrinsicHeight(width),
          _control.getMaxIntrinsicHeight(width),
        );

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final arranged = _arrange(constraints, ChildLayoutHelper.layoutChild);
    size = arranged.size;
    (_tile.parentData! as _EndControlParentData).offset = arranged.tile;
    (_control.parentData! as _EndControlParentData).offset = arranged.control;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

class _EditableTile extends StatelessWidget {
  final ThinIconBuilder icon;
  final String label;
  final String value;
  final void Function(String) onEdit;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _EditableTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: brand.primary.withAlpha(26), borderRadius: BorderRadius.circular(10)),
        child: ThinIcon(icon, color: brand.primary, size: 20),
      ),
      title: Text(label),
      subtitle: Text(value),
      trailing: const ThinIcon(tabler.Pencil.new, size: 18),
      onTap: () {
        final ctrl = TextEditingController(text: value);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('${AppStrings.of(context).edit} $label'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.of(context).cancel)),
              FilledButton(
                onPressed: () {
                  onEdit(ctrl.text.trim());
                  Navigator.pop(ctx);
                },
                child: Text(AppStrings.of(context).save),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final String currentMode;
  final ValueChanged<String> onChanged;

  const _ThemeModeSelector({required this.currentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final brand = context.brand;
    final modes = [
      ('light', tabler.Sun.new, s.light),
      ('dark', tabler.Moon.new, s.dark),
      ('system', tabler.SunMoon.new, s.system),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: modes.map((entry) {
          final (value, icon, label) = entry;
          final isSelected = currentMode == value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: isSelected ? brand.primary.withAlpha(31) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? brand.primary : theme.colorScheme.onSurface.withAlpha(31),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        ThinIcon(
                          icon,
                          color: isSelected ? brand.primary : theme.colorScheme.onSurface.withAlpha(128),
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? brand.primary : theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Settings → Color theme: the active theme's swatch (its main color with
/// its text color on it) and name. Opens the Color theme screen.
class _ColorThemeTile extends ConsumerWidget {
  const _ColorThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    // Plain values: only a change of theme or of the saved ones rebuilds.
    ref.watch(settingsProvider.select((m) => m['colorThemeId']));
    ref.watch(settingsProvider.select((m) => m['customColorThemes']));
    final active = ref.read(settingsProvider.notifier).activeColorTheme;
    // Phone colors saved (e.g. from another phone's backup) on a phone that
    // has none: the app is drawn in Teal, so name what is actually shown.
    final phoneState = ref.watch(dynamicColorAvailableProvider);
    final shown = active.isPhone &&
            phoneState.hasValue &&
            !(phoneState.value ?? false)
        ? kDefaultColorTheme
        : active;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ThinIcon(tabler.Palette.new, color: cs.onPrimary, size: 20),
      ),
      title: Text(s.colorTheme),
      subtitle: Text(
        colorThemeName(context, shown),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: const ThinIcon(tabler.ChevronRight.new, size: 20),
      onTap: () => context.push('/settings/color-theme'),
    );
  }
}

class _BackupPickerSheet extends StatelessWidget {
  final List<DriveBackupInfo> backups;

  const _BackupPickerSheet({required this.backups});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            AppStrings.of(context).selectBackupToRestore,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        // Flexible: more backups than the sheet's height holds scroll,
        // instead of running off its bottom.
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (ctx, i) {
              final backup = backups[i];
              return ListTile(
                leading: const ThinIcon(tabler.CloudDownload.new, color: Colors.green),
                title: Text(backup.name),
                subtitle: Text(DateFormatter.formatWithTime(backup.createdTime)),
                onTap: () => Navigator.pop(ctx, backup),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Currency Picker Sheet ──────────────────────────────────────────────────

class _CurrencyPickerSheet extends StatefulWidget {
  final String currentSymbol;

  const _CurrencyPickerSheet({required this.currentSymbol});

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _currencies = <({String symbol, String name, String code})>[
    (symbol: '\$', name: 'US Dollar', code: 'USD'),
    (symbol: '৳', name: 'Bangladeshi Taka', code: 'BDT'),
    (symbol: '€', name: 'Euro', code: 'EUR'),
    (symbol: '£', name: 'British Pound', code: 'GBP'),
    (symbol: '¥', name: 'Japanese Yen', code: 'JPY'),
    (symbol: '¥', name: 'Chinese Yuan', code: 'CNY'),
    (symbol: '₩', name: 'South Korean Won', code: 'KRW'),
    (symbol: '₱', name: 'Philippine Peso', code: 'PHP'),
    (symbol: '฿', name: 'Thai Baht', code: 'THB'),
    (symbol: '₫', name: 'Vietnamese Dong', code: 'VND'),
    (symbol: 'RM', name: 'Malaysian Ringgit', code: 'MYR'),
    (symbol: 'S\$', name: 'Singapore Dollar', code: 'SGD'),
    (symbol: '₨', name: 'Pakistani Rupee', code: 'PKR'),
    (symbol: '₨', name: 'Sri Lankan Rupee', code: 'LKR'),
    (symbol: '₨', name: 'Nepalese Rupee', code: 'NPR'),
    (symbol: 'R', name: 'South African Rand', code: 'ZAR'),
    (symbol: 'A\$', name: 'Australian Dollar', code: 'AUD'),
    (symbol: 'C\$', name: 'Canadian Dollar', code: 'CAD'),
    (symbol: 'Fr', name: 'Swiss Franc', code: 'CHF'),
    (symbol: 'kr', name: 'Swedish Krona', code: 'SEK'),
    (symbol: 'kr', name: 'Norwegian Krone', code: 'NOK'),
    (symbol: 'kr', name: 'Danish Krone', code: 'DKK'),
    (symbol: 'zł', name: 'Polish Zloty', code: 'PLN'),
    (symbol: '₺', name: 'Turkish Lira', code: 'TRY'),
    (symbol: 'R\$', name: 'Brazilian Real', code: 'BRL'),
    (symbol: '\$', name: 'Mexican Peso', code: 'MXN'),
    (symbol: '₽', name: 'Russian Ruble', code: 'RUB'),
    (symbol: 'د.إ', name: 'UAE Dirham', code: 'AED'),
    (symbol: 'ر.س', name: 'Saudi Riyal', code: 'SAR'),
    (symbol: 'د.ك', name: 'Kuwaiti Dinar', code: 'KWD'),
    (symbol: 'ر.ق', name: 'Qatari Riyal', code: 'QAR'),
    (symbol: '﷼', name: 'Iranian Rial', code: 'IRR'),
    (symbol: 'E£', name: 'Egyptian Pound', code: 'EGP'),
    (symbol: '₦', name: 'Nigerian Naira', code: 'NGN'),
    (symbol: 'KSh', name: 'Kenyan Shilling', code: 'KES'),
    (symbol: '₵', name: 'Ghanaian Cedi', code: 'GHS'),
    (symbol: 'Tk', name: 'Bangladeshi Taka (alt)', code: 'BDT2'),
    (symbol: '₹', name: 'Indian Rupee', code: 'INR'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final filtered = _query.isEmpty
        ? _currencies
        : _currencies
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_query) ||
                    c.code.toLowerCase().contains(_query) ||
                    c.symbol.contains(_query),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.of(context).selectCurrency,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: AppStrings.of(context).searchCurrency,
                // Centered: the field's 48 dp icon slot would stretch it.
                prefixIcon: const Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: ThinIcon(tabler.Search.new, size: 20),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const ThinIcon(tabler.X.new, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
              itemBuilder: (_, i) {
                final c = filtered[i];
                final isSelected = c.symbol == widget.currentSymbol;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.pop(ctx, c.symbol),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary.withValues(alpha: 0.15) : cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      // A long symbol (KSh) at a large text size shrinks to
                      // the box instead of wrapping and being cut off.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          c.symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                      color: isSelected ? cs.primary : null,
                    ),
                  ),
                  subtitle: Text(c.code, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                  trailing: isSelected ? ThinIcon(tabler.CircleCheck.new, color: cs.primary, size: 20) : null,
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Language Picker Sheet ──────────────────────────────────────────────────

class _LanguagePickerSheet extends StatelessWidget {
  final String currentCode;

  const _LanguagePickerSheet({required this.currentCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final languages = AppLocalizations.languageNames.entries.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.of(context).selectLanguage,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: languages.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
              itemBuilder: (_, i) {
                final entry = languages[i];
                final isSelected = entry.key == currentCode;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.pop(ctx, entry.key),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary.withValues(alpha: 0.15) : cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isSelected ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 15,
                      color: isSelected ? cs.primary : null,
                    ),
                  ),
                  trailing: isSelected ? ThinIcon(tabler.CircleCheck.new, color: cs.primary, size: 20) : null,
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
