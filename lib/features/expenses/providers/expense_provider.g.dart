// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(expenses)
final expensesProvider = ExpensesProvider._();

final class ExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  ExpensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expensesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expensesHash();

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    return expenses(ref);
  }
}

String _$expensesHash() => r'45382a7460ac7c2b122160e1d338413038e6dc28';

@ProviderFor(ExpenseNotifier)
final expenseProvider = ExpenseNotifierProvider._();

final class ExpenseNotifierProvider
    extends $AsyncNotifierProvider<ExpenseNotifier, void> {
  ExpenseNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseNotifierHash();

  @$internal
  @override
  ExpenseNotifier create() => ExpenseNotifier();
}

String _$expenseNotifierHash() => r'251dd3d164876e95aecfe08ad728a33261868ecd';

abstract class _$ExpenseNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
