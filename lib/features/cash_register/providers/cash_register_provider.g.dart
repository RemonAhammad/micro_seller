// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_register_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cashRegisters)
final cashRegistersProvider = CashRegistersProvider._();

final class CashRegistersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CashRegister>>,
          List<CashRegister>,
          Stream<List<CashRegister>>
        >
    with
        $FutureModifier<List<CashRegister>>,
        $StreamProvider<List<CashRegister>> {
  CashRegistersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cashRegistersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cashRegistersHash();

  @$internal
  @override
  $StreamProviderElement<List<CashRegister>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CashRegister>> create(Ref ref) {
    return cashRegisters(ref);
  }
}

String _$cashRegistersHash() => r'f18d99dab64c7fd0af81c737c386e9af0f9544d4';

/// Returns the currently open register (if any)

@ProviderFor(openRegister)
final openRegisterProvider = OpenRegisterProvider._();

/// Returns the currently open register (if any)

final class OpenRegisterProvider
    extends
        $FunctionalProvider<
          AsyncValue<CashRegister?>,
          CashRegister?,
          FutureOr<CashRegister?>
        >
    with $FutureModifier<CashRegister?>, $FutureProvider<CashRegister?> {
  /// Returns the currently open register (if any)
  OpenRegisterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openRegisterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openRegisterHash();

  @$internal
  @override
  $FutureProviderElement<CashRegister?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CashRegister?> create(Ref ref) {
    return openRegister(ref);
  }
}

String _$openRegisterHash() => r'5162a3f8176a50079b4aed5096448802d41b3f39';

@ProviderFor(CashRegisterNotifier)
final cashRegisterProvider = CashRegisterNotifierProvider._();

final class CashRegisterNotifierProvider
    extends $AsyncNotifierProvider<CashRegisterNotifier, void> {
  CashRegisterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cashRegisterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cashRegisterNotifierHash();

  @$internal
  @override
  CashRegisterNotifier create() => CashRegisterNotifier();
}

String _$cashRegisterNotifierHash() =>
    r'fe8aa4913315a74fe5eac94b362722c876902d14';

abstract class _$CashRegisterNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
