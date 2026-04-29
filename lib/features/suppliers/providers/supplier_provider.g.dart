// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(suppliers)
final suppliersProvider = SuppliersProvider._();

final class SuppliersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Supplier>>,
          List<Supplier>,
          Stream<List<Supplier>>
        >
    with $FutureModifier<List<Supplier>>, $StreamProvider<List<Supplier>> {
  SuppliersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suppliersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suppliersHash();

  @$internal
  @override
  $StreamProviderElement<List<Supplier>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Supplier>> create(Ref ref) {
    return suppliers(ref);
  }
}

String _$suppliersHash() => r'7470e8abe6ab3d2ad6a09b1356e5e94e346018ff';

@ProviderFor(purchases)
final purchasesProvider = PurchasesProvider._();

final class PurchasesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Purchase>>,
          List<Purchase>,
          Stream<List<Purchase>>
        >
    with $FutureModifier<List<Purchase>>, $StreamProvider<List<Purchase>> {
  PurchasesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchasesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchasesHash();

  @$internal
  @override
  $StreamProviderElement<List<Purchase>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Purchase>> create(Ref ref) {
    return purchases(ref);
  }
}

String _$purchasesHash() => r'476862a41c51fd3bb1093f2c657750338e2c1f8b';

@ProviderFor(supplierPurchases)
final supplierPurchasesProvider = SupplierPurchasesFamily._();

final class SupplierPurchasesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Purchase>>,
          List<Purchase>,
          Stream<List<Purchase>>
        >
    with $FutureModifier<List<Purchase>>, $StreamProvider<List<Purchase>> {
  SupplierPurchasesProvider._({
    required SupplierPurchasesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'supplierPurchasesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$supplierPurchasesHash();

  @override
  String toString() {
    return r'supplierPurchasesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Purchase>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Purchase>> create(Ref ref) {
    final argument = this.argument as int;
    return supplierPurchases(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierPurchasesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$supplierPurchasesHash() => r'a4d2229007d6a7375b4c52821420e9c9c2c461d1';

final class SupplierPurchasesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Purchase>>, int> {
  SupplierPurchasesFamily._()
    : super(
        retry: null,
        name: r'supplierPurchasesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SupplierPurchasesProvider call(int supplierId) =>
      SupplierPurchasesProvider._(argument: supplierId, from: this);

  @override
  String toString() => r'supplierPurchasesProvider';
}

@ProviderFor(supplierProducts)
final supplierProductsProvider = SupplierProductsFamily._();

final class SupplierProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          Stream<List<Product>>
        >
    with $FutureModifier<List<Product>>, $StreamProvider<List<Product>> {
  SupplierProductsProvider._({
    required SupplierProductsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'supplierProductsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$supplierProductsHash();

  @override
  String toString() {
    return r'supplierProductsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Product>> create(Ref ref) {
    final argument = this.argument as int;
    return supplierProducts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierProductsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$supplierProductsHash() => r'dd423261a9919454d74b6066d81dab0ccf9de43b';

final class SupplierProductsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Product>>, int> {
  SupplierProductsFamily._()
    : super(
        retry: null,
        name: r'supplierProductsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SupplierProductsProvider call(int supplierId) =>
      SupplierProductsProvider._(argument: supplierId, from: this);

  @override
  String toString() => r'supplierProductsProvider';
}

@ProviderFor(supplierStockMovements)
final supplierStockMovementsProvider = SupplierStockMovementsFamily._();

final class SupplierStockMovementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockMovement>>,
          List<StockMovement>,
          Stream<List<StockMovement>>
        >
    with
        $FutureModifier<List<StockMovement>>,
        $StreamProvider<List<StockMovement>> {
  SupplierStockMovementsProvider._({
    required SupplierStockMovementsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'supplierStockMovementsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$supplierStockMovementsHash();

  @override
  String toString() {
    return r'supplierStockMovementsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<StockMovement>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StockMovement>> create(Ref ref) {
    final argument = this.argument as int;
    return supplierStockMovements(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierStockMovementsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$supplierStockMovementsHash() =>
    r'd83718b21934131580d7647040fd0089384344ab';

final class SupplierStockMovementsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<StockMovement>>, int> {
  SupplierStockMovementsFamily._()
    : super(
        retry: null,
        name: r'supplierStockMovementsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SupplierStockMovementsProvider call(int supplierId) =>
      SupplierStockMovementsProvider._(argument: supplierId, from: this);

  @override
  String toString() => r'supplierStockMovementsProvider';
}

@ProviderFor(SupplierNotifier)
final supplierProvider = SupplierNotifierProvider._();

final class SupplierNotifierProvider
    extends $AsyncNotifierProvider<SupplierNotifier, void> {
  SupplierNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierNotifierHash();

  @$internal
  @override
  SupplierNotifier create() => SupplierNotifier();
}

String _$supplierNotifierHash() => r'c8e52bed241644a5e4918ed4bc7858977610f4a7';

abstract class _$SupplierNotifier extends $AsyncNotifier<void> {
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
