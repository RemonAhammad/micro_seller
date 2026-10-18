import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/product.dart';
import 'isar_service.dart';

part 'isar_revisions.g.dart';

// Change counters for providers that recompute from their own queries
// (dashboard stats, reports). Watching one of these instead of a list
// provider means nothing deserializes a whole collection just to notice a
// write. keepAlive and never paused, so writes made while the Dashboard or
// Reports is offstage collapse into a single recompute when it is shown.

void _bump(
    Ref ref, Stream<void> Function(Isar) changes, void Function() bump) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) return;
  final sub = changes(isar).listen((_) => bump());
  ref.onDispose(sub.cancel);
}

@Riverpod(keepAlive: true)
class OrdersRevision extends _$OrdersRevision {
  @override
  int build() {
    _bump(ref, (isar) => isar.orders.watchLazy(), () => state++);
    return 0;
  }
}

@Riverpod(keepAlive: true)
class CustomersRevision extends _$CustomersRevision {
  @override
  int build() {
    _bump(ref, (isar) => isar.customers.watchLazy(), () => state++);
    return 0;
  }
}

@Riverpod(keepAlive: true)
class ProductsRevision extends _$ProductsRevision {
  @override
  int build() {
    _bump(ref, (isar) => isar.products.watchLazy(), () => state++);
    return 0;
  }
}

@Riverpod(keepAlive: true)
class ExpensesRevision extends _$ExpensesRevision {
  @override
  int build() {
    _bump(ref, (isar) => isar.expenses.watchLazy(), () => state++);
    return 0;
  }
}

@Riverpod(keepAlive: true)
class PaymentsRevision extends _$PaymentsRevision {
  @override
  int build() {
    _bump(ref, (isar) => isar.payments.watchLazy(), () => state++);
    return 0;
  }
}
