import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../../../data/models/category.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/cash_register.dart';
import '../../../data/services/drive_service.dart';
import '../../../data/services/local_backup_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _driveService = DriveService();
  final _localBackupService = LocalBackupService();
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLocalExporting = false;
  bool _isLocalImporting = false;
  String? _googleAccountEmail;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final account = await _driveService.getCurrentUser();
    if (mounted) {
      setState(() => _googleAccountEmail = account?.email);
    }
  }

  Future<void> _backup() async {
    setState(() => _isBackingUp = true);
    try {
      final isar = await ref.read(isarProvider.future);
      await _driveService.backupToDrive(isar);
      ref.read(settingsProvider.notifier).updateLastBackupTime(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).backupSuccess), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Not authenticated')
            ? 'Please sign in to Google first.'
            : 'Backup failed. Check your internet connection and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).tr('noBackupsFound'))),
        );
        return;
      }

      final selected = await showModalBottomSheet<DriveBackupInfo>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _BackupPickerSheet(backups: backups),
      );

      if (selected == null || !mounted) return;

      final confirmed = await ConfirmDialog.show(
        context,
        title: AppStrings.of(context).tr('restoreData'),
        message: AppStrings.of(context).tr('restoreDataConfirm'),
        confirmText: AppStrings.of(context).restoreFromDrive,
        isDestructive: true,
        icon: Icons.restore_rounded,
      );

      if (confirmed != true || !mounted) return;

      final isar = await ref.read(isarProvider.future);
      await _driveService.restoreFromDrive(isar, selected.fileId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).restoreSuccess), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Not authenticated')
            ? 'Please sign in to Google first.'
            : e.toString().contains('preserved')
                ? 'Restore failed. Your previous data has been preserved.'
                : 'Restore failed. Check your internet connection and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _clearData() async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.of(context).clearAllData,
      message: AppStrings.of(context).clearDataConfirmation,
      confirmText: AppStrings.of(context).clearAllData,
      isDestructive: true,
      icon: Icons.warning_rounded,
    );
    if (ok != true || !mounted) return;

    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      await isar.products.clear();
      await isar.orders.clear();
      await isar.customers.clear();
      await isar.expenses.clear();
      await isar.stockMovements.clear();
      await isar.categories.clear();
      await isar.suppliers.clear();
      await isar.purchases.clear();
      await isar.cashRegisters.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).allDataCleared)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme
          _SectionHeader(s.theme),
          _ThemeModeSelector(
            currentMode: ref.read(settingsProvider.notifier).themeMode,
            onChanged: (mode) => ref.read(settingsProvider.notifier).updateThemeMode(mode),
          ),
          const SizedBox(height: 16),

          // Language
          _SectionHeader(s.language),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text(s.language),
              subtitle: Text(
                AppLocalizations.languageNames[ref.read(settingsProvider.notifier).language] ?? 'English',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () async {
                final currentLang = ref.read(settingsProvider.notifier).language;
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => _LanguagePickerSheet(currentCode: currentLang),
                );
                if (selected != null) {
                  ref.read(settingsProvider.notifier).updateLanguage(selected);
                  setState(() {});
                }
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Shop
          _SectionHeader(s.shop),
          _SettingsCard(children: [
            _EditableTile(
              icon: Icons.store_rounded,
              label: s.shopName,
              value: ref.read(settingsProvider.notifier).shopName,
              onEdit: (val) => ref.read(settingsProvider.notifier).updateShopName(val),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.attach_money_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text(s.currencySymbol),
              subtitle: Text(
                ref.read(settingsProvider.notifier).currencySymbol,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => _CurrencyPickerSheet(
                    currentSymbol: ref.read(settingsProvider.notifier).currencySymbol,
                  ),
                );
                if (selected != null) {
                  ref.read(settingsProvider.notifier).updateCurrencySymbol(selected);
                  setState(() {});
                }
              },
            ),
            const Divider(height: 1),
            _EditableTile(
              icon: Icons.inventory_2_rounded,
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
              icon: Icons.percent_rounded,
              label: s.taxRate,
              value: ref.read(settingsProvider.notifier).taxRate.toString(),
              onEdit: (val) {
                final rate = double.tryParse(val);
                if (rate != null) {
                  ref.read(settingsProvider.notifier).updateTaxRate(rate);
                }
              },
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ]),
          const SizedBox(height: 16),

          // Downloads
          _SectionHeader(s.downloads),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text(s.pdfDownloadFolder),
              subtitle: Text(
                ref.read(settingsProvider.notifier).downloadDirectory.isEmpty
                    ? s.tr('notSetWillAsk')
                    : ref.read(settingsProvider.notifier).downloadDirectory,
                style: TextStyle(
                  fontSize: 12,
                  color: ref.read(settingsProvider.notifier).downloadDirectory.isEmpty
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_rounded, size: 18),
              onTap: () async {
                final dir = await FilePicker.platform.getDirectoryPath();
                if (dir != null) {
                  ref.read(settingsProvider.notifier).updateDownloadDirectory(dir);
                  setState(() {});
                }
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Local Backup
          _SectionHeader(s.localBackup),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLocalExporting
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_rounded, color: Colors.blue, size: 20),
              ),
              title: Text(s.exportBackup),
              subtitle: Text(
                s.exportBackupDesc,
                style: TextStyle(fontSize: 12),
              ),
              onTap: _isLocalExporting
                  ? null
                  : () async {
                      setState(() => _isLocalExporting = true);
                      try {
                        final isar = await ref.read(isarProvider.future);
                        await _localBackupService.exportBackup(isar);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${s.tr("exportFailed")}: $e'),
                              backgroundColor: Colors.red,
                            ),
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
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLocalImporting
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, color: Colors.orange, size: 20),
              ),
              title: Text(s.importBackup),
              subtitle: Text(
                s.importBackupDesc,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: _isLocalImporting
                  ? null
                  : () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: s.importBackup,
                        message: s.importBackupConfirm,
                        confirmText: s.importBackup,
                        isDestructive: true,
                        icon: Icons.warning_rounded,
                      );
                      if (ok != true) return;
                      setState(() => _isLocalImporting = true);
                      try {
                        final isar = await ref.read(isarProvider.future);
                        final success = await _localBackupService.importBackup(isar);
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
                            SnackBar(
                              content: Text('${s.tr("importFailed")}: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLocalImporting = false);
                        }
                      }
                    },
            ),
          ]),
          const SizedBox(height: 16),

          // Google Drive
          _SectionHeader(s.googleDriveBackup),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_circle_rounded, color: AppColors.primary),
              ),
              title: Text(s.googleAccount),
              subtitle: Text(
                _googleAccountEmail ?? s.signIn,
                style: TextStyle(
                  color: _googleAccountEmail != null ? AppColors.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              trailing: TextButton(
                onPressed: () async {
                  if (_googleAccountEmail != null) {
                    await _driveService.signOut();
                    setState(() => _googleAccountEmail = null);
                  } else {
                    final account = await _driveService.signIn();
                    setState(() => _googleAccountEmail = account?.email);
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
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isBackingUp
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded, color: Colors.blue),
              ),
              title: Text(s.backupToDrive),
              subtitle: ref.read(settingsProvider.notifier).lastBackupTime != null
                  ? Text('${s.lastBackup}: ${DateFormatter.format(ref.read(settingsProvider.notifier).lastBackupTime)}')
                  : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _isBackingUp ? null : _backup,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isRestoring
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_rounded, color: Colors.green),
              ),
              title: Text(s.restoreFromDrive),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _isRestoring ? null : _restore,
            ),
          ]),
          const SizedBox(height: 16),

          // About
          _SectionHeader(s.tr('about')),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              ),
              title: Text(s.appVersion),
              trailing: Text(
                '1.0.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Danger zone
          _SectionHeader(s.dangerZone),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              ),
              title: Text(
                s.clearAllData,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: _clearData,
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
            ),
          ]),
          const SizedBox(height: 32),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _EditableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final void Function(String) onEdit;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _EditableTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_rounded, size: 18),
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
              maxLength: maxLength,
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

  const _ThemeModeSelector({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final modes = [
      ('light', Icons.light_mode_rounded, s.light),
      ('dark', Icons.dark_mode_rounded, s.dark),
      ('system', Icons.brightness_auto_rounded, s.system),
    ];

    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: modes.map((entry) {
              final (value, icon, label) = entry;
              final isSelected = currentMode == value;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: isSelected ? AppColors.primary.withOpacity(0.12) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onChanged(value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : theme.colorScheme.onSurface.withOpacity(0.12),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? AppColors.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primary : theme.colorScheme.onSurface.withOpacity(0.7),
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
        ),
      ],
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
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(AppStrings.of(context).selectBackupToRestore,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: backups.length,
          itemBuilder: (ctx, i) {
            final backup = backups[i];
            return ListTile(
              leading: const Icon(Icons.cloud_download_rounded, color: Colors.green),
              title: Text(backup.name),
              subtitle: Text(DateFormatter.formatWithTime(backup.createdTime)),
              onTap: () => Navigator.pop(ctx, backup),
            );
          },
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
            .where((c) =>
                c.name.toLowerCase().contains(_query) ||
                c.code.toLowerCase().contains(_query) ||
                c.symbol.contains(_query))
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
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(AppStrings.of(context).selectCurrency, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
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
                  title: Text(c.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                        color: isSelected ? cs.primary : null,
                      )),
                  subtitle: Text(c.code,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      )),
                  trailing: isSelected ? Icon(Icons.check_circle, color: cs.primary, size: 20) : null,
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
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(AppStrings.of(context).selectLanguage,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: languages.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
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
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.onSurface.withValues(alpha: 0.06),
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
                  title: Text(entry.value,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 15,
                        color: isSelected ? cs.primary : null,
                      )),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: cs.primary, size: 20)
                      : null,
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
