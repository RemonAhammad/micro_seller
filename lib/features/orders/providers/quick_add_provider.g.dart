// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_add_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The seller's most often sold products of late, for the order form's
/// quick-add chips: active ones with something left to sell, most sold first.

@ProviderFor(quickAddProducts)
final quickAddProductsProvider = QuickAddProductsProvider._();

/// The seller's most often sold products of late, for the order form's
/// quick-add chips: active ones with something left to sell, most sold first.

final class QuickAddProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  /// The seller's most often sold products of late, for the order form's
  /// quick-add chips: active ones with something left to sell, most sold first.
  QuickAddProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickAddProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickAddProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return quickAddProducts(ref);
  }
}

String _$quickAddProductsHash() => r'af984f4b5c869402b4280fb054945cc1304ac5db';
