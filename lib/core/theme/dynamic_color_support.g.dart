// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dynamic_color_support.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether Phone colors can be offered: Android 12+, where the system hands
/// out its color palette.

@ProviderFor(dynamicColorAvailable)
final dynamicColorAvailableProvider = DynamicColorAvailableProvider._();

/// Whether Phone colors can be offered: Android 12+, where the system hands
/// out its color palette.

final class DynamicColorAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether Phone colors can be offered: Android 12+, where the system hands
  /// out its color palette.
  DynamicColorAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dynamicColorAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dynamicColorAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return dynamicColorAvailable(ref);
  }
}

String _$dynamicColorAvailableHash() =>
    r'4742f16131b6916f098ce747d6ff319b7da2c95d';
