// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customersHash() => r'd44dafc6a8b9600b9d0f6e4dfd749e4d60aab2ce';

/// See also [customers].
@ProviderFor(customers)
final customersProvider = AutoDisposeStreamProvider<List<Customer>>.internal(
  customers,
  name: r'customersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$customersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CustomersRef = AutoDisposeStreamProviderRef<List<Customer>>;
String _$customerNotifierHash() => r'cd7ed186b398f0974e8c4ad8b9ee289139de61c1';

/// See also [CustomerNotifier].
@ProviderFor(CustomerNotifier)
final customerNotifierProvider =
    AutoDisposeAsyncNotifierProvider<CustomerNotifier, void>.internal(
  CustomerNotifier.new,
  name: r'customerNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$customerNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CustomerNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
