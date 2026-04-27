// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stockMovements)
final stockMovementsProvider = StockMovementsProvider._();

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

String _$stockMovementsHash() => r'4333ce7c65f3e27d62ed94df2f10696484347f92';

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
    r'88cc90881cbc4dacee95cd36857fa42cf3f689d3';

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
