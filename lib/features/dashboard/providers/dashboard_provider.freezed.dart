// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DailySales {
  DateTime get date => throw _privateConstructorUsedError;
  double get revenue => throw _privateConstructorUsedError;
  double get profit => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DailySalesCopyWith<DailySales> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailySalesCopyWith<$Res> {
  factory $DailySalesCopyWith(
          DailySales value, $Res Function(DailySales) then) =
      _$DailySalesCopyWithImpl<$Res, DailySales>;
  @useResult
  $Res call({DateTime date, double revenue, double profit});
}

/// @nodoc
class _$DailySalesCopyWithImpl<$Res, $Val extends DailySales>
    implements $DailySalesCopyWith<$Res> {
  _$DailySalesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? revenue = null,
    Object? profit = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      revenue: null == revenue
          ? _value.revenue
          : revenue // ignore: cast_nullable_to_non_nullable
              as double,
      profit: null == profit
          ? _value.profit
          : profit // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailySalesImplCopyWith<$Res>
    implements $DailySalesCopyWith<$Res> {
  factory _$$DailySalesImplCopyWith(
          _$DailySalesImpl value, $Res Function(_$DailySalesImpl) then) =
      __$$DailySalesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime date, double revenue, double profit});
}

/// @nodoc
class __$$DailySalesImplCopyWithImpl<$Res>
    extends _$DailySalesCopyWithImpl<$Res, _$DailySalesImpl>
    implements _$$DailySalesImplCopyWith<$Res> {
  __$$DailySalesImplCopyWithImpl(
      _$DailySalesImpl _value, $Res Function(_$DailySalesImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? revenue = null,
    Object? profit = null,
  }) {
    return _then(_$DailySalesImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      revenue: null == revenue
          ? _value.revenue
          : revenue // ignore: cast_nullable_to_non_nullable
              as double,
      profit: null == profit
          ? _value.profit
          : profit // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$DailySalesImpl implements _DailySales {
  const _$DailySalesImpl(
      {required this.date, required this.revenue, required this.profit});

  @override
  final DateTime date;
  @override
  final double revenue;
  @override
  final double profit;

  @override
  String toString() {
    return 'DailySales(date: $date, revenue: $revenue, profit: $profit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailySalesImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.revenue, revenue) || other.revenue == revenue) &&
            (identical(other.profit, profit) || other.profit == profit));
  }

  @override
  int get hashCode => Object.hash(runtimeType, date, revenue, profit);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailySalesImplCopyWith<_$DailySalesImpl> get copyWith =>
      __$$DailySalesImplCopyWithImpl<_$DailySalesImpl>(this, _$identity);
}

abstract class _DailySales implements DailySales {
  const factory _DailySales(
      {required final DateTime date,
      required final double revenue,
      required final double profit}) = _$DailySalesImpl;

  @override
  DateTime get date;
  @override
  double get revenue;
  @override
  double get profit;
  @override
  @JsonKey(ignore: true)
  _$$DailySalesImplCopyWith<_$DailySalesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DashboardStats {
  double get todayRevenue => throw _privateConstructorUsedError;
  double get thisMonthRevenue => throw _privateConstructorUsedError;
  double get thisMonthProfit => throw _privateConstructorUsedError;
  int get totalOrders => throw _privateConstructorUsedError;
  int get pendingOrders => throw _privateConstructorUsedError;
  double get unpaidTotal => throw _privateConstructorUsedError;
  List<Product> get lowStockProducts => throw _privateConstructorUsedError;
  List<DailySales> get weeklySales => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DashboardStatsCopyWith<DashboardStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardStatsCopyWith<$Res> {
  factory $DashboardStatsCopyWith(
          DashboardStats value, $Res Function(DashboardStats) then) =
      _$DashboardStatsCopyWithImpl<$Res, DashboardStats>;
  @useResult
  $Res call(
      {double todayRevenue,
      double thisMonthRevenue,
      double thisMonthProfit,
      int totalOrders,
      int pendingOrders,
      double unpaidTotal,
      List<Product> lowStockProducts,
      List<DailySales> weeklySales});
}

/// @nodoc
class _$DashboardStatsCopyWithImpl<$Res, $Val extends DashboardStats>
    implements $DashboardStatsCopyWith<$Res> {
  _$DashboardStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? todayRevenue = null,
    Object? thisMonthRevenue = null,
    Object? thisMonthProfit = null,
    Object? totalOrders = null,
    Object? pendingOrders = null,
    Object? unpaidTotal = null,
    Object? lowStockProducts = null,
    Object? weeklySales = null,
  }) {
    return _then(_value.copyWith(
      todayRevenue: null == todayRevenue
          ? _value.todayRevenue
          : todayRevenue // ignore: cast_nullable_to_non_nullable
              as double,
      thisMonthRevenue: null == thisMonthRevenue
          ? _value.thisMonthRevenue
          : thisMonthRevenue // ignore: cast_nullable_to_non_nullable
              as double,
      thisMonthProfit: null == thisMonthProfit
          ? _value.thisMonthProfit
          : thisMonthProfit // ignore: cast_nullable_to_non_nullable
              as double,
      totalOrders: null == totalOrders
          ? _value.totalOrders
          : totalOrders // ignore: cast_nullable_to_non_nullable
              as int,
      pendingOrders: null == pendingOrders
          ? _value.pendingOrders
          : pendingOrders // ignore: cast_nullable_to_non_nullable
              as int,
      unpaidTotal: null == unpaidTotal
          ? _value.unpaidTotal
          : unpaidTotal // ignore: cast_nullable_to_non_nullable
              as double,
      lowStockProducts: null == lowStockProducts
          ? _value.lowStockProducts
          : lowStockProducts // ignore: cast_nullable_to_non_nullable
              as List<Product>,
      weeklySales: null == weeklySales
          ? _value.weeklySales
          : weeklySales // ignore: cast_nullable_to_non_nullable
              as List<DailySales>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DashboardStatsImplCopyWith<$Res>
    implements $DashboardStatsCopyWith<$Res> {
  factory _$$DashboardStatsImplCopyWith(_$DashboardStatsImpl value,
          $Res Function(_$DashboardStatsImpl) then) =
      __$$DashboardStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double todayRevenue,
      double thisMonthRevenue,
      double thisMonthProfit,
      int totalOrders,
      int pendingOrders,
      double unpaidTotal,
      List<Product> lowStockProducts,
      List<DailySales> weeklySales});
}

/// @nodoc
class __$$DashboardStatsImplCopyWithImpl<$Res>
    extends _$DashboardStatsCopyWithImpl<$Res, _$DashboardStatsImpl>
    implements _$$DashboardStatsImplCopyWith<$Res> {
  __$$DashboardStatsImplCopyWithImpl(
      _$DashboardStatsImpl _value, $Res Function(_$DashboardStatsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? todayRevenue = null,
    Object? thisMonthRevenue = null,
    Object? thisMonthProfit = null,
    Object? totalOrders = null,
    Object? pendingOrders = null,
    Object? unpaidTotal = null,
    Object? lowStockProducts = null,
    Object? weeklySales = null,
  }) {
    return _then(_$DashboardStatsImpl(
      todayRevenue: null == todayRevenue
          ? _value.todayRevenue
          : todayRevenue // ignore: cast_nullable_to_non_nullable
              as double,
      thisMonthRevenue: null == thisMonthRevenue
          ? _value.thisMonthRevenue
          : thisMonthRevenue // ignore: cast_nullable_to_non_nullable
              as double,
      thisMonthProfit: null == thisMonthProfit
          ? _value.thisMonthProfit
          : thisMonthProfit // ignore: cast_nullable_to_non_nullable
              as double,
      totalOrders: null == totalOrders
          ? _value.totalOrders
          : totalOrders // ignore: cast_nullable_to_non_nullable
              as int,
      pendingOrders: null == pendingOrders
          ? _value.pendingOrders
          : pendingOrders // ignore: cast_nullable_to_non_nullable
              as int,
      unpaidTotal: null == unpaidTotal
          ? _value.unpaidTotal
          : unpaidTotal // ignore: cast_nullable_to_non_nullable
              as double,
      lowStockProducts: null == lowStockProducts
          ? _value._lowStockProducts
          : lowStockProducts // ignore: cast_nullable_to_non_nullable
              as List<Product>,
      weeklySales: null == weeklySales
          ? _value._weeklySales
          : weeklySales // ignore: cast_nullable_to_non_nullable
              as List<DailySales>,
    ));
  }
}

/// @nodoc

class _$DashboardStatsImpl implements _DashboardStats {
  const _$DashboardStatsImpl(
      {this.todayRevenue = 0.0,
      this.thisMonthRevenue = 0.0,
      this.thisMonthProfit = 0.0,
      this.totalOrders = 0,
      this.pendingOrders = 0,
      this.unpaidTotal = 0.0,
      final List<Product> lowStockProducts = const [],
      final List<DailySales> weeklySales = const []})
      : _lowStockProducts = lowStockProducts,
        _weeklySales = weeklySales;

  @override
  @JsonKey()
  final double todayRevenue;
  @override
  @JsonKey()
  final double thisMonthRevenue;
  @override
  @JsonKey()
  final double thisMonthProfit;
  @override
  @JsonKey()
  final int totalOrders;
  @override
  @JsonKey()
  final int pendingOrders;
  @override
  @JsonKey()
  final double unpaidTotal;
  final List<Product> _lowStockProducts;
  @override
  @JsonKey()
  List<Product> get lowStockProducts {
    if (_lowStockProducts is EqualUnmodifiableListView)
      return _lowStockProducts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lowStockProducts);
  }

  final List<DailySales> _weeklySales;
  @override
  @JsonKey()
  List<DailySales> get weeklySales {
    if (_weeklySales is EqualUnmodifiableListView) return _weeklySales;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weeklySales);
  }

  @override
  String toString() {
    return 'DashboardStats(todayRevenue: $todayRevenue, thisMonthRevenue: $thisMonthRevenue, thisMonthProfit: $thisMonthProfit, totalOrders: $totalOrders, pendingOrders: $pendingOrders, unpaidTotal: $unpaidTotal, lowStockProducts: $lowStockProducts, weeklySales: $weeklySales)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardStatsImpl &&
            (identical(other.todayRevenue, todayRevenue) ||
                other.todayRevenue == todayRevenue) &&
            (identical(other.thisMonthRevenue, thisMonthRevenue) ||
                other.thisMonthRevenue == thisMonthRevenue) &&
            (identical(other.thisMonthProfit, thisMonthProfit) ||
                other.thisMonthProfit == thisMonthProfit) &&
            (identical(other.totalOrders, totalOrders) ||
                other.totalOrders == totalOrders) &&
            (identical(other.pendingOrders, pendingOrders) ||
                other.pendingOrders == pendingOrders) &&
            (identical(other.unpaidTotal, unpaidTotal) ||
                other.unpaidTotal == unpaidTotal) &&
            const DeepCollectionEquality()
                .equals(other._lowStockProducts, _lowStockProducts) &&
            const DeepCollectionEquality()
                .equals(other._weeklySales, _weeklySales));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      todayRevenue,
      thisMonthRevenue,
      thisMonthProfit,
      totalOrders,
      pendingOrders,
      unpaidTotal,
      const DeepCollectionEquality().hash(_lowStockProducts),
      const DeepCollectionEquality().hash(_weeklySales));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardStatsImplCopyWith<_$DashboardStatsImpl> get copyWith =>
      __$$DashboardStatsImplCopyWithImpl<_$DashboardStatsImpl>(
          this, _$identity);
}

abstract class _DashboardStats implements DashboardStats {
  const factory _DashboardStats(
      {final double todayRevenue,
      final double thisMonthRevenue,
      final double thisMonthProfit,
      final int totalOrders,
      final int pendingOrders,
      final double unpaidTotal,
      final List<Product> lowStockProducts,
      final List<DailySales> weeklySales}) = _$DashboardStatsImpl;

  @override
  double get todayRevenue;
  @override
  double get thisMonthRevenue;
  @override
  double get thisMonthProfit;
  @override
  int get totalOrders;
  @override
  int get pendingOrders;
  @override
  double get unpaidTotal;
  @override
  List<Product> get lowStockProducts;
  @override
  List<DailySales> get weeklySales;
  @override
  @JsonKey(ignore: true)
  _$$DashboardStatsImplCopyWith<_$DashboardStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
