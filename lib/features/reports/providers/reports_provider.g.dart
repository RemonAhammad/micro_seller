// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(salesReport)
final salesReportProvider = SalesReportFamily._();

final class SalesReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<SalesReport>,
          SalesReport,
          FutureOr<SalesReport>
        >
    with $FutureModifier<SalesReport>, $FutureProvider<SalesReport> {
  SalesReportProvider._({
    required SalesReportFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'salesReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$salesReportHash();

  @override
  String toString() {
    return r'salesReportProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SalesReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SalesReport> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return salesReport(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SalesReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$salesReportHash() => r'1143e214d77df1f72a418b952e5270117e30b00a';

final class SalesReportFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<SalesReport>, (DateTime, DateTime)> {
  SalesReportFamily._()
    : super(
        retry: null,
        name: r'salesReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SalesReportProvider call(DateTime from, DateTime to) =>
      SalesReportProvider._(argument: (from, to), from: this);

  @override
  String toString() => r'salesReportProvider';
}

@ProviderFor(duesReport)
final duesReportProvider = DuesReportFamily._();

final class DuesReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<DuesReport>,
          DuesReport,
          FutureOr<DuesReport>
        >
    with $FutureModifier<DuesReport>, $FutureProvider<DuesReport> {
  DuesReportProvider._({
    required DuesReportFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'duesReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$duesReportHash();

  @override
  String toString() {
    return r'duesReportProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<DuesReport> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DuesReport> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return duesReport(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DuesReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$duesReportHash() => r'5e18add4894e3ddb1004153851b2c1469586288f';

final class DuesReportFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DuesReport>, (DateTime, DateTime)> {
  DuesReportFamily._()
    : super(
        retry: null,
        name: r'duesReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DuesReportProvider call(DateTime from, DateTime to) =>
      DuesReportProvider._(argument: (from, to), from: this);

  @override
  String toString() => r'duesReportProvider';
}

@ProviderFor(inventoryReport)
final inventoryReportProvider = InventoryReportFamily._();

final class InventoryReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<InventoryReport>,
          InventoryReport,
          FutureOr<InventoryReport>
        >
    with $FutureModifier<InventoryReport>, $FutureProvider<InventoryReport> {
  InventoryReportProvider._({
    required InventoryReportFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'inventoryReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$inventoryReportHash();

  @override
  String toString() {
    return r'inventoryReportProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<InventoryReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InventoryReport> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return inventoryReport(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is InventoryReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inventoryReportHash() => r'1a2b03f1f695f8db1ed35409045b2e5ddbc3989f';

final class InventoryReportFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<InventoryReport>,
          (DateTime, DateTime)
        > {
  InventoryReportFamily._()
    : super(
        retry: null,
        name: r'inventoryReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InventoryReportProvider call(DateTime from, DateTime to) =>
      InventoryReportProvider._(argument: (from, to), from: this);

  @override
  String toString() => r'inventoryReportProvider';
}

@ProviderFor(purchasesReport)
final purchasesReportProvider = PurchasesReportFamily._();

final class PurchasesReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<PurchasesReport>,
          PurchasesReport,
          FutureOr<PurchasesReport>
        >
    with $FutureModifier<PurchasesReport>, $FutureProvider<PurchasesReport> {
  PurchasesReportProvider._({
    required PurchasesReportFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'purchasesReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$purchasesReportHash();

  @override
  String toString() {
    return r'purchasesReportProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PurchasesReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PurchasesReport> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return purchasesReport(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is PurchasesReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$purchasesReportHash() => r'8f920b181030fc683615d65489a546c42ef69f43';

final class PurchasesReportFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PurchasesReport>,
          (DateTime, DateTime)
        > {
  PurchasesReportFamily._()
    : super(
        retry: null,
        name: r'purchasesReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PurchasesReportProvider call(DateTime from, DateTime to) =>
      PurchasesReportProvider._(argument: (from, to), from: this);

  @override
  String toString() => r'purchasesReportProvider';
}
