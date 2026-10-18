// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_detail_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One product, live, for its detail screen — so it shows an edit or a stock
/// adjustment made while it's open. A provider rather than a future created
/// in build(): go_router rebuilds pages on every push/pop in the branch, and
/// each rebuild used to re-query and flash a spinner.
///
/// Null when the product doesn't exist. But once a product has been shown, a
/// later delete keeps its last value: the detail screen pops itself after
/// deleting, and its exit transition shouldn't switch to "Product not found"
/// (it never did when the screen read the product once).

@ProviderFor(productById)
final productByIdProvider = ProductByIdFamily._();

/// One product, live, for its detail screen — so it shows an edit or a stock
/// adjustment made while it's open. A provider rather than a future created
/// in build(): go_router rebuilds pages on every push/pop in the branch, and
/// each rebuild used to re-query and flash a spinner.
///
/// Null when the product doesn't exist. But once a product has been shown, a
/// later delete keeps its last value: the detail screen pops itself after
/// deleting, and its exit transition shouldn't switch to "Product not found"
/// (it never did when the screen read the product once).

final class ProductByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Product?>, Product?, Stream<Product?>>
    with $FutureModifier<Product?>, $StreamProvider<Product?> {
  /// One product, live, for its detail screen — so it shows an edit or a stock
  /// adjustment made while it's open. A provider rather than a future created
  /// in build(): go_router rebuilds pages on every push/pop in the branch, and
  /// each rebuild used to re-query and flash a spinner.
  ///
  /// Null when the product doesn't exist. But once a product has been shown, a
  /// later delete keeps its last value: the detail screen pops itself after
  /// deleting, and its exit transition shouldn't switch to "Product not found"
  /// (it never did when the screen read the product once).
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

/// One product, live, for its detail screen — so it shows an edit or a stock
/// adjustment made while it's open. A provider rather than a future created
/// in build(): go_router rebuilds pages on every push/pop in the branch, and
/// each rebuild used to re-query and flash a spinner.
///
/// Null when the product doesn't exist. But once a product has been shown, a
/// later delete keeps its last value: the detail screen pops itself after
/// deleting, and its exit transition shouldn't switch to "Product not found"
/// (it never did when the screen read the product once).

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

  /// One product, live, for its detail screen — so it shows an edit or a stock
  /// adjustment made while it's open. A provider rather than a future created
  /// in build(): go_router rebuilds pages on every push/pop in the branch, and
  /// each rebuild used to re-query and flash a spinner.
  ///
  /// Null when the product doesn't exist. But once a product has been shown, a
  /// later delete keeps its last value: the detail screen pops itself after
  /// deleting, and its exit transition shouldn't switch to "Product not found"
  /// (it never did when the screen read the product once).

  ProductByIdProvider call(int id) =>
      ProductByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'productByIdProvider';
}
