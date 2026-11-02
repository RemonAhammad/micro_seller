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
