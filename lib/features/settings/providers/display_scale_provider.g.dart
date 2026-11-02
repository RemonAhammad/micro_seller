// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_scale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DisplayScale)
final displayScaleProvider = DisplayScaleProvider._();

final class DisplayScaleProvider
    extends $NotifierProvider<DisplayScale, DisplayScaleState> {
  DisplayScaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayScaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayScaleHash();

  @$internal
  @override
  DisplayScale create() => DisplayScale();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayScaleState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayScaleState>(value),
    );
  }
}

String _$displayScaleHash() => r'9c518418735d54a5eee1db30177d32b80aad1715';

abstract class _$DisplayScale extends $Notifier<DisplayScaleState> {
  DisplayScaleState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DisplayScaleState, DisplayScaleState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DisplayScaleState, DisplayScaleState>,
              DisplayScaleState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
