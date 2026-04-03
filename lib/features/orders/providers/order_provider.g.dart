// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ordersHash() => r'c1971fcd5dcd8d079f2a85a5e365b54e4f9960e0';

/// See also [orders].
@ProviderFor(orders)
final ordersProvider = AutoDisposeStreamProvider<List<Order>>.internal(
  orders,
  name: r'ordersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ordersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OrdersRef = AutoDisposeStreamProviderRef<List<Order>>;
String _$pendingOrdersHash() => r'9d70a1fcab97dd6e6c090a440d5c989e7d9b18ec';

/// See also [pendingOrders].
@ProviderFor(pendingOrders)
final pendingOrdersProvider = AutoDisposeStreamProvider<List<Order>>.internal(
  pendingOrders,
  name: r'pendingOrdersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingOrdersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PendingOrdersRef = AutoDisposeStreamProviderRef<List<Order>>;
String _$unpaidOrdersHash() => r'6cc3a246e47c4d991b1f47851de49d28bcca0fea';

/// See also [unpaidOrders].
@ProviderFor(unpaidOrders)
final unpaidOrdersProvider = AutoDisposeStreamProvider<List<Order>>.internal(
  unpaidOrders,
  name: r'unpaidOrdersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$unpaidOrdersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UnpaidOrdersRef = AutoDisposeStreamProviderRef<List<Order>>;
String _$orderNotifierHash() => r'd041bd40b4a96005c8b190055a80f6786e58c4c4';

/// See also [OrderNotifier].
@ProviderFor(OrderNotifier)
final orderNotifierProvider =
    AutoDisposeAsyncNotifierProvider<OrderNotifier, void>.internal(
  OrderNotifier.new,
  name: r'orderNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$orderNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$OrderNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
