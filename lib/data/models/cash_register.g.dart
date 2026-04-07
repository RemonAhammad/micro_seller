// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_register.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCashRegisterCollection on Isar {
  IsarCollection<CashRegister> get cashRegisters => this.collection();
}

const CashRegisterSchema = CollectionSchema(
  name: r'CashRegister',
  id: 8604440459258129516,
  properties: {
    r'closedAt': PropertySchema(
      id: 0,
      name: r'closedAt',
      type: IsarType.dateTime,
    ),
    r'closingAmount': PropertySchema(
      id: 1,
      name: r'closingAmount',
      type: IsarType.double,
    ),
    r'isClosed': PropertySchema(
      id: 2,
      name: r'isClosed',
      type: IsarType.bool,
    ),
    r'notes': PropertySchema(
      id: 3,
      name: r'notes',
      type: IsarType.string,
    ),
    r'openedAt': PropertySchema(
      id: 4,
      name: r'openedAt',
      type: IsarType.dateTime,
    ),
    r'openingAmount': PropertySchema(
      id: 5,
      name: r'openingAmount',
      type: IsarType.double,
    ),
    r'totalCashIn': PropertySchema(
      id: 6,
      name: r'totalCashIn',
      type: IsarType.double,
    ),
    r'totalCashOut': PropertySchema(
      id: 7,
      name: r'totalCashOut',
      type: IsarType.double,
    ),
    r'totalExpenses': PropertySchema(
      id: 8,
      name: r'totalExpenses',
      type: IsarType.double,
    ),
    r'totalSales': PropertySchema(
      id: 9,
      name: r'totalSales',
      type: IsarType.double,
    )
  },
  estimateSize: _cashRegisterEstimateSize,
  serialize: _cashRegisterSerialize,
  deserialize: _cashRegisterDeserialize,
  deserializeProp: _cashRegisterDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _cashRegisterGetId,
  getLinks: _cashRegisterGetLinks,
  attach: _cashRegisterAttach,
  version: '3.1.0+1',
);

int _cashRegisterEstimateSize(
  CashRegister object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.notes.length * 3;
  return bytesCount;
}

void _cashRegisterSerialize(
  CashRegister object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.closedAt);
  writer.writeDouble(offsets[1], object.closingAmount);
  writer.writeBool(offsets[2], object.isClosed);
  writer.writeString(offsets[3], object.notes);
  writer.writeDateTime(offsets[4], object.openedAt);
  writer.writeDouble(offsets[5], object.openingAmount);
  writer.writeDouble(offsets[6], object.totalCashIn);
  writer.writeDouble(offsets[7], object.totalCashOut);
  writer.writeDouble(offsets[8], object.totalExpenses);
  writer.writeDouble(offsets[9], object.totalSales);
}

CashRegister _cashRegisterDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CashRegister(
    closedAt: reader.readDateTimeOrNull(offsets[0]),
    closingAmount: reader.readDoubleOrNull(offsets[1]),
    id: id,
    isClosed: reader.readBoolOrNull(offsets[2]) ?? false,
    notes: reader.readStringOrNull(offsets[3]) ?? '',
    openedAt: reader.readDateTimeOrNull(offsets[4]),
    openingAmount: reader.readDoubleOrNull(offsets[5]) ?? 0.0,
    totalCashIn: reader.readDoubleOrNull(offsets[6]) ?? 0.0,
    totalCashOut: reader.readDoubleOrNull(offsets[7]) ?? 0.0,
    totalExpenses: reader.readDoubleOrNull(offsets[8]) ?? 0.0,
    totalSales: reader.readDoubleOrNull(offsets[9]) ?? 0.0,
  );
  return object;
}

P _cashRegisterDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 3:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 6:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 7:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 8:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 9:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cashRegisterGetId(CashRegister object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cashRegisterGetLinks(CashRegister object) {
  return [];
}

void _cashRegisterAttach(
    IsarCollection<dynamic> col, Id id, CashRegister object) {
  object.id = id;
}

extension CashRegisterQueryWhereSort
    on QueryBuilder<CashRegister, CashRegister, QWhere> {
  QueryBuilder<CashRegister, CashRegister, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CashRegisterQueryWhere
    on QueryBuilder<CashRegister, CashRegister, QWhereClause> {
  QueryBuilder<CashRegister, CashRegister, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<CashRegister, CashRegister, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CashRegisterQueryFilter
    on QueryBuilder<CashRegister, CashRegister, QFilterCondition> {
  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedAt',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedAt',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closingAmountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closingAmount',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closingAmountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closingAmount',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closingAmountEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closingAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closingAmountGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closingAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closingAmountLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closingAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      closingAmountBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closingAmount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      isClosedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isClosed',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> notesEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      notesGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> notesLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> notesBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> notesContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition> notesMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'openedAt',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'openedAt',
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openingAmountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openingAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openingAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openingAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openingAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openingAmount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      openingAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openingAmount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashInEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalCashIn',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashInGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalCashIn',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashInLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalCashIn',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashInBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalCashIn',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashOutEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalCashOut',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashOutGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalCashOut',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashOutLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalCashOut',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalCashOutBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalCashOut',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalExpensesEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalExpenses',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalExpensesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalExpenses',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalExpensesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalExpenses',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalExpensesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalExpenses',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalSalesEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalSales',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalSalesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalSales',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalSalesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalSales',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterFilterCondition>
      totalSalesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalSales',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension CashRegisterQueryObject
    on QueryBuilder<CashRegister, CashRegister, QFilterCondition> {}

extension CashRegisterQueryLinks
    on QueryBuilder<CashRegister, CashRegister, QFilterCondition> {}

extension CashRegisterQuerySortBy
    on QueryBuilder<CashRegister, CashRegister, QSortBy> {
  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByClosedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByClosingAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closingAmount', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      sortByClosingAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closingAmount', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByIsClosedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByOpeningAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openingAmount', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      sortByOpeningAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openingAmount', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByTotalCashIn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashIn', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      sortByTotalCashInDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashIn', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByTotalCashOut() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashOut', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      sortByTotalCashOutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashOut', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByTotalExpenses() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpenses', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      sortByTotalExpensesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpenses', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> sortByTotalSales() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSales', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      sortByTotalSalesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSales', Sort.desc);
    });
  }
}

extension CashRegisterQuerySortThenBy
    on QueryBuilder<CashRegister, CashRegister, QSortThenBy> {
  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByClosedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByClosingAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closingAmount', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      thenByClosingAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closingAmount', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByIsClosedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByOpeningAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openingAmount', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      thenByOpeningAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openingAmount', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByTotalCashIn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashIn', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      thenByTotalCashInDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashIn', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByTotalCashOut() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashOut', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      thenByTotalCashOutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCashOut', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByTotalExpenses() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpenses', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      thenByTotalExpensesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpenses', Sort.desc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy> thenByTotalSales() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSales', Sort.asc);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QAfterSortBy>
      thenByTotalSalesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSales', Sort.desc);
    });
  }
}

extension CashRegisterQueryWhereDistinct
    on QueryBuilder<CashRegister, CashRegister, QDistinct> {
  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedAt');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct>
      distinctByClosingAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closingAmount');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isClosed');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openedAt');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct>
      distinctByOpeningAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openingAmount');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByTotalCashIn() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCashIn');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByTotalCashOut() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCashOut');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct>
      distinctByTotalExpenses() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalExpenses');
    });
  }

  QueryBuilder<CashRegister, CashRegister, QDistinct> distinctByTotalSales() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalSales');
    });
  }
}

extension CashRegisterQueryProperty
    on QueryBuilder<CashRegister, CashRegister, QQueryProperty> {
  QueryBuilder<CashRegister, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CashRegister, DateTime?, QQueryOperations> closedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedAt');
    });
  }

  QueryBuilder<CashRegister, double?, QQueryOperations>
      closingAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closingAmount');
    });
  }

  QueryBuilder<CashRegister, bool, QQueryOperations> isClosedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isClosed');
    });
  }

  QueryBuilder<CashRegister, String, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<CashRegister, DateTime?, QQueryOperations> openedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openedAt');
    });
  }

  QueryBuilder<CashRegister, double, QQueryOperations> openingAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openingAmount');
    });
  }

  QueryBuilder<CashRegister, double, QQueryOperations> totalCashInProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCashIn');
    });
  }

  QueryBuilder<CashRegister, double, QQueryOperations> totalCashOutProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCashOut');
    });
  }

  QueryBuilder<CashRegister, double, QQueryOperations> totalExpensesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalExpenses');
    });
  }

  QueryBuilder<CashRegister, double, QQueryOperations> totalSalesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalSales');
    });
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CashRegister _$CashRegisterFromJson(Map<String, dynamic> json) => CashRegister(
      id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
      openingAmount: (json['openingAmount'] as num?)?.toDouble() ?? 0.0,
      closingAmount: (json['closingAmount'] as num?)?.toDouble(),
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      totalCashIn: (json['totalCashIn'] as num?)?.toDouble() ?? 0.0,
      totalCashOut: (json['totalCashOut'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
      isClosed: json['isClosed'] as bool? ?? false,
      openedAt: json['openedAt'] == null
          ? null
          : DateTime.parse(json['openedAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
    );

Map<String, dynamic> _$CashRegisterToJson(CashRegister instance) =>
    <String, dynamic>{
      'id': instance.id,
      'openingAmount': instance.openingAmount,
      'closingAmount': instance.closingAmount,
      'totalSales': instance.totalSales,
      'totalExpenses': instance.totalExpenses,
      'totalCashIn': instance.totalCashIn,
      'totalCashOut': instance.totalCashOut,
      'notes': instance.notes,
      'isClosed': instance.isClosed,
      'openedAt': instance.openedAt?.toIso8601String(),
      'closedAt': instance.closedAt?.toIso8601String(),
    };
