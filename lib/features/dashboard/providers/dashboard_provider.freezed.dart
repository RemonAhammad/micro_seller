// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DailySales {

 DateTime get date; double get revenue; double get profit;
/// Create a copy of DailySales
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailySalesCopyWith<DailySales> get copyWith => _$DailySalesCopyWithImpl<DailySales>(this as DailySales, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailySales&&(identical(other.date, date) || other.date == date)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.profit, profit) || other.profit == profit));
}


@override
int get hashCode => Object.hash(runtimeType,date,revenue,profit);

@override
String toString() {
  return 'DailySales(date: $date, revenue: $revenue, profit: $profit)';
}


}

/// @nodoc
abstract mixin class $DailySalesCopyWith<$Res>  {
  factory $DailySalesCopyWith(DailySales value, $Res Function(DailySales) _then) = _$DailySalesCopyWithImpl;
@useResult
$Res call({
 DateTime date, double revenue, double profit
});




}
/// @nodoc
class _$DailySalesCopyWithImpl<$Res>
    implements $DailySalesCopyWith<$Res> {
  _$DailySalesCopyWithImpl(this._self, this._then);

  final DailySales _self;
  final $Res Function(DailySales) _then;

/// Create a copy of DailySales
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? revenue = null,Object? profit = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as double,profit: null == profit ? _self.profit : profit // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DailySales].
extension DailySalesPatterns on DailySales {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailySales value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailySales() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailySales value)  $default,){
final _that = this;
switch (_that) {
case _DailySales():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailySales value)?  $default,){
final _that = this;
switch (_that) {
case _DailySales() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime date,  double revenue,  double profit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailySales() when $default != null:
return $default(_that.date,_that.revenue,_that.profit);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime date,  double revenue,  double profit)  $default,) {final _that = this;
switch (_that) {
case _DailySales():
return $default(_that.date,_that.revenue,_that.profit);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime date,  double revenue,  double profit)?  $default,) {final _that = this;
switch (_that) {
case _DailySales() when $default != null:
return $default(_that.date,_that.revenue,_that.profit);case _:
  return null;

}
}

}

/// @nodoc


class _DailySales implements DailySales {
  const _DailySales({required this.date, required this.revenue, required this.profit});
  

@override final  DateTime date;
@override final  double revenue;
@override final  double profit;

/// Create a copy of DailySales
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailySalesCopyWith<_DailySales> get copyWith => __$DailySalesCopyWithImpl<_DailySales>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailySales&&(identical(other.date, date) || other.date == date)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.profit, profit) || other.profit == profit));
}


@override
int get hashCode => Object.hash(runtimeType,date,revenue,profit);

@override
String toString() {
  return 'DailySales(date: $date, revenue: $revenue, profit: $profit)';
}


}

/// @nodoc
abstract mixin class _$DailySalesCopyWith<$Res> implements $DailySalesCopyWith<$Res> {
  factory _$DailySalesCopyWith(_DailySales value, $Res Function(_DailySales) _then) = __$DailySalesCopyWithImpl;
@override @useResult
$Res call({
 DateTime date, double revenue, double profit
});




}
/// @nodoc
class __$DailySalesCopyWithImpl<$Res>
    implements _$DailySalesCopyWith<$Res> {
  __$DailySalesCopyWithImpl(this._self, this._then);

  final _DailySales _self;
  final $Res Function(_DailySales) _then;

/// Create a copy of DailySales
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? revenue = null,Object? profit = null,}) {
  return _then(_DailySales(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as double,profit: null == profit ? _self.profit : profit // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$DashboardStats {

 double get todayRevenue; double get thisMonthRevenue; double get thisMonthProfit; int get totalOrders; int get pendingOrders; List<Product> get lowStockProducts; List<DailySales> get weeklySales;
/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardStatsCopyWith<DashboardStats> get copyWith => _$DashboardStatsCopyWithImpl<DashboardStats>(this as DashboardStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardStats&&(identical(other.todayRevenue, todayRevenue) || other.todayRevenue == todayRevenue)&&(identical(other.thisMonthRevenue, thisMonthRevenue) || other.thisMonthRevenue == thisMonthRevenue)&&(identical(other.thisMonthProfit, thisMonthProfit) || other.thisMonthProfit == thisMonthProfit)&&(identical(other.totalOrders, totalOrders) || other.totalOrders == totalOrders)&&(identical(other.pendingOrders, pendingOrders) || other.pendingOrders == pendingOrders)&&const DeepCollectionEquality().equals(other.lowStockProducts, lowStockProducts)&&const DeepCollectionEquality().equals(other.weeklySales, weeklySales));
}


@override
int get hashCode => Object.hash(runtimeType,todayRevenue,thisMonthRevenue,thisMonthProfit,totalOrders,pendingOrders,const DeepCollectionEquality().hash(lowStockProducts),const DeepCollectionEquality().hash(weeklySales));

@override
String toString() {
  return 'DashboardStats(todayRevenue: $todayRevenue, thisMonthRevenue: $thisMonthRevenue, thisMonthProfit: $thisMonthProfit, totalOrders: $totalOrders, pendingOrders: $pendingOrders, lowStockProducts: $lowStockProducts, weeklySales: $weeklySales)';
}


}

/// @nodoc
abstract mixin class $DashboardStatsCopyWith<$Res>  {
  factory $DashboardStatsCopyWith(DashboardStats value, $Res Function(DashboardStats) _then) = _$DashboardStatsCopyWithImpl;
@useResult
$Res call({
 double todayRevenue, double thisMonthRevenue, double thisMonthProfit, int totalOrders, int pendingOrders, List<Product> lowStockProducts, List<DailySales> weeklySales
});




}
/// @nodoc
class _$DashboardStatsCopyWithImpl<$Res>
    implements $DashboardStatsCopyWith<$Res> {
  _$DashboardStatsCopyWithImpl(this._self, this._then);

  final DashboardStats _self;
  final $Res Function(DashboardStats) _then;

/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? todayRevenue = null,Object? thisMonthRevenue = null,Object? thisMonthProfit = null,Object? totalOrders = null,Object? pendingOrders = null,Object? lowStockProducts = null,Object? weeklySales = null,}) {
  return _then(_self.copyWith(
todayRevenue: null == todayRevenue ? _self.todayRevenue : todayRevenue // ignore: cast_nullable_to_non_nullable
as double,thisMonthRevenue: null == thisMonthRevenue ? _self.thisMonthRevenue : thisMonthRevenue // ignore: cast_nullable_to_non_nullable
as double,thisMonthProfit: null == thisMonthProfit ? _self.thisMonthProfit : thisMonthProfit // ignore: cast_nullable_to_non_nullable
as double,totalOrders: null == totalOrders ? _self.totalOrders : totalOrders // ignore: cast_nullable_to_non_nullable
as int,pendingOrders: null == pendingOrders ? _self.pendingOrders : pendingOrders // ignore: cast_nullable_to_non_nullable
as int,lowStockProducts: null == lowStockProducts ? _self.lowStockProducts : lowStockProducts // ignore: cast_nullable_to_non_nullable
as List<Product>,weeklySales: null == weeklySales ? _self.weeklySales : weeklySales // ignore: cast_nullable_to_non_nullable
as List<DailySales>,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardStats].
extension DashboardStatsPatterns on DashboardStats {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardStats value)  $default,){
final _that = this;
switch (_that) {
case _DashboardStats():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardStats value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double todayRevenue,  double thisMonthRevenue,  double thisMonthProfit,  int totalOrders,  int pendingOrders,  List<Product> lowStockProducts,  List<DailySales> weeklySales)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
return $default(_that.todayRevenue,_that.thisMonthRevenue,_that.thisMonthProfit,_that.totalOrders,_that.pendingOrders,_that.lowStockProducts,_that.weeklySales);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double todayRevenue,  double thisMonthRevenue,  double thisMonthProfit,  int totalOrders,  int pendingOrders,  List<Product> lowStockProducts,  List<DailySales> weeklySales)  $default,) {final _that = this;
switch (_that) {
case _DashboardStats():
return $default(_that.todayRevenue,_that.thisMonthRevenue,_that.thisMonthProfit,_that.totalOrders,_that.pendingOrders,_that.lowStockProducts,_that.weeklySales);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double todayRevenue,  double thisMonthRevenue,  double thisMonthProfit,  int totalOrders,  int pendingOrders,  List<Product> lowStockProducts,  List<DailySales> weeklySales)?  $default,) {final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
return $default(_that.todayRevenue,_that.thisMonthRevenue,_that.thisMonthProfit,_that.totalOrders,_that.pendingOrders,_that.lowStockProducts,_that.weeklySales);case _:
  return null;

}
}

}

/// @nodoc


class _DashboardStats implements DashboardStats {
  const _DashboardStats({this.todayRevenue = 0.0, this.thisMonthRevenue = 0.0, this.thisMonthProfit = 0.0, this.totalOrders = 0, this.pendingOrders = 0, final  List<Product> lowStockProducts = const [], final  List<DailySales> weeklySales = const []}): _lowStockProducts = lowStockProducts,_weeklySales = weeklySales;
  

@override@JsonKey() final  double todayRevenue;
@override@JsonKey() final  double thisMonthRevenue;
@override@JsonKey() final  double thisMonthProfit;
@override@JsonKey() final  int totalOrders;
@override@JsonKey() final  int pendingOrders;
 final  List<Product> _lowStockProducts;
@override@JsonKey() List<Product> get lowStockProducts {
  if (_lowStockProducts is EqualUnmodifiableListView) return _lowStockProducts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lowStockProducts);
}

 final  List<DailySales> _weeklySales;
@override@JsonKey() List<DailySales> get weeklySales {
  if (_weeklySales is EqualUnmodifiableListView) return _weeklySales;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weeklySales);
}


/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardStatsCopyWith<_DashboardStats> get copyWith => __$DashboardStatsCopyWithImpl<_DashboardStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardStats&&(identical(other.todayRevenue, todayRevenue) || other.todayRevenue == todayRevenue)&&(identical(other.thisMonthRevenue, thisMonthRevenue) || other.thisMonthRevenue == thisMonthRevenue)&&(identical(other.thisMonthProfit, thisMonthProfit) || other.thisMonthProfit == thisMonthProfit)&&(identical(other.totalOrders, totalOrders) || other.totalOrders == totalOrders)&&(identical(other.pendingOrders, pendingOrders) || other.pendingOrders == pendingOrders)&&const DeepCollectionEquality().equals(other._lowStockProducts, _lowStockProducts)&&const DeepCollectionEquality().equals(other._weeklySales, _weeklySales));
}


@override
int get hashCode => Object.hash(runtimeType,todayRevenue,thisMonthRevenue,thisMonthProfit,totalOrders,pendingOrders,const DeepCollectionEquality().hash(_lowStockProducts),const DeepCollectionEquality().hash(_weeklySales));

@override
String toString() {
  return 'DashboardStats(todayRevenue: $todayRevenue, thisMonthRevenue: $thisMonthRevenue, thisMonthProfit: $thisMonthProfit, totalOrders: $totalOrders, pendingOrders: $pendingOrders, lowStockProducts: $lowStockProducts, weeklySales: $weeklySales)';
}


}

/// @nodoc
abstract mixin class _$DashboardStatsCopyWith<$Res> implements $DashboardStatsCopyWith<$Res> {
  factory _$DashboardStatsCopyWith(_DashboardStats value, $Res Function(_DashboardStats) _then) = __$DashboardStatsCopyWithImpl;
@override @useResult
$Res call({
 double todayRevenue, double thisMonthRevenue, double thisMonthProfit, int totalOrders, int pendingOrders, List<Product> lowStockProducts, List<DailySales> weeklySales
});




}
/// @nodoc
class __$DashboardStatsCopyWithImpl<$Res>
    implements _$DashboardStatsCopyWith<$Res> {
  __$DashboardStatsCopyWithImpl(this._self, this._then);

  final _DashboardStats _self;
  final $Res Function(_DashboardStats) _then;

/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? todayRevenue = null,Object? thisMonthRevenue = null,Object? thisMonthProfit = null,Object? totalOrders = null,Object? pendingOrders = null,Object? lowStockProducts = null,Object? weeklySales = null,}) {
  return _then(_DashboardStats(
todayRevenue: null == todayRevenue ? _self.todayRevenue : todayRevenue // ignore: cast_nullable_to_non_nullable
as double,thisMonthRevenue: null == thisMonthRevenue ? _self.thisMonthRevenue : thisMonthRevenue // ignore: cast_nullable_to_non_nullable
as double,thisMonthProfit: null == thisMonthProfit ? _self.thisMonthProfit : thisMonthProfit // ignore: cast_nullable_to_non_nullable
as double,totalOrders: null == totalOrders ? _self.totalOrders : totalOrders // ignore: cast_nullable_to_non_nullable
as int,pendingOrders: null == pendingOrders ? _self.pendingOrders : pendingOrders // ignore: cast_nullable_to_non_nullable
as int,lowStockProducts: null == lowStockProducts ? _self._lowStockProducts : lowStockProducts // ignore: cast_nullable_to_non_nullable
as List<Product>,weeklySales: null == weeklySales ? _self._weeklySales : weeklySales // ignore: cast_nullable_to_non_nullable
as List<DailySales>,
  ));
}


}

// dart format on
