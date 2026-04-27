// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOrderCollection on Isar {
  IsarCollection<Order> get orders => this.collection();
}

const OrderSchema = CollectionSchema(
  name: r'Order',
  id: 103494837486634173,
  properties: {
    r'actualDeliveryDate': PropertySchema(
      id: 0,
      name: r'actualDeliveryDate',
      type: IsarType.dateTime,
    ),
    r'amountPaid': PropertySchema(
      id: 1,
      name: r'amountPaid',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'customerId': PropertySchema(
      id: 3,
      name: r'customerId',
      type: IsarType.long,
    ),
    r'customerName': PropertySchema(
      id: 4,
      name: r'customerName',
      type: IsarType.string,
    ),
    r'customerPhone': PropertySchema(
      id: 5,
      name: r'customerPhone',
      type: IsarType.string,
    ),
    r'deliveryAddress': PropertySchema(
      id: 6,
      name: r'deliveryAddress',
      type: IsarType.string,
    ),
    r'deliveryFee': PropertySchema(
      id: 7,
      name: r'deliveryFee',
      type: IsarType.double,
    ),
    r'discountAmount': PropertySchema(
      id: 8,
      name: r'discountAmount',
      type: IsarType.double,
    ),
    r'estimatedDeliveryDate': PropertySchema(
      id: 9,
      name: r'estimatedDeliveryDate',
      type: IsarType.dateTime,
    ),
    r'isRecurring': PropertySchema(
      id: 10,
      name: r'isRecurring',
      type: IsarType.bool,
    ),
    r'isReturn': PropertySchema(id: 11, name: r'isReturn', type: IsarType.bool),
    r'items': PropertySchema(
      id: 12,
      name: r'items',
      type: IsarType.objectList,

      target: r'OrderItem',
    ),
    r'nextRecurringDate': PropertySchema(
      id: 13,
      name: r'nextRecurringDate',
      type: IsarType.dateTime,
    ),
    r'notes': PropertySchema(id: 14, name: r'notes', type: IsarType.string),
    r'orderNumber': PropertySchema(
      id: 15,
      name: r'orderNumber',
      type: IsarType.string,
    ),
    r'orderStatus': PropertySchema(
      id: 16,
      name: r'orderStatus',
      type: IsarType.string,
      enumMap: _OrderorderStatusEnumValueMap,
    ),
    r'originalOrderId': PropertySchema(
      id: 17,
      name: r'originalOrderId',
      type: IsarType.long,
    ),
    r'paymentMethod': PropertySchema(
      id: 18,
      name: r'paymentMethod',
      type: IsarType.string,
      enumMap: _OrderpaymentMethodEnumValueMap,
    ),
    r'paymentStatus': PropertySchema(
      id: 19,
      name: r'paymentStatus',
      type: IsarType.string,
      enumMap: _OrderpaymentStatusEnumValueMap,
    ),
    r'recurringIntervalDays': PropertySchema(
      id: 20,
      name: r'recurringIntervalDays',
      type: IsarType.long,
    ),
    r'refundAmount': PropertySchema(
      id: 21,
      name: r'refundAmount',
      type: IsarType.double,
    ),
    r'returnNotes': PropertySchema(
      id: 22,
      name: r'returnNotes',
      type: IsarType.string,
    ),
    r'returnReason': PropertySchema(
      id: 23,
      name: r'returnReason',
      type: IsarType.string,
      enumMap: _OrderreturnReasonEnumValueMap,
    ),
    r'returnStatus': PropertySchema(
      id: 24,
      name: r'returnStatus',
      type: IsarType.string,
      enumMap: _OrderreturnStatusEnumValueMap,
    ),
    r'subtotal': PropertySchema(
      id: 25,
      name: r'subtotal',
      type: IsarType.double,
    ),
    r'taxAmount': PropertySchema(
      id: 26,
      name: r'taxAmount',
      type: IsarType.double,
    ),
    r'totalAmount': PropertySchema(
      id: 27,
      name: r'totalAmount',
      type: IsarType.double,
    ),
    r'transactionId': PropertySchema(
      id: 28,
      name: r'transactionId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 29,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _orderEstimateSize,
  serialize: _orderSerialize,
  deserialize: _orderDeserialize,
  deserializeProp: _orderDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {r'OrderItem': OrderItemSchema},

  getId: _orderGetId,
  getLinks: _orderGetLinks,
  attach: _orderAttach,
  version: '3.3.2',
);

int _orderEstimateSize(
  Order object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.customerName.length * 3;
  bytesCount += 3 + object.customerPhone.length * 3;
  bytesCount += 3 + object.deliveryAddress.length * 3;
  bytesCount += 3 + object.items.length * 3;
  {
    final offsets = allOffsets[OrderItem]!;
    for (var i = 0; i < object.items.length; i++) {
      final value = object.items[i];
      bytesCount += OrderItemSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.notes.length * 3;
  bytesCount += 3 + object.orderNumber.length * 3;
  bytesCount += 3 + object.orderStatus.name.length * 3;
  bytesCount += 3 + object.paymentMethod.name.length * 3;
  bytesCount += 3 + object.paymentStatus.name.length * 3;
  bytesCount += 3 + object.returnNotes.length * 3;
  bytesCount += 3 + object.returnReason.name.length * 3;
  bytesCount += 3 + object.returnStatus.name.length * 3;
  bytesCount += 3 + object.transactionId.length * 3;
  return bytesCount;
}

void _orderSerialize(
  Order object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.actualDeliveryDate);
  writer.writeDouble(offsets[1], object.amountPaid);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeLong(offsets[3], object.customerId);
  writer.writeString(offsets[4], object.customerName);
  writer.writeString(offsets[5], object.customerPhone);
  writer.writeString(offsets[6], object.deliveryAddress);
  writer.writeDouble(offsets[7], object.deliveryFee);
  writer.writeDouble(offsets[8], object.discountAmount);
  writer.writeDateTime(offsets[9], object.estimatedDeliveryDate);
  writer.writeBool(offsets[10], object.isRecurring);
  writer.writeBool(offsets[11], object.isReturn);
  writer.writeObjectList<OrderItem>(
    offsets[12],
    allOffsets,
    OrderItemSchema.serialize,
    object.items,
  );
  writer.writeDateTime(offsets[13], object.nextRecurringDate);
  writer.writeString(offsets[14], object.notes);
  writer.writeString(offsets[15], object.orderNumber);
  writer.writeString(offsets[16], object.orderStatus.name);
  writer.writeLong(offsets[17], object.originalOrderId);
  writer.writeString(offsets[18], object.paymentMethod.name);
  writer.writeString(offsets[19], object.paymentStatus.name);
  writer.writeLong(offsets[20], object.recurringIntervalDays);
  writer.writeDouble(offsets[21], object.refundAmount);
  writer.writeString(offsets[22], object.returnNotes);
  writer.writeString(offsets[23], object.returnReason.name);
  writer.writeString(offsets[24], object.returnStatus.name);
  writer.writeDouble(offsets[25], object.subtotal);
  writer.writeDouble(offsets[26], object.taxAmount);
  writer.writeDouble(offsets[27], object.totalAmount);
  writer.writeString(offsets[28], object.transactionId);
  writer.writeDateTime(offsets[29], object.updatedAt);
}

Order _orderDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Order(
    actualDeliveryDate: reader.readDateTimeOrNull(offsets[0]),
    amountPaid: reader.readDoubleOrNull(offsets[1]) ?? 0.0,
    createdAt: reader.readDateTimeOrNull(offsets[2]),
    customerId: reader.readLongOrNull(offsets[3]) ?? 0,
    customerName: reader.readStringOrNull(offsets[4]) ?? '',
    customerPhone: reader.readStringOrNull(offsets[5]) ?? '',
    deliveryAddress: reader.readStringOrNull(offsets[6]) ?? '',
    deliveryFee: reader.readDoubleOrNull(offsets[7]) ?? 0.0,
    discountAmount: reader.readDoubleOrNull(offsets[8]) ?? 0.0,
    estimatedDeliveryDate: reader.readDateTimeOrNull(offsets[9]),
    id: id,
    isRecurring: reader.readBoolOrNull(offsets[10]) ?? false,
    isReturn: reader.readBoolOrNull(offsets[11]) ?? false,
    items:
        reader.readObjectList<OrderItem>(
          offsets[12],
          OrderItemSchema.deserialize,
          allOffsets,
          OrderItem(),
        ) ??
        const [],
    nextRecurringDate: reader.readDateTimeOrNull(offsets[13]),
    notes: reader.readStringOrNull(offsets[14]) ?? '',
    orderNumber: reader.readStringOrNull(offsets[15]) ?? '',
    orderStatus:
        _OrderorderStatusValueEnumMap[reader.readStringOrNull(offsets[16])] ??
        OrderStatus.pending,
    originalOrderId: reader.readLongOrNull(offsets[17]) ?? 0,
    paymentMethod:
        _OrderpaymentMethodValueEnumMap[reader.readStringOrNull(offsets[18])] ??
        PaymentMethod.cash,
    paymentStatus:
        _OrderpaymentStatusValueEnumMap[reader.readStringOrNull(offsets[19])] ??
        PaymentStatus.unpaid,
    recurringIntervalDays: reader.readLongOrNull(offsets[20]) ?? 0,
    refundAmount: reader.readDoubleOrNull(offsets[21]) ?? 0.0,
    returnNotes: reader.readStringOrNull(offsets[22]) ?? '',
    returnReason:
        _OrderreturnReasonValueEnumMap[reader.readStringOrNull(offsets[23])] ??
        ReturnReason.other,
    returnStatus:
        _OrderreturnStatusValueEnumMap[reader.readStringOrNull(offsets[24])] ??
        ReturnStatus.none,
    subtotal: reader.readDoubleOrNull(offsets[25]) ?? 0.0,
    taxAmount: reader.readDoubleOrNull(offsets[26]) ?? 0.0,
    totalAmount: reader.readDoubleOrNull(offsets[27]) ?? 0.0,
    transactionId: reader.readStringOrNull(offsets[28]) ?? '',
    updatedAt: reader.readDateTimeOrNull(offsets[29]),
  );
  return object;
}

P _orderDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 4:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 5:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 6:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 7:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 8:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 11:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 12:
      return (reader.readObjectList<OrderItem>(
                offset,
                OrderItemSchema.deserialize,
                allOffsets,
                OrderItem(),
              ) ??
              const [])
          as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 15:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 16:
      return (_OrderorderStatusValueEnumMap[reader.readStringOrNull(offset)] ??
              OrderStatus.pending)
          as P;
    case 17:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 18:
      return (_OrderpaymentMethodValueEnumMap[reader.readStringOrNull(
                offset,
              )] ??
              PaymentMethod.cash)
          as P;
    case 19:
      return (_OrderpaymentStatusValueEnumMap[reader.readStringOrNull(
                offset,
              )] ??
              PaymentStatus.unpaid)
          as P;
    case 20:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 21:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 22:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 23:
      return (_OrderreturnReasonValueEnumMap[reader.readStringOrNull(offset)] ??
              ReturnReason.other)
          as P;
    case 24:
      return (_OrderreturnStatusValueEnumMap[reader.readStringOrNull(offset)] ??
              ReturnStatus.none)
          as P;
    case 25:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 26:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 27:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 28:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 29:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _OrderorderStatusEnumValueMap = {
  r'pending': r'pending',
  r'confirmed': r'confirmed',
  r'shipped': r'shipped',
  r'completed': r'completed',
  r'cancelled': r'cancelled',
};
const _OrderorderStatusValueEnumMap = {
  r'pending': OrderStatus.pending,
  r'confirmed': OrderStatus.confirmed,
  r'shipped': OrderStatus.shipped,
  r'completed': OrderStatus.completed,
  r'cancelled': OrderStatus.cancelled,
};
const _OrderpaymentMethodEnumValueMap = {
  r'cash': r'cash',
  r'card': r'card',
  r'mfs': r'mfs',
  r'bank': r'bank',
  r'other': r'other',
};
const _OrderpaymentMethodValueEnumMap = {
  r'cash': PaymentMethod.cash,
  r'card': PaymentMethod.card,
  r'mfs': PaymentMethod.mfs,
  r'bank': PaymentMethod.bank,
  r'other': PaymentMethod.other,
};
const _OrderpaymentStatusEnumValueMap = {
  r'unpaid': r'unpaid',
  r'partial': r'partial',
  r'paid': r'paid',
};
const _OrderpaymentStatusValueEnumMap = {
  r'unpaid': PaymentStatus.unpaid,
  r'partial': PaymentStatus.partial,
  r'paid': PaymentStatus.paid,
};
const _OrderreturnReasonEnumValueMap = {
  r'defective': r'defective',
  r'wrongItem': r'wrongItem',
  r'damaged': r'damaged',
  r'changedMind': r'changedMind',
  r'other': r'other',
};
const _OrderreturnReasonValueEnumMap = {
  r'defective': ReturnReason.defective,
  r'wrongItem': ReturnReason.wrongItem,
  r'damaged': ReturnReason.damaged,
  r'changedMind': ReturnReason.changedMind,
  r'other': ReturnReason.other,
};
const _OrderreturnStatusEnumValueMap = {
  r'none': r'none',
  r'requested': r'requested',
  r'approved': r'approved',
  r'received': r'received',
  r'refunded': r'refunded',
  r'rejected': r'rejected',
};
const _OrderreturnStatusValueEnumMap = {
  r'none': ReturnStatus.none,
  r'requested': ReturnStatus.requested,
  r'approved': ReturnStatus.approved,
  r'received': ReturnStatus.received,
  r'refunded': ReturnStatus.refunded,
  r'rejected': ReturnStatus.rejected,
};

Id _orderGetId(Order object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _orderGetLinks(Order object) {
  return [];
}

void _orderAttach(IsarCollection<dynamic> col, Id id, Order object) {
  object.id = id;
}

extension OrderQueryWhereSort on QueryBuilder<Order, Order, QWhere> {
  QueryBuilder<Order, Order, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension OrderQueryWhere on QueryBuilder<Order, Order, QWhereClause> {
  QueryBuilder<Order, Order, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Order, Order, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Order, Order, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterWhereClause> idBetween(
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

extension OrderQueryFilter on QueryBuilder<Order, Order, QFilterCondition> {
  QueryBuilder<Order, Order, QAfterFilterCondition> actualDeliveryDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'actualDeliveryDate'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  actualDeliveryDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'actualDeliveryDate'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> actualDeliveryDateEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'actualDeliveryDate', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  actualDeliveryDateGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'actualDeliveryDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> actualDeliveryDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'actualDeliveryDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> actualDeliveryDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'actualDeliveryDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> amountPaidEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'amountPaid',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> amountPaidGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'amountPaid',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> amountPaidLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'amountPaid',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> amountPaidBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'amountPaid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> createdAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> createdAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
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

  QueryBuilder<Order, Order, QAfterFilterCondition> createdAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
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

  QueryBuilder<Order, Order, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Order, Order, QAfterFilterCondition> customerIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'customerId', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'customerId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'customerId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'customerId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'customerName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'customerName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'customerName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'customerName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'customerName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'customerName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'customerName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'customerName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'customerName', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'customerName', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'customerPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'customerPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'customerPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'customerPhone',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'customerPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'customerPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'customerPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'customerPhone',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'customerPhone', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> customerPhoneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'customerPhone', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deliveryAddress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'deliveryAddress',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryAddressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deliveryAddress', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  deliveryAddressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'deliveryAddress', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryFeeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'deliveryFee',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryFeeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deliveryFee',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryFeeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deliveryFee',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> deliveryFeeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deliveryFee',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> discountAmountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'discountAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> discountAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'discountAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> discountAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'discountAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> discountAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'discountAmount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  estimatedDeliveryDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'estimatedDeliveryDate'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  estimatedDeliveryDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'estimatedDeliveryDate'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  estimatedDeliveryDateEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'estimatedDeliveryDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  estimatedDeliveryDateGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'estimatedDeliveryDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  estimatedDeliveryDateLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'estimatedDeliveryDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  estimatedDeliveryDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'estimatedDeliveryDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Order, Order, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Order, Order, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Order, Order, QAfterFilterCondition> isRecurringEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isRecurring', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> isReturnEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isReturn', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> itemsLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', length, true, length, true);
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> itemsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, true, 0, true);
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> itemsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, false, 999999, true);
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> itemsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, true, length, include);
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> itemsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', length, include, 999999, true);
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> itemsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> nextRecurringDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'nextRecurringDate'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  nextRecurringDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'nextRecurringDate'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> nextRecurringDateEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nextRecurringDate', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  nextRecurringDateGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nextRecurringDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> nextRecurringDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nextRecurringDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> nextRecurringDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nextRecurringDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'notes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'notes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'orderNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'orderNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'orderNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'orderNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'orderNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'orderNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'orderNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'orderNumber',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'orderNumber', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'orderNumber', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusEqualTo(
    OrderStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'orderStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusGreaterThan(
    OrderStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'orderStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusLessThan(
    OrderStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'orderStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusBetween(
    OrderStatus lower,
    OrderStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'orderStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'orderStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'orderStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'orderStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'orderStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'orderStatus', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> orderStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'orderStatus', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> originalOrderIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'originalOrderId', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> originalOrderIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'originalOrderId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> originalOrderIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'originalOrderId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> originalOrderIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'originalOrderId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodEqualTo(
    PaymentMethod value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'paymentMethod',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodGreaterThan(
    PaymentMethod value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'paymentMethod',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodLessThan(
    PaymentMethod value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'paymentMethod',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodBetween(
    PaymentMethod lower,
    PaymentMethod upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'paymentMethod',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'paymentMethod',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'paymentMethod',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'paymentMethod',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'paymentMethod',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'paymentMethod', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentMethodIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'paymentMethod', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusEqualTo(
    PaymentStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'paymentStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusGreaterThan(
    PaymentStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'paymentStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusLessThan(
    PaymentStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'paymentStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusBetween(
    PaymentStatus lower,
    PaymentStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'paymentStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'paymentStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'paymentStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'paymentStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'paymentStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'paymentStatus', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> paymentStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'paymentStatus', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  recurringIntervalDaysEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recurringIntervalDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  recurringIntervalDaysGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recurringIntervalDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  recurringIntervalDaysLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recurringIntervalDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition>
  recurringIntervalDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recurringIntervalDays',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> refundAmountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'refundAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> refundAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'refundAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> refundAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'refundAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> refundAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'refundAmount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'returnNotes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'returnNotes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'returnNotes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'returnNotes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'returnNotes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'returnNotes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'returnNotes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'returnNotes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'returnNotes', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'returnNotes', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonEqualTo(
    ReturnReason value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'returnReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonGreaterThan(
    ReturnReason value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'returnReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonLessThan(
    ReturnReason value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'returnReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonBetween(
    ReturnReason lower,
    ReturnReason upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'returnReason',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'returnReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'returnReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'returnReason',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'returnReason',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'returnReason', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'returnReason', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusEqualTo(
    ReturnStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'returnStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusGreaterThan(
    ReturnStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'returnStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusLessThan(
    ReturnStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'returnStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusBetween(
    ReturnStatus lower,
    ReturnStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'returnStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'returnStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'returnStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'returnStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'returnStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'returnStatus', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> returnStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'returnStatus', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> subtotalEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'subtotal',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> subtotalGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'subtotal',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> subtotalLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'subtotal',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> subtotalBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'subtotal',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> taxAmountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'taxAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> taxAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'taxAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> taxAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'taxAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> taxAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'taxAmount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> totalAmountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> totalAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> totalAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> totalAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalAmount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'transactionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'transactionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'transactionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'transactionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'transactionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'transactionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'transactionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'transactionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'transactionId', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> transactionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'transactionId', value: ''),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> updatedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<Order, Order, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
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

  QueryBuilder<Order, Order, QAfterFilterCondition> updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
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

  QueryBuilder<Order, Order, QAfterFilterCondition> updatedAtBetween(
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
}

extension OrderQueryObject on QueryBuilder<Order, Order, QFilterCondition> {
  QueryBuilder<Order, Order, QAfterFilterCondition> itemsElement(
    FilterQuery<OrderItem> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'items');
    });
  }
}

extension OrderQueryLinks on QueryBuilder<Order, Order, QFilterCondition> {}

extension OrderQuerySortBy on QueryBuilder<Order, Order, QSortBy> {
  QueryBuilder<Order, Order, QAfterSortBy> sortByActualDeliveryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actualDeliveryDate', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByActualDeliveryDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actualDeliveryDate', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByAmountPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByAmountPaidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCustomerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCustomerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCustomerName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerName', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCustomerNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerName', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCustomerPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerPhone', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByCustomerPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerPhone', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByDeliveryAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByDeliveryAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByDeliveryFee() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryFee', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByDeliveryFeeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryFee', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByDiscountAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discountAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByDiscountAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discountAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByEstimatedDeliveryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedDeliveryDate', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByEstimatedDeliveryDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedDeliveryDate', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByIsRecurring() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurring', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByIsRecurringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurring', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByIsReturn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReturn', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByIsReturnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReturn', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByNextRecurringDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRecurringDate', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByNextRecurringDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRecurringDate', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByOrderNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderNumber', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByOrderNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderNumber', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByOrderStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderStatus', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByOrderStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderStatus', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByOriginalOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalOrderId', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByOriginalOrderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalOrderId', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByPaymentMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByPaymentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByPaymentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByRecurringIntervalDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recurringIntervalDays', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByRecurringIntervalDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recurringIntervalDays', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByRefundAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refundAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByRefundAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refundAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByReturnNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnNotes', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByReturnNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnNotes', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByReturnReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByReturnReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByReturnStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnStatus', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByReturnStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnStatus', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortBySubtotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtotal', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortBySubtotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtotal', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByTaxAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByTaxAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByTotalAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByTotalAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByTransactionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension OrderQuerySortThenBy on QueryBuilder<Order, Order, QSortThenBy> {
  QueryBuilder<Order, Order, QAfterSortBy> thenByActualDeliveryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actualDeliveryDate', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByActualDeliveryDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actualDeliveryDate', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByAmountPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByAmountPaidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCustomerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCustomerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCustomerName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerName', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCustomerNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerName', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCustomerPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerPhone', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByCustomerPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerPhone', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByDeliveryAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByDeliveryAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByDeliveryFee() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryFee', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByDeliveryFeeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryFee', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByDiscountAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discountAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByDiscountAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discountAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByEstimatedDeliveryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedDeliveryDate', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByEstimatedDeliveryDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedDeliveryDate', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByIsRecurring() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurring', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByIsRecurringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurring', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByIsReturn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReturn', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByIsReturnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReturn', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByNextRecurringDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRecurringDate', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByNextRecurringDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRecurringDate', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByOrderNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderNumber', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByOrderNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderNumber', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByOrderStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderStatus', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByOrderStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderStatus', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByOriginalOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalOrderId', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByOriginalOrderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalOrderId', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByPaymentMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByPaymentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByPaymentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByRecurringIntervalDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recurringIntervalDays', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByRecurringIntervalDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recurringIntervalDays', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByRefundAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refundAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByRefundAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refundAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByReturnNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnNotes', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByReturnNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnNotes', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByReturnReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByReturnReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByReturnStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnStatus', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByReturnStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnStatus', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenBySubtotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtotal', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenBySubtotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtotal', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByTaxAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByTaxAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByTotalAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmount', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByTotalAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmount', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByTransactionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.desc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Order, Order, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension OrderQueryWhereDistinct on QueryBuilder<Order, Order, QDistinct> {
  QueryBuilder<Order, Order, QDistinct> distinctByActualDeliveryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actualDeliveryDate');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByAmountPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountPaid');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByCustomerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customerId');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByCustomerName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customerName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByCustomerPhone({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'customerPhone',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByDeliveryAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'deliveryAddress',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByDeliveryFee() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deliveryFee');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByDiscountAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'discountAmount');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByEstimatedDeliveryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'estimatedDeliveryDate');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByIsRecurring() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRecurring');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByIsReturn() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isReturn');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByNextRecurringDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextRecurringDate');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByNotes({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByOrderNumber({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'orderNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByOrderStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'orderStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByOriginalOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalOrderId');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByPaymentMethod({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'paymentMethod',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByPaymentStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'paymentStatus',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByRecurringIntervalDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recurringIntervalDays');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByRefundAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'refundAmount');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByReturnNotes({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnNotes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByReturnReason({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByReturnStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctBySubtotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subtotal');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByTaxAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taxAmount');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByTotalAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalAmount');
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByTransactionId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'transactionId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Order, Order, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension OrderQueryProperty on QueryBuilder<Order, Order, QQueryProperty> {
  QueryBuilder<Order, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Order, DateTime?, QQueryOperations>
  actualDeliveryDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actualDeliveryDate');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> amountPaidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountPaid');
    });
  }

  QueryBuilder<Order, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Order, int, QQueryOperations> customerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customerId');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> customerNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customerName');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> customerPhoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customerPhone');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> deliveryAddressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryAddress');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> deliveryFeeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryFee');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> discountAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'discountAmount');
    });
  }

  QueryBuilder<Order, DateTime?, QQueryOperations>
  estimatedDeliveryDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'estimatedDeliveryDate');
    });
  }

  QueryBuilder<Order, bool, QQueryOperations> isRecurringProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRecurring');
    });
  }

  QueryBuilder<Order, bool, QQueryOperations> isReturnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isReturn');
    });
  }

  QueryBuilder<Order, List<OrderItem>, QQueryOperations> itemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'items');
    });
  }

  QueryBuilder<Order, DateTime?, QQueryOperations> nextRecurringDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextRecurringDate');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> orderNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'orderNumber');
    });
  }

  QueryBuilder<Order, OrderStatus, QQueryOperations> orderStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'orderStatus');
    });
  }

  QueryBuilder<Order, int, QQueryOperations> originalOrderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalOrderId');
    });
  }

  QueryBuilder<Order, PaymentMethod, QQueryOperations> paymentMethodProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentMethod');
    });
  }

  QueryBuilder<Order, PaymentStatus, QQueryOperations> paymentStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentStatus');
    });
  }

  QueryBuilder<Order, int, QQueryOperations> recurringIntervalDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recurringIntervalDays');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> refundAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'refundAmount');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> returnNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnNotes');
    });
  }

  QueryBuilder<Order, ReturnReason, QQueryOperations> returnReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnReason');
    });
  }

  QueryBuilder<Order, ReturnStatus, QQueryOperations> returnStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnStatus');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> subtotalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subtotal');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> taxAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taxAmount');
    });
  }

  QueryBuilder<Order, double, QQueryOperations> totalAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalAmount');
    });
  }

  QueryBuilder<Order, String, QQueryOperations> transactionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transactionId');
    });
  }

  QueryBuilder<Order, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
  orderNumber: json['orderNumber'] as String? ?? '',
  customerId: (json['customerId'] as num?)?.toInt() ?? 0,
  customerName: json['customerName'] as String? ?? '',
  customerPhone: json['customerPhone'] as String? ?? '',
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
  discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
  deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
  taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
  totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
  amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
  paymentStatus:
      $enumDecodeNullable(_$PaymentStatusEnumMap, json['paymentStatus']) ??
      PaymentStatus.unpaid,
  paymentMethod:
      $enumDecodeNullable(_$PaymentMethodEnumMap, json['paymentMethod']) ??
      PaymentMethod.cash,
  transactionId: json['transactionId'] as String? ?? '',
  orderStatus:
      $enumDecodeNullable(_$OrderStatusEnumMap, json['orderStatus']) ??
      OrderStatus.pending,
  notes: json['notes'] as String? ?? '',
  deliveryAddress: json['deliveryAddress'] as String? ?? '',
  estimatedDeliveryDate: json['estimatedDeliveryDate'] == null
      ? null
      : DateTime.parse(json['estimatedDeliveryDate'] as String),
  actualDeliveryDate: json['actualDeliveryDate'] == null
      ? null
      : DateTime.parse(json['actualDeliveryDate'] as String),
  isReturn: json['isReturn'] as bool? ?? false,
  originalOrderId: (json['originalOrderId'] as num?)?.toInt() ?? 0,
  returnStatus:
      $enumDecodeNullable(_$ReturnStatusEnumMap, json['returnStatus']) ??
      ReturnStatus.none,
  returnReason:
      $enumDecodeNullable(_$ReturnReasonEnumMap, json['returnReason']) ??
      ReturnReason.other,
  returnNotes: json['returnNotes'] as String? ?? '',
  refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0.0,
  isRecurring: json['isRecurring'] as bool? ?? false,
  recurringIntervalDays: (json['recurringIntervalDays'] as num?)?.toInt() ?? 0,
  nextRecurringDate: json['nextRecurringDate'] == null
      ? null
      : DateTime.parse(json['nextRecurringDate'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'orderNumber': instance.orderNumber,
  'customerId': instance.customerId,
  'customerName': instance.customerName,
  'customerPhone': instance.customerPhone,
  'items': instance.items,
  'subtotal': instance.subtotal,
  'discountAmount': instance.discountAmount,
  'deliveryFee': instance.deliveryFee,
  'taxAmount': instance.taxAmount,
  'totalAmount': instance.totalAmount,
  'amountPaid': instance.amountPaid,
  'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
  'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod]!,
  'transactionId': instance.transactionId,
  'orderStatus': _$OrderStatusEnumMap[instance.orderStatus]!,
  'notes': instance.notes,
  'deliveryAddress': instance.deliveryAddress,
  'estimatedDeliveryDate': instance.estimatedDeliveryDate?.toIso8601String(),
  'actualDeliveryDate': instance.actualDeliveryDate?.toIso8601String(),
  'isReturn': instance.isReturn,
  'originalOrderId': instance.originalOrderId,
  'returnStatus': _$ReturnStatusEnumMap[instance.returnStatus]!,
  'returnReason': _$ReturnReasonEnumMap[instance.returnReason]!,
  'returnNotes': instance.returnNotes,
  'refundAmount': instance.refundAmount,
  'isRecurring': instance.isRecurring,
  'recurringIntervalDays': instance.recurringIntervalDays,
  'nextRecurringDate': instance.nextRecurringDate?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.unpaid: 'unpaid',
  PaymentStatus.partial: 'partial',
  PaymentStatus.paid: 'paid',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.card: 'card',
  PaymentMethod.mfs: 'mfs',
  PaymentMethod.bank: 'bank',
  PaymentMethod.other: 'other',
};

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'pending',
  OrderStatus.confirmed: 'confirmed',
  OrderStatus.shipped: 'shipped',
  OrderStatus.completed: 'completed',
  OrderStatus.cancelled: 'cancelled',
};

const _$ReturnStatusEnumMap = {
  ReturnStatus.none: 'none',
  ReturnStatus.requested: 'requested',
  ReturnStatus.approved: 'approved',
  ReturnStatus.received: 'received',
  ReturnStatus.refunded: 'refunded',
  ReturnStatus.rejected: 'rejected',
};

const _$ReturnReasonEnumMap = {
  ReturnReason.defective: 'defective',
  ReturnReason.wrongItem: 'wrongItem',
  ReturnReason.damaged: 'damaged',
  ReturnReason.changedMind: 'changedMind',
  ReturnReason.other: 'other',
};
