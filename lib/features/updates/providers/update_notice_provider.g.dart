// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_notice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How this install gets its updates: Play's in-app update, the GitHub
/// notice, or none. Tests override it (`UpdateChannel.none`), so they never
/// ask GitHub.

@ProviderFor(updateChannel)
final updateChannelProvider = UpdateChannelProvider._();

/// How this install gets its updates: Play's in-app update, the GitHub
/// notice, or none. Tests override it (`UpdateChannel.none`), so they never
/// ask GitHub.

final class UpdateChannelProvider
    extends
        $FunctionalProvider<
          AsyncValue<UpdateChannel>,
          UpdateChannel,
          FutureOr<UpdateChannel>
        >
    with $FutureModifier<UpdateChannel>, $FutureProvider<UpdateChannel> {
  /// How this install gets its updates: Play's in-app update, the GitHub
  /// notice, or none. Tests override it (`UpdateChannel.none`), so they never
  /// ask GitHub.
  UpdateChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateChannelHash();

  @$internal
  @override
  $FutureProviderElement<UpdateChannel> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UpdateChannel> create(Ref ref) {
    return updateChannel(ref);
  }
}

String _$updateChannelHash() => r'dbf64a62f7285d2e2a5812b69ede96aefed31648';

/// The GitHub release check, on the github channel only; null elsewhere, or
/// when it couldn't be set up.

@ProviderFor(releaseUpdateService)
final releaseUpdateServiceProvider = ReleaseUpdateServiceProvider._();

/// The GitHub release check, on the github channel only; null elsewhere, or
/// when it couldn't be set up.

final class ReleaseUpdateServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReleaseUpdateService?>,
          ReleaseUpdateService?,
          FutureOr<ReleaseUpdateService?>
        >
    with
        $FutureModifier<ReleaseUpdateService?>,
        $FutureProvider<ReleaseUpdateService?> {
  /// The GitHub release check, on the github channel only; null elsewhere, or
  /// when it couldn't be set up.
  ReleaseUpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'releaseUpdateServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$releaseUpdateServiceHash();

  @$internal
  @override
  $FutureProviderElement<ReleaseUpdateService?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReleaseUpdateService?> create(Ref ref) {
    return releaseUpdateService(ref);
  }
}

String _$releaseUpdateServiceHash() =>
    r'72cb8d50d55184d49a851e134c6c9d292bfc0112';

/// The newer release the Dashboard's notice offers, or null. Asks GitHub at
/// most once a day (`ReleaseUpdateService.check`). Never an error.

@ProviderFor(UpdateNotice)
final updateNoticeProvider = UpdateNoticeProvider._();

/// The newer release the Dashboard's notice offers, or null. Asks GitHub at
/// most once a day (`ReleaseUpdateService.check`). Never an error.
final class UpdateNoticeProvider
    extends $AsyncNotifierProvider<UpdateNotice, AvailableUpdate?> {
  /// The newer release the Dashboard's notice offers, or null. Asks GitHub at
  /// most once a day (`ReleaseUpdateService.check`). Never an error.
  UpdateNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNoticeHash();

  @$internal
  @override
  UpdateNotice create() => UpdateNotice();
}

String _$updateNoticeHash() => r'8f4ff5fd99eaa22936061e84a4162b4e101f6b0c';

/// The newer release the Dashboard's notice offers, or null. Asks GitHub at
/// most once a day (`ReleaseUpdateService.check`). Never an error.

abstract class _$UpdateNotice extends $AsyncNotifier<AvailableUpdate?> {
  FutureOr<AvailableUpdate?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AvailableUpdate?>, AvailableUpdate?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AvailableUpdate?>, AvailableUpdate?>,
              AsyncValue<AvailableUpdate?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
