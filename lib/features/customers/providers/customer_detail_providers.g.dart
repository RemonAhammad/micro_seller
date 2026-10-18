// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_detail_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One customer, live, so collecting a payment from their detail screen
/// refreshes the stats. Null once the customer doesn't exist.

@ProviderFor(customerById)
final customerByIdProvider = CustomerByIdFamily._();

/// One customer, live, so collecting a payment from their detail screen
/// refreshes the stats. Null once the customer doesn't exist.

final class CustomerByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Customer?>, Customer?, Stream<Customer?>>
    with $FutureModifier<Customer?>, $StreamProvider<Customer?> {
  /// One customer, live, so collecting a payment from their detail screen
  /// refreshes the stats. Null once the customer doesn't exist.
  CustomerByIdProvider._({
    required CustomerByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'customerByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customerByIdHash();

  @override
  String toString() {
    return r'customerByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Customer?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Customer?> create(Ref ref) {
    final argument = this.argument as int;
    return customerById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customerByIdHash() => r'88c5288ddb993265d4e2390e6634e49f5f0869ba';

/// One customer, live, so collecting a payment from their detail screen
/// refreshes the stats. Null once the customer doesn't exist.

final class CustomerByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Customer?>, int> {
  CustomerByIdFamily._()
    : super(
        retry: null,
        name: r'customerByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One customer, live, so collecting a payment from their detail screen
  /// refreshes the stats. Null once the customer doesn't exist.

  CustomerByIdProvider call(int id) =>
      CustomerByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'customerByIdProvider';
}

/// A customer's purchase history, live and paged: their newest
/// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
/// isolate.

@ProviderFor(CustomerOrders)
final customerOrdersProvider = CustomerOrdersFamily._();

/// A customer's purchase history, live and paged: their newest
/// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
/// isolate.
final class CustomerOrdersProvider
    extends $StreamNotifierProvider<CustomerOrders, CustomerOrdersPage> {
  /// A customer's purchase history, live and paged: their newest
  /// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
  /// isolate.
  CustomerOrdersProvider._({
    required CustomerOrdersFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'customerOrdersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customerOrdersHash();

  @override
  String toString() {
    return r'customerOrdersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CustomerOrders create() => CustomerOrders();

  @override
  bool operator ==(Object other) {
    return other is CustomerOrdersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customerOrdersHash() => r'0e0165644444efb6bb39a5e5de6ba13901d0e6d7';

/// A customer's purchase history, live and paged: their newest
/// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
/// isolate.

final class CustomerOrdersFamily extends $Family
    with
        $ClassFamilyOverride<
          CustomerOrders,
          AsyncValue<CustomerOrdersPage>,
          CustomerOrdersPage,
          Stream<CustomerOrdersPage>,
          int
        > {
  CustomerOrdersFamily._()
    : super(
        retry: null,
        name: r'customerOrdersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A customer's purchase history, live and paged: their newest
  /// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
  /// isolate.

  CustomerOrdersProvider call(int customerId) =>
      CustomerOrdersProvider._(argument: customerId, from: this);

  @override
  String toString() => r'customerOrdersProvider';
}

/// A customer's purchase history, live and paged: their newest
/// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
/// isolate.

abstract class _$CustomerOrders extends $StreamNotifier<CustomerOrdersPage> {
  late final _$args = ref.$arg as int;
  int get customerId => _$args;

  Stream<CustomerOrdersPage> build(int customerId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CustomerOrdersPage>, CustomerOrdersPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CustomerOrdersPage>, CustomerOrdersPage>,
              AsyncValue<CustomerOrdersPage>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

/// The purchase-history chart: the customer's spending in each of the last
/// six months (oldest first), or null — chart hidden — when they have no
/// orders apart from cancelled ones. Live.

@ProviderFor(customerMonthlySpending)
final customerMonthlySpendingProvider = CustomerMonthlySpendingFamily._();

/// The purchase-history chart: the customer's spending in each of the last
/// six months (oldest first), or null — chart hidden — when they have no
/// orders apart from cancelled ones. Live.

final class CustomerMonthlySpendingProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<DateTime, double>?>,
          Map<DateTime, double>?,
          Stream<Map<DateTime, double>?>
        >
    with
        $FutureModifier<Map<DateTime, double>?>,
        $StreamProvider<Map<DateTime, double>?> {
  /// The purchase-history chart: the customer's spending in each of the last
  /// six months (oldest first), or null — chart hidden — when they have no
  /// orders apart from cancelled ones. Live.
  CustomerMonthlySpendingProvider._({
    required CustomerMonthlySpendingFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'customerMonthlySpendingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customerMonthlySpendingHash();

  @override
  String toString() {
    return r'customerMonthlySpendingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Map<DateTime, double>?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<DateTime, double>?> create(Ref ref) {
    final argument = this.argument as int;
    return customerMonthlySpending(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerMonthlySpendingProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customerMonthlySpendingHash() =>
    r'e701c5793dae616ab7f79e31c92e42fb4581d955';

/// The purchase-history chart: the customer's spending in each of the last
/// six months (oldest first), or null — chart hidden — when they have no
/// orders apart from cancelled ones. Live.

final class CustomerMonthlySpendingFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Map<DateTime, double>?>, int> {
  CustomerMonthlySpendingFamily._()
    : super(
        retry: null,
        name: r'customerMonthlySpendingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The purchase-history chart: the customer's spending in each of the last
  /// six months (oldest first), or null — chart hidden — when they have no
  /// orders apart from cancelled ones. Live.

  CustomerMonthlySpendingProvider call(int customerId) =>
      CustomerMonthlySpendingProvider._(argument: customerId, from: this);

  @override
  String toString() => r'customerMonthlySpendingProvider';
}
