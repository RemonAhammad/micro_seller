// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_target_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SalesTargetNotifier)
final salesTargetProvider = SalesTargetNotifierProvider._();

final class SalesTargetNotifierProvider
    extends $AsyncNotifierProvider<SalesTargetNotifier, SalesTarget?> {
  SalesTargetNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesTargetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesTargetNotifierHash();

  @$internal
  @override
  SalesTargetNotifier create() => SalesTargetNotifier();
}

String _$salesTargetNotifierHash() =>
    r'385bfee7dc0224525b8ccf31b0f78ef5a521388d';

abstract class _$SalesTargetNotifier extends $AsyncNotifier<SalesTarget?> {
  FutureOr<SalesTarget?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SalesTarget?>, SalesTarget?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SalesTarget?>, SalesTarget?>,
              AsyncValue<SalesTarget?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(salesTargetForMonth)
final salesTargetForMonthProvider = SalesTargetForMonthFamily._();

final class SalesTargetForMonthProvider
    extends
        $FunctionalProvider<
          AsyncValue<SalesTarget?>,
          SalesTarget?,
          FutureOr<SalesTarget?>
        >
    with $FutureModifier<SalesTarget?>, $FutureProvider<SalesTarget?> {
  SalesTargetForMonthProvider._({
    required SalesTargetForMonthFamily super.from,
    required (int, int) super.argument,
  }) : super(
         retry: null,
         name: r'salesTargetForMonthProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$salesTargetForMonthHash();

  @override
  String toString() {
    return r'salesTargetForMonthProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SalesTarget?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SalesTarget?> create(Ref ref) {
    final argument = this.argument as (int, int);
    return salesTargetForMonth(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SalesTargetForMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$salesTargetForMonthHash() =>
    r'e0c83fa93a9e528bad3c99ac0f50e40c979be400';

final class SalesTargetForMonthFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SalesTarget?>, (int, int)> {
  SalesTargetForMonthFamily._()
    : super(
        retry: null,
        name: r'salesTargetForMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SalesTargetForMonthProvider call(int year, int month) =>
      SalesTargetForMonthProvider._(argument: (year, month), from: this);

  @override
  String toString() => r'salesTargetForMonthProvider';
}
