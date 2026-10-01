import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/expense.dart';
import '../providers/expense_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final Expense? expense;
  final int? expenseId;

  const ExpenseFormScreen({super.key, this.expense, this.expenseId});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.other;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  Expense? _existing;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.expense != null) {
      _populate(widget.expense!);
    } else if (widget.expenseId != null) {
      final isar = await ref.read(isarProvider.future);
      final e = await isar.expenses.get(widget.expenseId!);
      if (e != null && mounted) {
        _existing = e;
        _populate(e);
      }
    }
  }

  void _populate(Expense e) {
    _titleCtrl.text = e.title;
    _amountCtrl.text = e.amount.toString();
    _notesCtrl.text = e.notes;
    setState(() {
      _category = e.category;
      _date = e.date ?? DateTime.now();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final isEdit = _existing != null || widget.expense != null;
      final existing = _existing ?? widget.expense;

      final expense = Expense(
        id: existing?.id ?? Isar.autoIncrement,
        title: _titleCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text),
        category: _category,
        date: _date,
        notes: _notesCtrl.text.trim(),
        createdAt: existing?.createdAt,
      );

      if (isEdit) {
        await ref.read(expenseProvider.notifier).updateExpense(expense);
      } else {
        await ref.read(expenseProvider.notifier).addExpense(expense);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppStrings.of(context).savedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppStrings.of(context).error}: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isEdit = widget.expense != null || widget.expenseId != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? s.editExpense : s.addExpense),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: s.expenseTitle,
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => Validators.required(v, 'Title'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.amount,
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                ],
                validator: (v) => Validators.positiveNumber(v, 'Amount'),
                prefixIcon: const ThinIcon(tabler.Coin.new, size: 18),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      ThinIcon(tabler.Calendar.new,
                          size: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                )),
                            Text(
                              '${_date.day}/${_date.month}/${_date.year}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      ThinIcon(tabler.ChevronRight.new,
                          color: theme.colorScheme.outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category
              Text(s.expenseCategory,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((cat) {
                  final label = switch (cat) {
                    ExpenseCategory.logistics => s.logistics,
                    ExpenseCategory.packaging => s.packaging,
                    ExpenseCategory.marketing => s.marketing,
                    ExpenseCategory.supplies => s.supplies,
                    ExpenseCategory.other => s.other,
                  };
                  final isSelected = _category == cat;

                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.notes,
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),

              AppButton(
                label: isEdit ? s.editExpense : s.addExpense,
                onPressed: _submit,
                isLoading: _isLoading,
                isFullWidth: true,
                height: 52,
                icon: isEdit ? tabler.DeviceFloppy.new : tabler.Plus.new,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
