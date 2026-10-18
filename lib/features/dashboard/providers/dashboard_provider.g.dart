// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DashboardDateRange)
final dashboardDateRangeProvider = DashboardDateRangeProvider._();

final class DashboardDateRangeProvider
    extends $NotifierProvider<DashboardDateRange, DashboardRange> {
  DashboardDateRangeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardDateRangeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardDateRangeHash();

  @$internal
  @override
  DashboardDateRange create() => DashboardDateRange();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DashboardRange value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DashboardRange>(value),
    );
  }
}

String _$dashboardDateRangeHash() =>
    r'acad9e0ba4f2047dd13718fc823e64811470dfdf';

abstract class _$DashboardDateRange extends $Notifier<DashboardRange> {
  DashboardRange build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DashboardRange, DashboardRange>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DashboardRange, DashboardRange>,
              DashboardRange,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(dashboardStats)
final dashboardStatsProvider = DashboardStatsProvider._();

final class DashboardStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardStats>,
          DashboardStats,
          FutureOr<DashboardStats>
        >
    with $FutureModifier<DashboardStats>, $FutureProvider<DashboardStats> {
  DashboardStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardStatsHash();

  @$internal
  @override
  $FutureProviderElement<DashboardStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DashboardStats> create(Ref ref) {
    return dashboardStats(ref);
  }
}

String _$dashboardStatsHash() => r'aef3e66dfeb45ca19d6867e7bb890972a24ba576';
