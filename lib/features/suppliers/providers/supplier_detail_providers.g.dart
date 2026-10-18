// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_detail_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One supplier, live, for their detail screen. A provider rather than a
/// stream created in build(): go_router rebuilds pages on every push/pop in
/// the branch, and each rebuild used to resubscribe. Null once the supplier
/// doesn't exist.

@ProviderFor(supplierById)
final supplierByIdProvider = SupplierByIdFamily._();

/// One supplier, live, for their detail screen. A provider rather than a
/// stream created in build(): go_router rebuilds pages on every push/pop in
/// the branch, and each rebuild used to resubscribe. Null once the supplier
/// doesn't exist.

final class SupplierByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Supplier?>, Supplier?, Stream<Supplier?>>
    with $FutureModifier<Supplier?>, $StreamProvider<Supplier?> {
  /// One supplier, live, for their detail screen. A provider rather than a
  /// stream created in build(): go_router rebuilds pages on every push/pop in
  /// the branch, and each rebuild used to resubscribe. Null once the supplier
  /// doesn't exist.
  SupplierByIdProvider._({
    required SupplierByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'supplierByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$supplierByIdHash();

  @override
  String toString() {
    return r'supplierByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Supplier?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Supplier?> create(Ref ref) {
    final argument = this.argument as int;
    return supplierById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$supplierByIdHash() => r'544975c71a6b9f1edf53365dd614561011a06de0';

/// One supplier, live, for their detail screen. A provider rather than a
/// stream created in build(): go_router rebuilds pages on every push/pop in
/// the branch, and each rebuild used to resubscribe. Null once the supplier
/// doesn't exist.

final class SupplierByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Supplier?>, int> {
  SupplierByIdFamily._()
    : super(
        retry: null,
        name: r'supplierByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One supplier, live, for their detail screen. A provider rather than a
  /// stream created in build(): go_router rebuilds pages on every push/pop in
  /// the branch, and each rebuild used to resubscribe. Null once the supplier
  /// doesn't exist.

  SupplierByIdProvider call(int id) =>
      SupplierByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'supplierByIdProvider';
}
