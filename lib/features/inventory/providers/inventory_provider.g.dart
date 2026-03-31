// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$stockMovementsHash() => r'6b256eb01a5f0d2313a8cf96d262aa1afd03463d';

/// See also [stockMovements].
@ProviderFor(stockMovements)
final stockMovementsProvider =
    AutoDisposeStreamProvider<List<StockMovement>>.internal(
  stockMovements,
  name: r'stockMovementsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stockMovementsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StockMovementsRef = AutoDisposeStreamProviderRef<List<StockMovement>>;
String _$productStockMovementsHash() =>
    r'def97a9226acaee3cbc6d04d15a024484eeea2e0';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [productStockMovements].
@ProviderFor(productStockMovements)
const productStockMovementsProvider = ProductStockMovementsFamily();

/// See also [productStockMovements].
class ProductStockMovementsFamily
    extends Family<AsyncValue<List<StockMovement>>> {
  /// See also [productStockMovements].
  const ProductStockMovementsFamily();

  /// See also [productStockMovements].
  ProductStockMovementsProvider call(
    int productId,
  ) {
    return ProductStockMovementsProvider(
      productId,
    );
  }

  @override
  ProductStockMovementsProvider getProviderOverride(
    covariant ProductStockMovementsProvider provider,
  ) {
    return call(
      provider.productId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productStockMovementsProvider';
}

/// See also [productStockMovements].
class ProductStockMovementsProvider
    extends AutoDisposeStreamProvider<List<StockMovement>> {
  /// See also [productStockMovements].
  ProductStockMovementsProvider(
    int productId,
  ) : this._internal(
          (ref) => productStockMovements(
            ref as ProductStockMovementsRef,
            productId,
          ),
          from: productStockMovementsProvider,
          name: r'productStockMovementsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$productStockMovementsHash,
          dependencies: ProductStockMovementsFamily._dependencies,
          allTransitiveDependencies:
              ProductStockMovementsFamily._allTransitiveDependencies,
          productId: productId,
        );

  ProductStockMovementsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.productId,
  }) : super.internal();

  final int productId;

  @override
  Override overrideWith(
    Stream<List<StockMovement>> Function(ProductStockMovementsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductStockMovementsProvider._internal(
        (ref) => create(ref as ProductStockMovementsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        productId: productId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<StockMovement>> createElement() {
    return _ProductStockMovementsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductStockMovementsProvider &&
        other.productId == productId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, productId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ProductStockMovementsRef
    on AutoDisposeStreamProviderRef<List<StockMovement>> {
  /// The parameter `productId` of this provider.
  int get productId;
}

class _ProductStockMovementsProviderElement
    extends AutoDisposeStreamProviderElement<List<StockMovement>>
    with ProductStockMovementsRef {
  _ProductStockMovementsProviderElement(super.provider);

  @override
  int get productId => (origin as ProductStockMovementsProvider).productId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
