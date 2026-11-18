// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categories)
final categoriesProvider = CategoriesProvider._();

final class CategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          Stream<List<Category>>
        >
    with $FutureModifier<List<Category>>, $StreamProvider<List<Category>> {
  CategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesHash();

  @$internal
  @override
  $StreamProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Category>> create(Ref ref) {
    return categories(ref);
  }
}

String _$categoriesHash() => r'cead5e1f38e8f9b7c261f11ff15095f5b5d023f4';

/// Products the order screen may sell by the dozen: those in a category
/// with "Sell by the dozen" on. Live as categories and products change.

@ProviderFor(dozenProductIds)
final dozenProductIdsProvider = DozenProductIdsProvider._();

/// Products the order screen may sell by the dozen: those in a category
/// with "Sell by the dozen" on. Live as categories and products change.

final class DozenProductIdsProvider
    extends
        $FunctionalProvider<AsyncValue<Set<int>>, Set<int>, Stream<Set<int>>>
    with $FutureModifier<Set<int>>, $StreamProvider<Set<int>> {
  /// Products the order screen may sell by the dozen: those in a category
  /// with "Sell by the dozen" on. Live as categories and products change.
  DozenProductIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dozenProductIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dozenProductIdsHash();

  @$internal
  @override
  $StreamProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Set<int>> create(Ref ref) {
    return dozenProductIds(ref);
  }
}

String _$dozenProductIdsHash() => r'a263861bc032733e92bef0b721cde87c3bca2650';

@ProviderFor(CategoryNotifier)
final categoryProvider = CategoryNotifierProvider._();

final class CategoryNotifierProvider
    extends $AsyncNotifierProvider<CategoryNotifier, void> {
  CategoryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryNotifierHash();

  @$internal
  @override
  CategoryNotifier create() => CategoryNotifier();
}

String _$categoryNotifierHash() => r'6b2d89e7b85c37a8b4bbf7d19cddc074a8943f5b';

abstract class _$CategoryNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
