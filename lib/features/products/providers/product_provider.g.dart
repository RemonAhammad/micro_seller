// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productRepositoryHash() => r'8cfc1f55cd302ac09c0a1db034607d4561b52501';

/// See also [productRepository].
@ProviderFor(productRepository)
final productRepositoryProvider =
    AutoDisposeProvider<ProductRepository>.internal(
  productRepository,
  name: r'productRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$productRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ProductRepositoryRef = AutoDisposeProviderRef<ProductRepository>;
String _$productsHash() => r'5e3617504f25c5d6a4bfb42e108de6fc7ef1ccb9';

/// See also [products].
@ProviderFor(products)
final productsProvider = AutoDisposeStreamProvider<List<Product>>.internal(
  products,
  name: r'productsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$productsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ProductsRef = AutoDisposeStreamProviderRef<List<Product>>;
String _$lowStockProductsHash() => r'66c79bb70e515b68f912919d64bc0d7a7b836801';

/// See also [lowStockProducts].
@ProviderFor(lowStockProducts)
final lowStockProductsProvider =
    AutoDisposeStreamProvider<List<Product>>.internal(
  lowStockProducts,
  name: r'lowStockProductsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lowStockProductsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LowStockProductsRef = AutoDisposeStreamProviderRef<List<Product>>;
String _$productNotifierHash() => r'd32d098e96cf1734d6d9f9164f28949496a174ad';

/// See also [ProductNotifier].
@ProviderFor(ProductNotifier)
final productNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ProductNotifier, void>.internal(
  ProductNotifier.new,
  name: r'productNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$productNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProductNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
