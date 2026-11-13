// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_notice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateChannel)
final updateChannelProvider = UpdateChannelProvider._();

final class UpdateChannelProvider
    extends
        $FunctionalProvider<
          AsyncValue<UpdateChannel>,
          UpdateChannel,
          FutureOr<UpdateChannel>
        >
    with $FutureModifier<UpdateChannel>, $FutureProvider<UpdateChannel> {
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

@ProviderFor(releaseUpdateService)
final releaseUpdateServiceProvider = ReleaseUpdateServiceProvider._();

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

@ProviderFor(UpdateNotice)
final updateNoticeProvider = UpdateNoticeProvider._();

final class UpdateNoticeProvider
    extends $AsyncNotifierProvider<UpdateNotice, AvailableUpdate?> {
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

abstract class _$UpdateNotice extends $AsyncNotifier<AvailableUpdate?> {
  FutureOr<AvailableUpdate?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
  }
}
