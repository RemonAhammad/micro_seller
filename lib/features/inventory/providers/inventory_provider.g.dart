// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every movement newest first, read in createdAt-index order on a worker.

@ProviderFor(stockMovements)
final stockMovementsProvider = StockMovementsProvider._();

/// Every movement newest first, read in createdAt-index order on a worker.

final class StockMovementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockMovement>>,
          List<StockMovement>,
          Stream<List<StockMovement>>
        >
    with
        $FutureModifier<List<StockMovement>>,
        $StreamProvider<List<StockMovement>> {
  /// Every movement newest first, read in createdAt-index order on a worker.
  StockMovementsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stockMovementsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stockMovementsHash();

  @$internal
  @override
  $StreamProviderElement<List<StockMovement>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StockMovement>> create(Ref ref) {
    return stockMovements(ref);
  }
}

String _$stockMovementsHash() => r'93c1d13519607beb87b1e303e21f963967f6d5a7';

/// The movement history, paged: the newest [kMovementPageSize] movements,
/// more on [loadMore].

@ProviderFor(StockMovementPages)
final stockMovementPagesProvider = StockMovementPagesProvider._();

/// The movement history, paged: the newest [kMovementPageSize] movements,
/// more on [loadMore].
final class StockMovementPagesProvider
    extends $StreamNotifierProvider<StockMovementPages, StockMovementPage> {
  /// The movement history, paged: the newest [kMovementPageSize] movements,
  /// more on [loadMore].
  StockMovementPagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stockMovementPagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stockMovementPagesHash();

  @$internal
  @override
  StockMovementPages create() => StockMovementPages();
}

String _$stockMovementPagesHash() =>
    r'c0e474966c12ad0f814d0fc0481fd897bb375fcd';

/// The movement history, paged: the newest [kMovementPageSize] movements,
/// more on [loadMore].

abstract class _$StockMovementPages extends $StreamNotifier<StockMovementPage> {
  Stream<StockMovementPage> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<StockMovementPage>, StockMovementPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StockMovementPage>, StockMovementPage>,
              AsyncValue<StockMovementPage>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(productStockMovements)
final productStockMovementsProvider = ProductStockMovementsFamily._();

final class ProductStockMovementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockMovement>>,
          List<StockMovement>,
          Stream<List<StockMovement>>
        >
    with
        $FutureModifier<List<StockMovement>>,
        $StreamProvider<List<StockMovement>> {
  ProductStockMovementsProvider._({
    required ProductStockMovementsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'productStockMovementsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$productStockMovementsHash();

  @override
  String toString() {
    return r'productStockMovementsProvider'
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
    return productStockMovements(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductStockMovementsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productStockMovementsHash() =>
    r'b9539ca0353d1bae5b8eee78a025e50bdb8d3c83';

final class ProductStockMovementsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<StockMovement>>, int> {
  ProductStockMovementsFamily._()
    : super(
        retry: null,
        name: r'productStockMovementsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProductStockMovementsProvider call(int productId) =>
      ProductStockMovementsProvider._(argument: productId, from: this);

  @override
  String toString() => r'productStockMovementsProvider';
}
