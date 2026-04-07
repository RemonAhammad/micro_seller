// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_register_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cashRegistersHash() => r'73e2c5336385fdaa660777cd0143e90f0697c92b';

/// See also [cashRegisters].
@ProviderFor(cashRegisters)
final cashRegistersProvider =
    AutoDisposeStreamProvider<List<CashRegister>>.internal(
  cashRegisters,
  name: r'cashRegistersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cashRegistersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CashRegistersRef = AutoDisposeStreamProviderRef<List<CashRegister>>;
String _$openRegisterHash() => r'e8cec326723bf674034077a2a77fedddea736827';

/// Returns the currently open register (if any)
///
/// Copied from [openRegister].
@ProviderFor(openRegister)
final openRegisterProvider = AutoDisposeFutureProvider<CashRegister?>.internal(
  openRegister,
  name: r'openRegisterProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$openRegisterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OpenRegisterRef = AutoDisposeFutureProviderRef<CashRegister?>;
String _$cashRegisterNotifierHash() =>
    r'aa72aa2e8118b5216f8757596b4707c8d9f7b47d';

/// See also [CashRegisterNotifier].
@ProviderFor(CashRegisterNotifier)
final cashRegisterNotifierProvider =
    AutoDisposeAsyncNotifierProvider<CashRegisterNotifier, void>.internal(
  CashRegisterNotifier.new,
  name: r'cashRegisterNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cashRegisterNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CashRegisterNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
