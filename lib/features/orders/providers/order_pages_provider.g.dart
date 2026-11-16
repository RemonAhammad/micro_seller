// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_pages_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OrderPages)
final orderPagesProvider = OrderPagesFamily._();

final class OrderPagesProvider
    extends $StreamNotifierProvider<OrderPages, OrderPage> {
  OrderPagesProvider._({
    required OrderPagesFamily super.from,
    required OrderTab super.argument,
  }) : super(
         retry: null,
         name: r'orderPagesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$orderPagesHash();

  @override
  String toString() {
    return r'orderPagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  OrderPages create() => OrderPages();

  @override
  bool operator ==(Object other) {
    return other is OrderPagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$orderPagesHash() => r'60efb0690453b269a47205eb024d42e147342893';

final class OrderPagesFamily extends $Family
    with
        $ClassFamilyOverride<
          OrderPages,
          AsyncValue<OrderPage>,
          OrderPage,
          Stream<OrderPage>,
          OrderTab
        > {
  OrderPagesFamily._()
    : super(
        retry: null,
        name: r'orderPagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  OrderPagesProvider call(OrderTab tab) =>
      OrderPagesProvider._(argument: tab, from: this);

  @override
  String toString() => r'orderPagesProvider';
}

abstract class _$OrderPages extends $StreamNotifier<OrderPage> {
  late final _$args = ref.$arg as OrderTab;
  OrderTab get tab => _$args;

  Stream<OrderPage> build(OrderTab tab);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<OrderPage>, OrderPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<OrderPage>, OrderPage>,
              AsyncValue<OrderPage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(orderTabCounts)
final orderTabCountsProvider = OrderTabCountsProvider._();

final class OrderTabCountsProvider
    extends
        $FunctionalProvider<AsyncValue<List<int>>, List<int>, Stream<List<int>>>
    with $FutureModifier<List<int>>, $StreamProvider<List<int>> {
  OrderTabCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderTabCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderTabCountsHash();

  @$internal
  @override
  $StreamProviderElement<List<int>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<int>> create(Ref ref) {
    return orderTabCounts(ref);
  }
}

String _$orderTabCountsHash() => r'4730374b4b8ce26db1d97e40c3c43a1b338333f0';
