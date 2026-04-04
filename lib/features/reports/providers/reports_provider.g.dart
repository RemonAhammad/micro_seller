// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reportDataHash() => r'60b164e4e2f1d0f20333f39c93034863405288bd';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [reportData].
@ProviderFor(reportData)
const reportDataProvider = ReportDataFamily();

/// See also [reportData].
class ReportDataFamily extends Family<AsyncValue<ReportData>> {
  /// See also [reportData].
  const ReportDataFamily();

  /// See also [reportData].
  ReportDataProvider call(
    DateTime startDate,
    DateTime endDate,
  ) {
    return ReportDataProvider(
      startDate,
      endDate,
    );
  }

  @override
  ReportDataProvider getProviderOverride(
    covariant ReportDataProvider provider,
  ) {
    return call(
      provider.startDate,
      provider.endDate,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'reportDataProvider';
}

/// See also [reportData].
class ReportDataProvider extends AutoDisposeFutureProvider<ReportData> {
  /// See also [reportData].
  ReportDataProvider(
    DateTime startDate,
    DateTime endDate,
  ) : this._internal(
          (ref) => reportData(
            ref as ReportDataRef,
            startDate,
            endDate,
          ),
          from: reportDataProvider,
          name: r'reportDataProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$reportDataHash,
          dependencies: ReportDataFamily._dependencies,
          allTransitiveDependencies:
              ReportDataFamily._allTransitiveDependencies,
          startDate: startDate,
          endDate: endDate,
        );

  ReportDataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.startDate,
    required this.endDate,
  }) : super.internal();

  final DateTime startDate;
  final DateTime endDate;

  @override
  Override overrideWith(
    FutureOr<ReportData> Function(ReportDataRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ReportDataProvider._internal(
        (ref) => create(ref as ReportDataRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ReportData> createElement() {
    return _ReportDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReportDataProvider &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, startDate.hashCode);
    hash = _SystemHash.combine(hash, endDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ReportDataRef on AutoDisposeFutureProviderRef<ReportData> {
  /// The parameter `startDate` of this provider.
  DateTime get startDate;

  /// The parameter `endDate` of this provider.
  DateTime get endDate;
}

class _ReportDataProviderElement
    extends AutoDisposeFutureProviderElement<ReportData> with ReportDataRef {
  _ReportDataProviderElement(super.provider);

  @override
  DateTime get startDate => (origin as ReportDataProvider).startDate;
  @override
  DateTime get endDate => (origin as ReportDataProvider).endDate;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
