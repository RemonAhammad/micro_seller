import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/services/trash_service.dart';
import '../../../shared/widgets/auth_gate.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

/// Deleted records, recoverable for [kTrashRetention].
///
/// Phase A covers expenses, categories, customers and products. Orders,
/// purchases and suppliers still delete permanently — their reversal touches
/// stock, variant stock, movements and party stats, and is handled
/// separately. Anything of an unsupported kind is shown greyed out with
/// restore disabled rather than offering an action that would throw.
class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  static const _restorable = {
    TrashKind.expense,
    TrashKind.category,
    TrashKind.customer,
    TrashKind.product,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final entriesAsync = ref.watch(trashEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.recycleBin),
        actions: [
          entriesAsync.maybeWhen(
            data: (entries) => entries.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _emptyBin(context, ref),
                    child: Text(
                      s.emptyBin,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: tabler.Trash.new,
              title: s.recycleBinEmpty,
              subtitle: s.recycleBinEmptyHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
            itemBuilder: (_, i) {
              if (i == 0) return _retentionBanner(context, s);
              return _tile(context, ref, s, entries[i - 1]);
            },
          );
        },
      ),
    );
  }

  Widget _retentionBanner(BuildContext context, dynamic s) {
    final cs = context.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ThinIcon(tabler.InfoCircle.new, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.recycleBinRetentionNote,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    dynamic s,
    TrashEntry entry,
  ) {
    final canRestore = _restorable.contains(entry.kind);
    final cs = context.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _kindColor(entry.kind).withValues(alpha: 0.15),
        child: ThinIcon(_kindIcon(entry.kind),
            size: 20, color: _kindColor(entry.kind)),
      ),
      title: Text(
        entry.label.isEmpty ? _kindLabel(s, entry.kind) : entry.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          _kindLabel(s, entry.kind),
          if (entry.sublabel.isNotEmpty) entry.sublabel,
          if (entry.deletedAt != null) DateFormatter.timeAgo(entry.deletedAt!),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: s.restore,
            icon: const ThinIcon(tabler.Restore.new),
            color: canRestore ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
            onPressed:
                canRestore ? () => _restore(context, ref, s, entry) : null,
          ),
          IconButton(
            tooltip: s.deleteForever,
            icon: const ThinIcon(tabler.TrashX.new),
            color: Colors.red.shade400,
            onPressed: () => _deleteForever(context, ref, s, entry),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    dynamic s,
    TrashEntry entry,
  ) async {
    final ok = await ref.read(trashProvider.notifier).restore(entry.id);
    if (!context.mounted) return;
    if (ok) {
      context.showSuccessSnackBar(s.itemRestored);
    } else {
      context.showErrorSnackBar(s.restoreFailed);
    }
  }

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    dynamic s,
    TrashEntry entry,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      title: s.deleteForever,
      message: s.deleteForeverConfirm,
      confirmText: s.delete,
      isDestructive: true,
      icon: tabler.TrashX.new,
    );
    if (ok != true || !context.mounted) return;
    await ref.read(trashProvider.notifier).deleteForever(entry.id);
  }

  /// Emptying the bin destroys data irrecoverably, so it goes through the
  /// same security gate as Clear All Data.
  Future<void> _emptyBin(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: s.emptyBin,
      message: s.emptyBinConfirm,
      confirmText: s.delete,
      isDestructive: true,
      icon: tabler.TrashX.new,
    );
    if (ok != true || !context.mounted) return;

    final settings = ref.read(settingsProvider.notifier);
    final passed = await runAuthGate(
      context,
      reason: s.emptyBin,
      fingerprintEnabled: settings.securityFingerprintEnabled,
      pinEnabled: settings.securityPinEnabled,
    );
    if (!passed || !context.mounted) return;

    await ref.read(trashProvider.notifier).clearAll();
    if (context.mounted) context.showSuccessSnackBar(s.binEmptied);
  }

  // ── presentation helpers ───────────────────────────────────────────────

  ThinIconBuilder _kindIcon(TrashKind kind) => switch (kind) {
        TrashKind.expense => tabler.Receipt.new,
        TrashKind.category => tabler.Category.new,
        TrashKind.customer => tabler.User.new,
        TrashKind.product => tabler.Package.new,
        TrashKind.order => tabler.ShoppingBag.new,
        TrashKind.purchase => tabler.TruckDelivery.new,
        TrashKind.supplier => tabler.BuildingStore.new,
      };

  Color _kindColor(TrashKind kind) => switch (kind) {
        TrashKind.expense => Colors.orange,
        TrashKind.category => Colors.purple,
        TrashKind.customer => Colors.blue,
        TrashKind.product => Colors.teal,
        TrashKind.order => Colors.indigo,
        TrashKind.purchase => Colors.brown,
        TrashKind.supplier => Colors.deepPurple,
      };

  String _kindLabel(dynamic s, TrashKind kind) => switch (kind) {
        TrashKind.expense => s.expense,
        TrashKind.category => s.category,
        TrashKind.customer => s.customer,
        TrashKind.product => s.product,
        TrashKind.order => s.order,
        TrashKind.purchase => s.purchase,
        TrashKind.supplier => s.supplier,
      };
}
