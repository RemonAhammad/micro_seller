// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reportData)
final reportDataProvider = ReportDataFamily._();

final class ReportDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReportData>,
          ReportData,
          FutureOr<ReportData>
        >
    with $FutureModifier<ReportData>, $FutureProvider<ReportData> {
  ReportDataProvider._({
    required ReportDataFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'reportDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reportDataHash();

  @override
  String toString() {
    return r'reportDataProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ReportData> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ReportData> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return reportData(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ReportDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reportDataHash() => r'3bb640f78e565cf90bb5284f6b7886dd448f481e';

final class ReportDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReportData>, (DateTime, DateTime)> {
  ReportDataFamily._()
    : super(
        retry: null,
        name: r'reportDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReportDataProvider call(DateTime startDate, DateTime endDate) =>
      ReportDataProvider._(argument: (startDate, endDate), from: this);

  @override
  String toString() => r'reportDataProvider';
}
