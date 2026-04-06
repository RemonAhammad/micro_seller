// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_combination.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const VariantCombinationSchema = Schema(
  name: r'VariantCombination',
  id: 98191113424116650,
  properties: {
    r'combinationKey': PropertySchema(
      id: 0,
      name: r'combinationKey',
      type: IsarType.string,
    ),
    r'displayLabel': PropertySchema(
      id: 1,
      name: r'displayLabel',
      type: IsarType.string,
    ),
    r'isActive': PropertySchema(
      id: 2,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'priceAdjustment': PropertySchema(
      id: 3,
      name: r'priceAdjustment',
      type: IsarType.double,
    ),
    r'sku': PropertySchema(
      id: 4,
      name: r'sku',
      type: IsarType.string,
    ),
    r'stockQty': PropertySchema(
      id: 5,
      name: r'stockQty',
      type: IsarType.long,
    )
  },
  estimateSize: _variantCombinationEstimateSize,
  serialize: _variantCombinationSerialize,
  deserialize: _variantCombinationDeserialize,
  deserializeProp: _variantCombinationDeserializeProp,
);

int _variantCombinationEstimateSize(
  VariantCombination object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.combinationKey.length * 3;
  bytesCount += 3 + object.displayLabel.length * 3;
  bytesCount += 3 + object.sku.length * 3;
  return bytesCount;
}

void _variantCombinationSerialize(
  VariantCombination object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.combinationKey);
  writer.writeString(offsets[1], object.displayLabel);
  writer.writeBool(offsets[2], object.isActive);
  writer.writeDouble(offsets[3], object.priceAdjustment);
  writer.writeString(offsets[4], object.sku);
  writer.writeLong(offsets[5], object.stockQty);
}

VariantCombination _variantCombinationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VariantCombination(
    combinationKey: reader.readStringOrNull(offsets[0]) ?? '',
    displayLabel: reader.readStringOrNull(offsets[1]) ?? '',
    isActive: reader.readBoolOrNull(offsets[2]) ?? true,
    priceAdjustment: reader.readDoubleOrNull(offsets[3]) ?? 0.0,
    sku: reader.readStringOrNull(offsets[4]) ?? '',
    stockQty: reader.readLongOrNull(offsets[5]) ?? 0,
  );
  return object;
}

P _variantCombinationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 1:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 2:
      return (reader.readBoolOrNull(offset) ?? true) as P;
    case 3:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 4:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 5:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension VariantCombinationQueryFilter
    on QueryBuilder<VariantCombination, VariantCombination, QFilterCondition> {
  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'combinationKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'combinationKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'combinationKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'combinationKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'combinationKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'combinationKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'combinationKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'combinationKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'combinationKey',
        value: '',
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      combinationKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'combinationKey',
        value: '',
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'displayLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'displayLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'displayLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'displayLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      displayLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'displayLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      priceAdjustmentEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'priceAdjustment',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      priceAdjustmentGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'priceAdjustment',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      priceAdjustmentLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'priceAdjustment',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      priceAdjustmentBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'priceAdjustment',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sku',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sku',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sku',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sku',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sku',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sku',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sku',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sku',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sku',
        value: '',
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      skuIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sku',
        value: '',
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      stockQtyEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stockQty',
        value: value,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      stockQtyGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stockQty',
        value: value,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      stockQtyLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stockQty',
        value: value,
      ));
    });
  }

  QueryBuilder<VariantCombination, VariantCombination, QAfterFilterCondition>
      stockQtyBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stockQty',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension VariantCombinationQueryObject
    on QueryBuilder<VariantCombination, VariantCombination, QFilterCondition> {}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VariantCombination _$VariantCombinationFromJson(Map<String, dynamic> json) =>
    VariantCombination(
      combinationKey: json['combinationKey'] as String? ?? '',
      displayLabel: json['displayLabel'] as String? ?? '',
      priceAdjustment: (json['priceAdjustment'] as num?)?.toDouble() ?? 0.0,
      stockQty: (json['stockQty'] as num?)?.toInt() ?? 0,
      sku: json['sku'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$VariantCombinationToJson(VariantCombination instance) =>
    <String, dynamic>{
      'combinationKey': instance.combinationKey,
      'displayLabel': instance.displayLabel,
      'priceAdjustment': instance.priceAdjustment,
      'stockQty': instance.stockQty,
      'sku': instance.sku,
      'isActive': instance.isActive,
    };
