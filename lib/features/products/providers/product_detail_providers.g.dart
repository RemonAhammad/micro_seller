// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_detail_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(productById)
final productByIdProvider = ProductByIdFamily._();

final class ProductByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Product?>, Product?, Stream<Product?>>
    with $FutureModifier<Product?>, $StreamProvider<Product?> {
  ProductByIdProvider._({
    required ProductByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'productByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$productByIdHash();

  @override
  String toString() {
    return r'productByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Product?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Product?> create(Ref ref) {
    final argument = this.argument as int;
    return productById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productByIdHash() => r'd87d021896d6373a3c4b86c6c1658085af0fec3f';

final class ProductByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Product?>, int> {
  ProductByIdFamily._()
    : super(
        retry: null,
        name: r'productByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProductByIdProvider call(int id) =>
      ProductByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'productByIdProvider';
}

/// A product's serial numbers, newest first, each with its order; live.

@ProviderFor(productSerials)
final productSerialsProvider = ProductSerialsFamily._();

/// A product's serial numbers, newest first, each with its order; live.

final class ProductSerialsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SerialRow>>,
          List<SerialRow>,
          Stream<List<SerialRow>>
        >
    with $FutureModifier<List<SerialRow>>, $StreamProvider<List<SerialRow>> {
  /// A product's serial numbers, newest first, each with its order; live.
  ProductSerialsProvider._({
    required ProductSerialsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'productSerialsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$productSerialsHash();

  @override
  String toString() {
    return r'productSerialsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<SerialRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SerialRow>> create(Ref ref) {
    final argument = this.argument as int;
    return productSerials(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductSerialsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productSerialsHash() => r'48e923bdbbd0bf4e77d6e5e96023de96b2d2da42';

/// A product's serial numbers, newest first, each with its order; live.

final class ProductSerialsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SerialRow>>, int> {
  ProductSerialsFamily._()
    : super(
        retry: null,
        name: r'productSerialsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A product's serial numbers, newest first, each with its order; live.

  ProductSerialsProvider call(int productId) =>
      ProductSerialsProvider._(argument: productId, from: this);

  @override
  String toString() => r'productSerialsProvider';
}
