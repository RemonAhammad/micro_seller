// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_scale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings → Display size / Text size, applied by `AppZoom` around the
/// router (app_frame.dart).
///
/// Per-device on purpose, so it lives outside `Settings` and its
/// `exportSettings()`: the right size depends on this screen and on the
/// phone's own font setting, and a phone backup restored on a tablet must
/// not resize it. Same precedent as ReviewService's per-device prompt state.
///
/// [DisplayScale.primeFrom] runs in main() before runApp, so the first frame
/// is already at the saved size.

@ProviderFor(DisplayScale)
final displayScaleProvider = DisplayScaleProvider._();

/// Settings → Display size / Text size, applied by `AppZoom` around the
/// router (app_frame.dart).
///
/// Per-device on purpose, so it lives outside `Settings` and its
/// `exportSettings()`: the right size depends on this screen and on the
/// phone's own font setting, and a phone backup restored on a tablet must
/// not resize it. Same precedent as ReviewService's per-device prompt state.
///
/// [DisplayScale.primeFrom] runs in main() before runApp, so the first frame
/// is already at the saved size.
final class DisplayScaleProvider
    extends $NotifierProvider<DisplayScale, DisplayScaleState> {
  /// Settings → Display size / Text size, applied by `AppZoom` around the
  /// router (app_frame.dart).
  ///
  /// Per-device on purpose, so it lives outside `Settings` and its
  /// `exportSettings()`: the right size depends on this screen and on the
  /// phone's own font setting, and a phone backup restored on a tablet must
  /// not resize it. Same precedent as ReviewService's per-device prompt state.
  ///
  /// [DisplayScale.primeFrom] runs in main() before runApp, so the first frame
  /// is already at the saved size.
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

/// Settings → Display size / Text size, applied by `AppZoom` around the
/// router (app_frame.dart).
///
/// Per-device on purpose, so it lives outside `Settings` and its
/// `exportSettings()`: the right size depends on this screen and on the
/// phone's own font setting, and a phone backup restored on a tablet must
/// not resize it. Same precedent as ReviewService's per-device prompt state.
///
/// [DisplayScale.primeFrom] runs in main() before runApp, so the first frame
/// is already at the saved size.

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
