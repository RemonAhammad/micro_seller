// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$expensesHash() => r'7e297ce626b71c8a8fa1e3152b66b8d2ef62b08d';

/// See also [expenses].
@ProviderFor(expenses)
final expensesProvider = AutoDisposeStreamProvider<List<Expense>>.internal(
  expenses,
  name: r'expensesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$expensesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ExpensesRef = AutoDisposeStreamProviderRef<List<Expense>>;
String _$expenseNotifierHash() => r'5c6e84bed2df47f4aeae50551525dae815522a16';

/// See also [ExpenseNotifier].
@ProviderFor(ExpenseNotifier)
final expenseNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ExpenseNotifier, void>.internal(
  ExpenseNotifier.new,
  name: r'expenseNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$expenseNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ExpenseNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
