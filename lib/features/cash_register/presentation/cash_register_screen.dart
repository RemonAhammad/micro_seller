import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cash_register_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';

class CashRegisterScreen extends ConsumerWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registersAsync = ref.watch(cashRegistersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Register')),
      body: registersAsync.when(
        data: (registers) {
          final openReg = registers.where((r) => !r.isClosed).firstOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current register status
                if (openReg != null) ...[
                  _OpenRegisterCard(register: openReg, theme: theme, cs: cs, ref: ref),
                ] else ...[
                  _ClosedStateCard(theme: theme, cs: cs, ref: ref),
                ],

                const SizedBox(height: 24),

                // History
                Text('History',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                if (registers.where((r) => r.isClosed).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No register history yet',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4))),
                    ),
                  )
                else
                  ...registers.where((r) => r.isClosed).map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.1)),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Closed',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _historyRow(theme, 'Opening',
                                CurrencyFormatter.format(r.openingAmount)),
                            _historyRow(theme, 'Cash In',
                                CurrencyFormatter.format(r.totalCashIn)),
                            _historyRow(theme, 'Cash Out',
                                CurrencyFormatter.format(r.totalCashOut)),
                            _historyRow(theme, 'Expected',
                                CurrencyFormatter.format(r.expectedClosing)),
                            _historyRow(theme, 'Closing',
                                CurrencyFormatter.format(r.closingAmount ?? 0),
                                isBold: true),
                            if (r.difference.abs() > 0.01)
                              _historyRow(
                                theme,
                                'Difference',
                                '${r.difference > 0 ? '+' : ''}${CurrencyFormatter.format(r.difference)}',
                                valueColor: r.difference > 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                          ],
                        ),
                      )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
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
              Icon(Icons.point_of_sale_rounded, color: cs.primary, size: 24),
              const SizedBox(width: 10),
              Text('Register Open',
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: cs.primary)),
              const Spacer(),
              Text(DateFormatter.formatWithTime(register.openedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 16),
          _statRow('Opening Amount',
              CurrencyFormatter.format(register.openingAmount)),
          _statRow(
              'Cash In', CurrencyFormatter.format(register.totalCashIn)),
          _statRow(
              'Cash Out', CurrencyFormatter.format(register.totalCashOut)),
          const Divider(height: 16),
          _statRow('Expected Closing',
              CurrencyFormatter.format(register.expectedClosing),
              isBold: true, valueColor: cs.primary),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashInOutDialog(context, true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Cash In', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashInOutDialog(context, false),
                  icon: const Icon(Icons.remove, size: 16),
                  label:
                      const Text('Cash Out', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showCloseDialog(context),
              icon: const Icon(Icons.lock_rounded, size: 16),
              label: const Text('Close Register'),
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
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? 'Cash In' : 'Cash Out'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
          ],
          decoration:
              const InputDecoration(labelText: 'Amount', isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              if (isIn) {
                await ref
                    .read(cashRegisterNotifierProvider.notifier)
                    .addCashIn(register.id, amount);
              } else {
                await ref
                    .read(cashRegisterNotifierProvider.notifier)
                    .addCashOut(register.id, amount);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context) {
    final ctrl = TextEditingController(
        text: register.expectedClosing.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Expected: ${CurrencyFormatter.format(register.expectedClosing)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Actual Closing Amount', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                  labelText: 'Notes (optional)', isDense: true),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null) return;
              await ref
                  .read(cashRegisterNotifierProvider.notifier)
                  .closeRegister(register.id, amount,
                      notes: notesCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Close'),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(Icons.point_of_sale_rounded,
              size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No register open',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('Open a register to start tracking cash flow',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 20),
          AppButton(
            label: 'Open Register',
            icon: Icons.lock_open_rounded,
            isFullWidth: true,
            height: 48,
            onPressed: () => _showOpenDialog(context),
          ),
        ],
      ),
    );
  }

  void _showOpenDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Register'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
          ],
          decoration: const InputDecoration(
              labelText: 'Opening Cash Amount', isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              await ref
                  .read(cashRegisterNotifierProvider.notifier)
                  .openRegister(amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
