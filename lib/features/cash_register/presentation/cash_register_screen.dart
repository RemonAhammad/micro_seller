import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cash_register_provider.dart';
import '../../../data/models/cash_register.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class CashRegisterScreen extends ConsumerWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final registersAsync = ref.watch(cashRegistersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.cashRegister)),
      body: registersAsync.when(
        data: (registers) {
          final openReg = registers.where((r) => !r.isClosed).firstOrNull;
          final closed = registers.where((r) => r.isClosed).toList();

          // Slivers, so the history (about one session a day) only builds
          // the sessions on screen — and a cash in/out doesn't rebuild them
          // all.
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current register status
                      if (openReg != null) ...[
                        _OpenRegisterCard(
                            register: openReg, theme: theme, cs: cs, ref: ref),
                      ] else ...[
                        _ClosedStateCard(theme: theme, cs: cs, ref: ref),
                      ],

                      const SizedBox(height: 24),

                      // History
                      Text(s.history,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),

                      if (closed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(s.noRegisterHistory,
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.builder(
                  itemCount: closed.length,
                  itemBuilder: (context, i) => AnimatedEntrance(
                    index: i,
                    child: _historyCard(context, closed[i]),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _historyCard(BuildContext context, CashRegister r) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormatter.format(r.openedAt),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s.closed,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _historyRow(theme, s.tr('opening'),
              CurrencyFormatter.format(r.openingAmount)),
          _historyRow(
              theme, s.cashIn, CurrencyFormatter.format(r.totalCashIn)),
          _historyRow(
              theme, s.cashOut, CurrencyFormatter.format(r.totalCashOut)),
          _historyRow(theme, s.tr('expected'),
              CurrencyFormatter.format(r.expectedClosing)),
          _historyRow(theme, s.tr('closing'),
              CurrencyFormatter.format(r.closingAmount ?? 0),
              isBold: true),
          if (r.difference.abs() > 0.01)
            _historyRow(
              theme,
              s.tr('difference'),
              '${r.difference > 0 ? '+' : ''}${CurrencyFormatter.format(r.difference)}',
              valueColor: r.difference > 0 ? Colors.green : Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _historyRow(ThemeData theme, String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor)),
        ],
      ),
    );
  }
}

// ─── Open Register Card ──────────────────────────────────────────────────────

class _OpenRegisterCard extends StatelessWidget {
  final dynamic register;
  final ThemeData theme;
  final ColorScheme cs;
  final WidgetRef ref;

  const _OpenRegisterCard(
      {required this.register,
      required this.theme,
      required this.cs,
      required this.ref});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ThinIcon(tabler.CashRegister.new, color: cs.primary, size: 24),
              const SizedBox(width: 10),
              Text(s.registerOpen,
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: cs.primary)),
              const Spacer(),
              Text(DateFormatter.formatWithTime(register.openedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 16),
          _statRow(s.openingAmount,
              CurrencyFormatter.format(register.openingAmount)),
          _statRow(
              s.cashIn, CurrencyFormatter.format(register.totalCashIn)),
          _statRow(
              s.cashOut, CurrencyFormatter.format(register.totalCashOut)),
          const Divider(height: 16),
          _statRow(s.expectedClosing,
              CurrencyFormatter.format(register.expectedClosing),
              isBold: true, valueColor: cs.primary),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashInOutDialog(context, true),
                  icon: const ThinIcon(tabler.Plus.new, size: 16),
                  label: Text(s.cashIn, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashInOutDialog(context, false),
                  icon: const ThinIcon(tabler.Minus.new, size: 16),
                  label:
                      Text(s.cashOut, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showCloseDialog(context),
              icon: const ThinIcon(tabler.Lock.new, size: 16),
              label: Text(s.closeRegister),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6))),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }

  void _showCashInOutDialog(BuildContext context, bool isIn) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? s.cashIn : s.cashOut),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
          ],
          decoration:
              InputDecoration(labelText: s.amount, isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              if (isIn) {
                await ref
                    .read(cashRegisterProvider.notifier)
                    .addCashIn(register.id, amount);
              } else {
                await ref
                    .read(cashRegisterProvider.notifier)
                    .addCashOut(register.id, amount);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController(
        text: register.expectedClosing.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.closeRegister),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${s.tr("expected")}: ${CurrencyFormatter.format(register.expectedClosing)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
              ],
              decoration: InputDecoration(
                  labelText: s.tr('closingAmount'), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                  labelText: s.notesOptional, isDense: true),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null) return;
              await ref
                  .read(cashRegisterProvider.notifier)
                  .closeRegister(register.id, amount,
                      notes: notesCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.close),
          ),
        ],
      ),
    );
  }
}

// ─── Closed State (no open register) ─────────────────────────────────────────

class _ClosedStateCard extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme cs;
  final WidgetRef ref;

  const _ClosedStateCard(
      {required this.theme, required this.cs, required this.ref});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          ThinIcon(tabler.CashRegister.new,
              size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(s.noRegisterOpen,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text(s.openRegisterDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 20),
          AppButton(
            label: s.openRegister,
            icon: tabler.LockOpen.new,
            isFullWidth: true,
            height: 48,
            onPressed: () => _showOpenDialog(context),
          ),
        ],
      ),
    );
  }

  void _showOpenDialog(BuildContext context) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.openRegister),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
          ],
          decoration: InputDecoration(
              labelText: s.openingAmount, isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              await ref
                  .read(cashRegisterProvider.notifier)
                  .openRegister(amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.open),
          ),
        ],
      ),
    );
  }
}
