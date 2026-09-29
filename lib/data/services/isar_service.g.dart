// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(isar)
final isarProvider = IsarProvider._();

final class IsarProvider
    extends $FunctionalProvider<AsyncValue<Isar>, Isar, FutureOr<Isar>>
    with $FutureModifier<Isar>, $FutureProvider<Isar> {
  IsarProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isarProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isarHash();

  @$internal
  @override
  $FutureProviderElement<Isar> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Isar> create(Ref ref) {
    return isar(ref);
  }
}

String _$isarHash() => r'8be0c874894f98a1e95e6d21b908e6740649e011';
