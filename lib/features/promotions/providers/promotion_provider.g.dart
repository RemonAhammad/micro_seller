// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promotion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PromotionNotifier)
final promotionProvider = PromotionNotifierProvider._();

final class PromotionNotifierProvider
    extends $AsyncNotifierProvider<PromotionNotifier, List<Promotion>> {
  PromotionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promotionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promotionNotifierHash();

  @$internal
  @override
  PromotionNotifier create() => PromotionNotifier();
}

String _$promotionNotifierHash() => r'09350d6c1c5a46ed8f095a951fb5a0960474565d';

abstract class _$PromotionNotifier extends $AsyncNotifier<List<Promotion>> {
  FutureOr<List<Promotion>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Promotion>>, List<Promotion>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Promotion>>, List<Promotion>>,
              AsyncValue<List<Promotion>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
