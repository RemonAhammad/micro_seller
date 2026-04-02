import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../../data/models/category.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/drive_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _driveService = DriveService();
  bool _isBackingUp = false;
  bool _isRestoring = false;
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
      ref
          .read(settingsProvider.notifier)
          .updateLastBackupTime(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(AppStrings.backupSuccess),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Backup failed: $e'),
              backgroundColor: Colors.red),
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
          const SnackBar(content: Text('No backups found on Drive')),
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
        title: 'Restore Data',
        message:
            'This will replace all current data with the backup from ${selected.name}. Continue?',
        confirmText: 'Restore',
        isDestructive: true,
        icon: Icons.restore_rounded,
      );

      if (confirmed != true || !mounted) return;

      final isar = await ref.read(isarProvider.future);
      await _driveService.restoreFromDrive(isar, selected.fileId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(AppStrings.restoreSuccess),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Restore failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _clearData() async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Clear All Data',
      message: AppStrings.clearDataConfirmation,
      confirmText: 'Clear Everything',
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
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Shop
          const _SectionHeader('Shop'),
          _SettingsCard(children: [
            _EditableTile(
              icon: Icons.store_rounded,
              label: AppStrings.shopName,
              value: ref.read(settingsProvider.notifier).shopName,
              onEdit: (val) =>
                  ref.read(settingsProvider.notifier).updateShopName(val),
            ),
            const Divider(height: 1),
            _EditableTile(
              icon: Icons.attach_money_rounded,
              label: AppStrings.currencySymbol,
              value: ref.read(settingsProvider.notifier).currencySymbol,
              onEdit: (val) =>
                  ref.read(settingsProvider.notifier).updateCurrencySymbol(val),
              maxLength: 3,
            ),
            const Divider(height: 1),
            _EditableTile(
              icon: Icons.inventory_2_rounded,
              label: AppStrings.defaultLowStockThreshold,
              value:
                  ref.read(settingsProvider.notifier).lowStockThreshold.toString(),
              onEdit: (val) {
                final n = int.tryParse(val);
                if (n != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateLowStockThreshold(n);
                }
              },
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
          const SizedBox(height: 16),

          // Google Drive
          const _SectionHeader('Google Drive Backup'),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_circle_rounded,
                    color: AppColors.primary),
              ),
              title: const Text(AppStrings.googleAccount),
              subtitle: Text(
                _googleAccountEmail ?? 'Not signed in',
                style: TextStyle(
                  color: _googleAccountEmail != null
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
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
                child: Text(_googleAccountEmail != null
                    ? AppStrings.signOut
                    : AppStrings.signIn),
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
              title: const Text(AppStrings.backupToDrive),
              subtitle: ref.read(settingsProvider.notifier).lastBackupTime != null
                  ? Text(
                      'Last: ${DateFormatter.format(ref.read(settingsProvider.notifier).lastBackupTime)}')
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
              title: const Text(AppStrings.restoreFromDrive),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _isRestoring ? null : _restore,
            ),
          ]),
          const SizedBox(height: 16),

          // About
          const _SectionHeader('About'),
          _SettingsCard(children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary),
              ),
              title: const Text(AppStrings.appVersion),
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
          const _SectionHeader('Danger Zone'),
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
              title: const Text(
                AppStrings.clearAllData,
                style: TextStyle(color: Colors.red),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Edit $label'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: maxLength,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  onEdit(ctrl.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('Select Backup to Restore',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: backups.length,
          itemBuilder: (ctx, i) {
            final backup = backups[i];
            return ListTile(
              leading:
                  const Icon(Icons.cloud_download_rounded, color: Colors.green),
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
