// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(orders)
final ordersProvider = OrdersProvider._();

final class OrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Order>>,
          List<Order>,
          Stream<List<Order>>
        >
    with $FutureModifier<List<Order>>, $StreamProvider<List<Order>> {
  OrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersHash();

  @$internal
  @override
  $StreamProviderElement<List<Order>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Order>> create(Ref ref) {
    return orders(ref);
  }
}

String _$ordersHash() => r'0e44b9b5af0225e773bc6182e96be19629488d08';

/// Return orders only, newest first — the Returns screen's list, without
/// loading every order to filter them.

@ProviderFor(returnOrders)
final returnOrdersProvider = ReturnOrdersProvider._();

/// Return orders only, newest first — the Returns screen's list, without
/// loading every order to filter them.

final class ReturnOrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Order>>,
          List<Order>,
          Stream<List<Order>>
        >
    with $FutureModifier<List<Order>>, $StreamProvider<List<Order>> {
  /// Return orders only, newest first — the Returns screen's list, without
  /// loading every order to filter them.
  ReturnOrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'returnOrdersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$returnOrdersHash();

  @$internal
  @override
  $StreamProviderElement<List<Order>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Order>> create(Ref ref) {
    return returnOrders(ref);
  }
}

String _$returnOrdersHash() => r'60908a7288cff1fbc561ec32db8fe1d50e600d96';

/// One order, live — without reloading every order on each write.

@ProviderFor(orderById)
final orderByIdProvider = OrderByIdFamily._();

/// One order, live — without reloading every order on each write.

final class OrderByIdProvider
    extends $FunctionalProvider<AsyncValue<Order?>, Order?, Stream<Order?>>
    with $FutureModifier<Order?>, $StreamProvider<Order?> {
  /// One order, live — without reloading every order on each write.
  OrderByIdProvider._({
    required OrderByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'orderByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$orderByIdHash();

  @override
  String toString() {
    return r'orderByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Order?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Order?> create(Ref ref) {
    final argument = this.argument as int;
    return orderById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$orderByIdHash() => r'd7f7648feeaea342f7f3532c7b5079d2969fb3cf';

/// One order, live — without reloading every order on each write.

final class OrderByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Order?>, int> {
  OrderByIdFamily._()
    : super(
        retry: null,
        name: r'orderByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One order, live — without reloading every order on each write.

  OrderByIdProvider call(int id) =>
      OrderByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'orderByIdProvider';
}

@ProviderFor(pendingOrders)
final pendingOrdersProvider = PendingOrdersProvider._();

final class PendingOrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Order>>,
          List<Order>,
          Stream<List<Order>>
        >
    with $FutureModifier<List<Order>>, $StreamProvider<List<Order>> {
  PendingOrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingOrdersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingOrdersHash();

  @$internal
  @override
  $StreamProviderElement<List<Order>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Order>> create(Ref ref) {
    return pendingOrders(ref);
  }
}

String _$pendingOrdersHash() => r'6e1c02fdda068ea21a49dcb33145c5a50e67dc70';

@ProviderFor(OrderNotifier)
final orderProvider = OrderNotifierProvider._();

final class OrderNotifierProvider
    extends $AsyncNotifierProvider<OrderNotifier, void> {
  OrderNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderNotifierHash();

  @$internal
  @override
  OrderNotifier create() => OrderNotifier();
}

String _$orderNotifierHash() => r'1f5c4f110db7873ca39957a9da22fa4f56f8759c';

abstract class _$OrderNotifier extends $AsyncNotifier<void> {
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
