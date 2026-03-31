// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$categoriesHash() => r'bcfca9b29ce17c5d7ef364670e8180618ac87d60';

/// See also [categories].
@ProviderFor(categories)
final categoriesProvider = AutoDisposeStreamProvider<List<Category>>.internal(
  categories,
  name: r'categoriesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$categoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CategoriesRef = AutoDisposeStreamProviderRef<List<Category>>;
String _$categoryNotifierHash() => r'0bc304c92937f99ebdc0c3b8a005010f7a01ed08';

/// See also [CategoryNotifier].
@ProviderFor(CategoryNotifier)
final categoryNotifierProvider =
    AutoDisposeAsyncNotifierProvider<CategoryNotifier, void>.internal(
  CategoryNotifier.new,
  name: r'categoryNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$categoryNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CategoryNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
