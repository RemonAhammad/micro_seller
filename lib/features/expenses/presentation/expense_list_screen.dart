import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/expense_provider.dart';
import '../../../data/services/csv_export_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/expense_card.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.expenses),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: s.exportCsv,
            onPressed: () async {
              final expenses = ref.read(expensesProvider).valueOrNull ?? [];
              if (expenses.isEmpty) return;
              await CsvExportService().exportExpenses(expenses);
            },
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: s.noExpenses,
              subtitle: s.trackExpenses,
              actionLabel: s.addExpense,
              onAction: () => context.push('/expenses/add'),
            );
          }

          // Monthly total summary
          final thisMonthExpenses = expenses.where((e) =>
              e.date != null && DateFormatter.isThisMonth(e.date!)).toList();
          final monthTotal =
              thisMonthExpenses.fold(0.0, (s, e) => s + e.amount);

          return Column(
            children: [
              // Month summary
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.thisMonth,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                          CurrencyFormatter.format(monthTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(s.entries,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                          '${thisMonthExpenses.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final expense = expenses[i];
                    return ExpenseCard(
                      expense: expense,
                      onTap: () => context.push('/expenses/${expense.id}/edit'),
                      onDelete: () async {
                        final ok = await ConfirmDialog.show(
                          context,
                          title: s.deleteExpense,
                          message: '${s.delete} "${expense.title}"?',
                          confirmText: s.delete,
                          isDestructive: true,
                          icon: Icons.delete_rounded,
                        );
                        if (ok == true) {
                          await ref
                              .read(expenseNotifierProvider.notifier)
                              .deleteExpense(expense.id);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expenses/add'),
        tooltip: s.addExpense,
        child: const Icon(Icons.add),
      ),
    );
  }
}
