// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$suppliersHash() => r'aedfdd9fbe072585bbcd71a307a1f8043855671f';

/// See also [suppliers].
@ProviderFor(suppliers)
final suppliersProvider = AutoDisposeStreamProvider<List<Supplier>>.internal(
  suppliers,
  name: r'suppliersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$suppliersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SuppliersRef = AutoDisposeStreamProviderRef<List<Supplier>>;
String _$purchasesHash() => r'8c031385b06fb5a792da5820d52c6d2fd320a76a';

/// See also [purchases].
@ProviderFor(purchases)
final purchasesProvider = AutoDisposeStreamProvider<List<Purchase>>.internal(
  purchases,
  name: r'purchasesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$purchasesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PurchasesRef = AutoDisposeStreamProviderRef<List<Purchase>>;
String _$supplierPurchasesHash() => r'0f730842cedf3d66a38d263b5773b3e32042bc49';

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

/// See also [supplierPurchases].
@ProviderFor(supplierPurchases)
const supplierPurchasesProvider = SupplierPurchasesFamily();

/// See also [supplierPurchases].
class SupplierPurchasesFamily extends Family<AsyncValue<List<Purchase>>> {
  /// See also [supplierPurchases].
  const SupplierPurchasesFamily();

  /// See also [supplierPurchases].
  SupplierPurchasesProvider call(
    int supplierId,
  ) {
    return SupplierPurchasesProvider(
      supplierId,
    );
  }

  @override
  SupplierPurchasesProvider getProviderOverride(
    covariant SupplierPurchasesProvider provider,
  ) {
    return call(
      provider.supplierId,
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
  String? get name => r'supplierPurchasesProvider';
}

/// See also [supplierPurchases].
class SupplierPurchasesProvider
    extends AutoDisposeStreamProvider<List<Purchase>> {
  /// See also [supplierPurchases].
  SupplierPurchasesProvider(
    int supplierId,
  ) : this._internal(
          (ref) => supplierPurchases(
            ref as SupplierPurchasesRef,
            supplierId,
          ),
          from: supplierPurchasesProvider,
          name: r'supplierPurchasesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$supplierPurchasesHash,
          dependencies: SupplierPurchasesFamily._dependencies,
          allTransitiveDependencies:
              SupplierPurchasesFamily._allTransitiveDependencies,
          supplierId: supplierId,
        );

  SupplierPurchasesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.supplierId,
  }) : super.internal();

  final int supplierId;

  @override
  Override overrideWith(
    Stream<List<Purchase>> Function(SupplierPurchasesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SupplierPurchasesProvider._internal(
        (ref) => create(ref as SupplierPurchasesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        supplierId: supplierId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Purchase>> createElement() {
    return _SupplierPurchasesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierPurchasesProvider && other.supplierId == supplierId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, supplierId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SupplierPurchasesRef on AutoDisposeStreamProviderRef<List<Purchase>> {
  /// The parameter `supplierId` of this provider.
  int get supplierId;
}

class _SupplierPurchasesProviderElement
    extends AutoDisposeStreamProviderElement<List<Purchase>>
    with SupplierPurchasesRef {
  _SupplierPurchasesProviderElement(super.provider);

  @override
  int get supplierId => (origin as SupplierPurchasesProvider).supplierId;
}

String _$supplierProductsHash() => r'4ad3052ccb76a951146b82834625911b429bb2b9';

/// See also [supplierProducts].
@ProviderFor(supplierProducts)
const supplierProductsProvider = SupplierProductsFamily();

/// See also [supplierProducts].
class SupplierProductsFamily extends Family<AsyncValue<List<Product>>> {
  /// See also [supplierProducts].
  const SupplierProductsFamily();

  /// See also [supplierProducts].
  SupplierProductsProvider call(
    int supplierId,
  ) {
    return SupplierProductsProvider(
      supplierId,
    );
  }

  @override
  SupplierProductsProvider getProviderOverride(
    covariant SupplierProductsProvider provider,
  ) {
    return call(
      provider.supplierId,
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
  String? get name => r'supplierProductsProvider';
}

/// See also [supplierProducts].
class SupplierProductsProvider
    extends AutoDisposeStreamProvider<List<Product>> {
  /// See also [supplierProducts].
  SupplierProductsProvider(
    int supplierId,
  ) : this._internal(
          (ref) => supplierProducts(
            ref as SupplierProductsRef,
            supplierId,
          ),
          from: supplierProductsProvider,
          name: r'supplierProductsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$supplierProductsHash,
          dependencies: SupplierProductsFamily._dependencies,
          allTransitiveDependencies:
              SupplierProductsFamily._allTransitiveDependencies,
          supplierId: supplierId,
        );

  SupplierProductsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.supplierId,
  }) : super.internal();

  final int supplierId;

  @override
  Override overrideWith(
    Stream<List<Product>> Function(SupplierProductsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SupplierProductsProvider._internal(
        (ref) => create(ref as SupplierProductsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        supplierId: supplierId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Product>> createElement() {
    return _SupplierProductsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierProductsProvider && other.supplierId == supplierId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, supplierId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SupplierProductsRef on AutoDisposeStreamProviderRef<List<Product>> {
  /// The parameter `supplierId` of this provider.
  int get supplierId;
}

class _SupplierProductsProviderElement
    extends AutoDisposeStreamProviderElement<List<Product>>
    with SupplierProductsRef {
  _SupplierProductsProviderElement(super.provider);

  @override
  int get supplierId => (origin as SupplierProductsProvider).supplierId;
}

String _$supplierStockMovementsHash() =>
    r'c7f2e26948c5ef2f94eaf5c33b1c962d42565c15';

/// See also [supplierStockMovements].
@ProviderFor(supplierStockMovements)
const supplierStockMovementsProvider = SupplierStockMovementsFamily();

/// See also [supplierStockMovements].
class SupplierStockMovementsFamily
    extends Family<AsyncValue<List<StockMovement>>> {
  /// See also [supplierStockMovements].
  const SupplierStockMovementsFamily();

  /// See also [supplierStockMovements].
  SupplierStockMovementsProvider call(
    int supplierId,
  ) {
    return SupplierStockMovementsProvider(
      supplierId,
    );
  }

  @override
  SupplierStockMovementsProvider getProviderOverride(
    covariant SupplierStockMovementsProvider provider,
  ) {
    return call(
      provider.supplierId,
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
  String? get name => r'supplierStockMovementsProvider';
}

/// See also [supplierStockMovements].
class SupplierStockMovementsProvider
    extends AutoDisposeStreamProvider<List<StockMovement>> {
  /// See also [supplierStockMovements].
  SupplierStockMovementsProvider(
    int supplierId,
  ) : this._internal(
          (ref) => supplierStockMovements(
            ref as SupplierStockMovementsRef,
            supplierId,
          ),
          from: supplierStockMovementsProvider,
          name: r'supplierStockMovementsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$supplierStockMovementsHash,
          dependencies: SupplierStockMovementsFamily._dependencies,
          allTransitiveDependencies:
              SupplierStockMovementsFamily._allTransitiveDependencies,
          supplierId: supplierId,
        );

  SupplierStockMovementsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.supplierId,
  }) : super.internal();

  final int supplierId;

  @override
  Override overrideWith(
    Stream<List<StockMovement>> Function(SupplierStockMovementsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SupplierStockMovementsProvider._internal(
        (ref) => create(ref as SupplierStockMovementsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        supplierId: supplierId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<StockMovement>> createElement() {
    return _SupplierStockMovementsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierStockMovementsProvider &&
        other.supplierId == supplierId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, supplierId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SupplierStockMovementsRef
    on AutoDisposeStreamProviderRef<List<StockMovement>> {
  /// The parameter `supplierId` of this provider.
  int get supplierId;
}

class _SupplierStockMovementsProviderElement
    extends AutoDisposeStreamProviderElement<List<StockMovement>>
    with SupplierStockMovementsRef {
  _SupplierStockMovementsProviderElement(super.provider);

  @override
  int get supplierId => (origin as SupplierStockMovementsProvider).supplierId;
}

String _$supplierNotifierHash() => r'5971587e4147eb94abbe612fdcc44d513ce52a98';

/// See also [SupplierNotifier].
@ProviderFor(SupplierNotifier)
final supplierNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SupplierNotifier, void>.internal(
  SupplierNotifier.new,
  name: r'supplierNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$supplierNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SupplierNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
