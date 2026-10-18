import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/cash_register.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'cash_register_provider.g.dart';

@riverpod
Stream<List<CashRegister>> cashRegisters(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  final query = isar.cashRegisters.where().sortByOpenedAtDesc();
  yield* reloadOn(isar.cashRegisters.watchLazy(), query.findAll);
}

/// Returns the currently open register (if any)
@riverpod
Future<CashRegister?> openRegister(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return isar.cashRegisters
      .filter()
      .isClosedEqualTo(false)
      .sortByOpenedAtDesc()
      .findFirst();
}

@Riverpod(keepAlive: true)
class CashRegisterNotifier extends _$CashRegisterNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> openRegister(double openingAmount, {String notes = ''}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        // Close any existing open register first
        final existing = await isar.cashRegisters
            .filter()
            .isClosedEqualTo(false)
            .findFirst();
        if (existing != null) {
          await isar.cashRegisters.put(existing.copyWith(
            isClosed: true,
            closingAmount: existing.expectedClosing,
            closedAt: DateTime.now(),
          ));
        }

        await isar.cashRegisters.put(CashRegister(
          openingAmount: openingAmount,
          notes: notes,
          openedAt: DateTime.now(),
        ));
      });
    });
  }

  Future<void> closeRegister(int id, double closingAmount, {String notes = ''}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final register = await isar.cashRegisters.get(id);
        if (register == null || register.isClosed) return;
        await isar.cashRegisters.put(register.copyWith(
          closingAmount: closingAmount,
          isClosed: true,
          closedAt: DateTime.now(),
          notes: notes.isNotEmpty ? notes : register.notes,
        ));
      });
    });
  }

  Future<void> addCashIn(int id, double amount) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final register = await isar.cashRegisters.get(id);
        if (register == null || register.isClosed) return;
        await isar.cashRegisters.put(register.copyWith(
          totalCashIn: register.totalCashIn + amount,
        ));
      });
    });
  }

  Future<void> addCashOut(int id, double amount) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final register = await isar.cashRegisters.get(id);
        if (register == null || register.isClosed) return;
        await isar.cashRegisters.put(register.copyWith(
          totalCashOut: register.totalCashOut + amount,
        ));
      });
    });
  }

  Future<void> updateSalesAndExpenses(int id, double sales, double expenses) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final register = await isar.cashRegisters.get(id);
        if (register == null || register.isClosed) return;
        await isar.cashRegisters.put(register.copyWith(
          totalSales: sales,
          totalExpenses: expenses,
        ));
      });
    });
  }
}
