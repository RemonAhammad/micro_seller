// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dashboardStatsHash() => r'b1d6db563f8622f55a35906a93c5ef32273739b8';

/// See also [dashboardStats].
@ProviderFor(dashboardStats)
final dashboardStatsProvider =
    AutoDisposeFutureProvider<DashboardStats>.internal(
  dashboardStats,
  name: r'dashboardStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dashboardStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DashboardStatsRef = AutoDisposeFutureProviderRef<DashboardStats>;
String _$dashboardDateRangeHash() =>
    r'3104e875bb99ec012c1510bd7a89028d6b7fb67c';

/// See also [DashboardDateRange].
@ProviderFor(DashboardDateRange)
final dashboardDateRangeProvider = AutoDisposeNotifierProvider<
    DashboardDateRange,
    ({DateTime start, DateTime end, DateRangePreset preset})>.internal(
  DashboardDateRange.new,
  name: r'dashboardDateRangeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dashboardDateRangeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DashboardDateRange = AutoDisposeNotifier<
    ({DateTime start, DateTime end, DateRangePreset preset})>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
