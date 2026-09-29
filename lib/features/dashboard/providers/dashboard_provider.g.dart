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
    extends
        $NotifierProvider<
          DashboardDateRange,
          ({DateTime end, DateRangePreset preset, DateTime start})
        > {
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
  Override overrideWithValue(
    ({DateTime end, DateRangePreset preset, DateTime start}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            ({DateTime end, DateRangePreset preset, DateTime start})
          >(value),
    );
  }
}

String _$dashboardDateRangeHash() =>
    r'3104e875bb99ec012c1510bd7a89028d6b7fb67c';

abstract class _$DashboardDateRange
    extends
        $Notifier<({DateTime end, DateRangePreset preset, DateTime start})> {
  ({DateTime end, DateRangePreset preset, DateTime start}) build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({DateTime end, DateRangePreset preset, DateTime start}),
              ({DateTime end, DateRangePreset preset, DateTime start})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({DateTime end, DateRangePreset preset, DateTime start}),
                ({DateTime end, DateRangePreset preset, DateTime start})
              >,
              ({DateTime end, DateRangePreset preset, DateTime start}),
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

String _$dashboardStatsHash() => r'd61791bb439cb0d6a3f239d16f9f543e09ed24f0';
