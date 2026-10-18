// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dues_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every customer who owes money, live. Re-emits whenever orders or
/// customers change; computed on a worker isolate.

@ProviderFor(dues)
final duesProvider = DuesProvider._();

/// Every customer who owes money, live. Re-emits whenever orders or
/// customers change; computed on a worker isolate.

final class DuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomerDue>>,
          List<CustomerDue>,
          Stream<List<CustomerDue>>
        >
    with
        $FutureModifier<List<CustomerDue>>,
        $StreamProvider<List<CustomerDue>> {
  /// Every customer who owes money, live. Re-emits whenever orders or
  /// customers change; computed on a worker isolate.
  DuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duesHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomerDue>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomerDue>> create(Ref ref) {
    return dues(ref);
  }
}

String _$duesHash() => r'6c9ea059ded23bdfd8e92a6ee2c9601a46387ad3';

@ProviderFor(dueSummary)
final dueSummaryProvider = DueSummaryProvider._();

final class DueSummaryProvider
    extends $FunctionalProvider<DueSummary?, DueSummary?, DueSummary?>
    with $Provider<DueSummary?> {
  DueSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueSummaryHash();

  @$internal
  @override
  $ProviderElement<DueSummary?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DueSummary? create(Ref ref) {
    return dueSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DueSummary? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DueSummary?>(value),
    );
  }
}

String _$dueSummaryHash() => r'3d3dbc1a7f64ef59251222437254b9f2dbd5c45c';

/// Dues collected since the 1st of this month (see [duesCollectedBetween]).

@ProviderFor(duesCollectedThisMonth)
final duesCollectedThisMonthProvider = DuesCollectedThisMonthProvider._();

/// Dues collected since the 1st of this month (see [duesCollectedBetween]).

final class DuesCollectedThisMonthProvider
    extends $FunctionalProvider<AsyncValue<double>, double, Stream<double>>
    with $FutureModifier<double>, $StreamProvider<double> {
  /// Dues collected since the 1st of this month (see [duesCollectedBetween]).
  DuesCollectedThisMonthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duesCollectedThisMonthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duesCollectedThisMonthHash();

  @$internal
  @override
  $StreamProviderElement<double> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<double> create(Ref ref) {
    return duesCollectedThisMonth(ref);
  }
}

String _$duesCollectedThisMonthHash() =>
    r'96f37880c717847d07a81e68609b33bd57584423';

/// A customer's payment history, newest first.

@ProviderFor(customerPayments)
final customerPaymentsProvider = CustomerPaymentsFamily._();

/// A customer's payment history, newest first.

final class CustomerPaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Payment>>,
          List<Payment>,
          Stream<List<Payment>>
        >
    with $FutureModifier<List<Payment>>, $StreamProvider<List<Payment>> {
  /// A customer's payment history, newest first.
  CustomerPaymentsProvider._({
    required CustomerPaymentsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'customerPaymentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customerPaymentsHash();

  @override
  String toString() {
    return r'customerPaymentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Payment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Payment>> create(Ref ref) {
    final argument = this.argument as int;
    return customerPayments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerPaymentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customerPaymentsHash() => r'1a9d4b044b16150926be335d00e6ab828558a605';

/// A customer's payment history, newest first.

final class CustomerPaymentsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Payment>>, int> {
  CustomerPaymentsFamily._()
    : super(
        retry: null,
        name: r'customerPaymentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A customer's payment history, newest first.

  CustomerPaymentsProvider call(int customerId) =>
      CustomerPaymentsProvider._(argument: customerId, from: this);

  @override
  String toString() => r'customerPaymentsProvider';
}
