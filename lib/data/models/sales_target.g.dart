// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_target.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetSalesTargetCollection on Isar {
  IsarCollection<SalesTarget> get salesTargets => this.collection();
}

const SalesTargetSchema = CollectionSchema(
  name: r'SalesTarget',
  id: 2816153584594332438,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'hasAnyTarget': PropertySchema(
      id: 1,
      name: r'hasAnyTarget',
      type: IsarType.bool,
    ),
    r'month': PropertySchema(id: 2, name: r'month', type: IsarType.long),
    r'orderCountTarget': PropertySchema(
      id: 3,
      name: r'orderCountTarget',
      type: IsarType.long,
    ),
    r'productTargets': PropertySchema(
      id: 4,
      name: r'productTargets',
      type: IsarType.objectList,

      target: r'ProductTarget',
    ),
    r'profitTarget': PropertySchema(
      id: 5,
      name: r'profitTarget',
      type: IsarType.double,
    ),
    r'revenueTarget': PropertySchema(
      id: 6,
      name: r'revenueTarget',
      type: IsarType.double,
    ),
    r'updatedAt': PropertySchema(
      id: 7,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'year': PropertySchema(id: 8, name: r'year', type: IsarType.long),
  },

  estimateSize: _salesTargetEstimateSize,
  serialize: _salesTargetSerialize,
  deserialize: _salesTargetDeserialize,
  deserializeProp: _salesTargetDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {r'ProductTarget': ProductTargetSchema},

  getId: _salesTargetGetId,
  getLinks: _salesTargetGetLinks,
  attach: _salesTargetAttach,
  version: '3.4.1',
);

int _salesTargetEstimateSize(
  SalesTarget object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.productTargets.length * 3;
  {
    final offsets = allOffsets[ProductTarget]!;
    for (var i = 0; i < object.productTargets.length; i++) {
      final value = object.productTargets[i];
      bytesCount += ProductTargetSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  return bytesCount;
}

void _salesTargetSerialize(
  SalesTarget object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeBool(offsets[1], object.hasAnyTarget);
  writer.writeLong(offsets[2], object.month);
  writer.writeLong(offsets[3], object.orderCountTarget);
  writer.writeObjectList<ProductTarget>(
    offsets[4],
    allOffsets,
    ProductTargetSchema.serialize,
    object.productTargets,
  );
  writer.writeDouble(offsets[5], object.profitTarget);
  writer.writeDouble(offsets[6], object.revenueTarget);
  writer.writeDateTime(offsets[7], object.updatedAt);
  writer.writeLong(offsets[8], object.year);
}

SalesTarget _salesTargetDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SalesTarget(
    createdAt: reader.readDateTimeOrNull(offsets[0]),
    id: id,
    month: reader.readLong(offsets[2]),
    orderCountTarget: reader.readLongOrNull(offsets[3]) ?? 0,
    productTargets:
        reader.readObjectList<ProductTarget>(
          offsets[4],
          ProductTargetSchema.deserialize,
          allOffsets,
          ProductTarget(),
        ) ??
        const [],
    profitTarget: reader.readDoubleOrNull(offsets[5]) ?? 0,
    revenueTarget: reader.readDoubleOrNull(offsets[6]) ?? 0,
    updatedAt: reader.readDateTimeOrNull(offsets[7]),
    year: reader.readLong(offsets[8]),
  );
  return object;
}

P _salesTargetDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 4:
      return (reader.readObjectList<ProductTarget>(
                offset,
                ProductTargetSchema.deserialize,
                allOffsets,
                ProductTarget(),
              ) ??
              const [])
          as P;
    case 5:
      return (reader.readDoubleOrNull(offset) ?? 0) as P;
    case 6:
      return (reader.readDoubleOrNull(offset) ?? 0) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _salesTargetGetId(SalesTarget object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _salesTargetGetLinks(SalesTarget object) {
  return [];
}

void _salesTargetAttach(
  IsarCollection<dynamic> col,
  Id id,
  SalesTarget object,
) {
  object.id = id;
}

extension SalesTargetQueryWhereSort
    on QueryBuilder<SalesTarget, SalesTarget, QWhere> {
  QueryBuilder<SalesTarget, SalesTarget, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SalesTargetQueryWhere
    on QueryBuilder<SalesTarget, SalesTarget, QWhereClause> {
  QueryBuilder<SalesTarget, SalesTarget, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SalesTargetQueryFilter
    on QueryBuilder<SalesTarget, SalesTarget, QFilterCondition> {
  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  createdAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  hasAnyTargetEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hasAnyTarget', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> monthEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'month', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  monthGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'month',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> monthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'month',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> monthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'month',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  orderCountTargetEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'orderCountTarget', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  orderCountTargetGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'orderCountTarget',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  orderCountTargetLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'orderCountTarget',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  orderCountTargetBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'orderCountTarget',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'productTargets', length, true, length, true);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'productTargets', 0, true, 0, true);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'productTargets', 0, false, 999999, true);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'productTargets', 0, true, length, include);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'productTargets', length, include, 999999, true);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productTargets',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  profitTargetEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'profitTarget',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  profitTargetGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'profitTarget',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  profitTargetLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'profitTarget',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  profitTargetBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'profitTarget',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  revenueTargetEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'revenueTarget',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  revenueTargetGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'revenueTarget',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  revenueTargetLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'revenueTarget',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  revenueTargetBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'revenueTarget',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  updatedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> yearEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'year', value: value),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> yearGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'year',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> yearLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'year',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition> yearBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'year',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SalesTargetQueryObject
    on QueryBuilder<SalesTarget, SalesTarget, QFilterCondition> {
  QueryBuilder<SalesTarget, SalesTarget, QAfterFilterCondition>
  productTargetsElement(FilterQuery<ProductTarget> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'productTargets');
    });
  }
}

extension SalesTargetQueryLinks
    on QueryBuilder<SalesTarget, SalesTarget, QFilterCondition> {}

extension SalesTargetQuerySortBy
    on QueryBuilder<SalesTarget, SalesTarget, QSortBy> {
  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByHasAnyTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAnyTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  sortByHasAnyTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAnyTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByMonth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'month', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByMonthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'month', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  sortByOrderCountTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderCountTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  sortByOrderCountTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderCountTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByProfitTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  sortByProfitTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByRevenueTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revenueTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  sortByRevenueTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revenueTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> sortByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension SalesTargetQuerySortThenBy
    on QueryBuilder<SalesTarget, SalesTarget, QSortThenBy> {
  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByHasAnyTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAnyTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  thenByHasAnyTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAnyTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByMonth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'month', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByMonthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'month', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  thenByOrderCountTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderCountTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  thenByOrderCountTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderCountTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByProfitTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  thenByProfitTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByRevenueTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revenueTarget', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy>
  thenByRevenueTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revenueTarget', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QAfterSortBy> thenByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension SalesTargetQueryWhereDistinct
    on QueryBuilder<SalesTarget, SalesTarget, QDistinct> {
  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByHasAnyTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasAnyTarget');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByMonth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'month');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct>
  distinctByOrderCountTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'orderCountTarget');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByProfitTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'profitTarget');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByRevenueTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revenueTarget');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<SalesTarget, SalesTarget, QDistinct> distinctByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'year');
    });
  }
}

extension SalesTargetQueryProperty
    on QueryBuilder<SalesTarget, SalesTarget, QQueryProperty> {
  QueryBuilder<SalesTarget, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SalesTarget, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SalesTarget, bool, QQueryOperations> hasAnyTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasAnyTarget');
    });
  }

  QueryBuilder<SalesTarget, int, QQueryOperations> monthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'month');
    });
  }

  QueryBuilder<SalesTarget, int, QQueryOperations> orderCountTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'orderCountTarget');
    });
  }

  QueryBuilder<SalesTarget, List<ProductTarget>, QQueryOperations>
  productTargetsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productTargets');
    });
  }

  QueryBuilder<SalesTarget, double, QQueryOperations> profitTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'profitTarget');
    });
  }

  QueryBuilder<SalesTarget, double, QQueryOperations> revenueTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revenueTarget');
    });
  }

  QueryBuilder<SalesTarget, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<SalesTarget, int, QQueryOperations> yearProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'year');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

const ProductTargetSchema = Schema(
  name: r'ProductTarget',
  id: -8137881665921836431,
  properties: {
    r'productId': PropertySchema(
      id: 0,
      name: r'productId',
      type: IsarType.long,
    ),
    r'productName': PropertySchema(
      id: 1,
      name: r'productName',
      type: IsarType.string,
    ),
    r'targetQty': PropertySchema(
      id: 2,
      name: r'targetQty',
      type: IsarType.long,
    ),
  },

  estimateSize: _productTargetEstimateSize,
  serialize: _productTargetSerialize,
  deserialize: _productTargetDeserialize,
  deserializeProp: _productTargetDeserializeProp,
);

int _productTargetEstimateSize(
  ProductTarget object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.productName.length * 3;
  return bytesCount;
}

void _productTargetSerialize(
  ProductTarget object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.productId);
  writer.writeString(offsets[1], object.productName);
  writer.writeLong(offsets[2], object.targetQty);
}

ProductTarget _productTargetDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ProductTarget(
    productId: reader.readLongOrNull(offsets[0]) ?? 0,
    productName: reader.readStringOrNull(offsets[1]) ?? '',
    targetQty: reader.readLongOrNull(offsets[2]) ?? 0,
  );
  return object;
}

P _productTargetDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 2:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension ProductTargetQueryFilter
    on QueryBuilder<ProductTarget, ProductTarget, QFilterCondition> {
  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productId', value: value),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'productId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'productId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'productId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'productName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'productName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productName', value: ''),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  productNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'productName', value: ''),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  targetQtyEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetQty', value: value),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  targetQtyGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetQty',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  targetQtyLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetQty',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ProductTarget, ProductTarget, QAfterFilterCondition>
  targetQtyBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetQty',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ProductTargetQueryObject
    on QueryBuilder<ProductTarget, ProductTarget, QFilterCondition> {}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesTarget _$SalesTargetFromJson(Map<String, dynamic> json) => SalesTarget(
  id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
  year: (json['year'] as num).toInt(),
  month: (json['month'] as num).toInt(),
  revenueTarget: (json['revenueTarget'] as num?)?.toDouble() ?? 0,
  profitTarget: (json['profitTarget'] as num?)?.toDouble() ?? 0,
  orderCountTarget: (json['orderCountTarget'] as num?)?.toInt() ?? 0,
  productTargets:
      (json['productTargets'] as List<dynamic>?)
          ?.map((e) => ProductTarget.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SalesTargetToJson(SalesTarget instance) =>
    <String, dynamic>{
      'id': instance.id,
      'year': instance.year,
      'month': instance.month,
      'revenueTarget': instance.revenueTarget,
      'profitTarget': instance.profitTarget,
      'orderCountTarget': instance.orderCountTarget,
      'productTargets': instance.productTargets,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

ProductTarget _$ProductTargetFromJson(Map<String, dynamic> json) =>
    ProductTarget(
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productName'] as String? ?? '',
      targetQty: (json['targetQty'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ProductTargetToJson(ProductTarget instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'targetQty': instance.targetQty,
    };
