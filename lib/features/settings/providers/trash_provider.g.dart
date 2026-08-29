// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trashService)
final trashServiceProvider = TrashServiceProvider._();

final class TrashServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrashService>,
          TrashService,
          FutureOr<TrashService>
        >
    with $FutureModifier<TrashService>, $FutureProvider<TrashService> {
  TrashServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashServiceHash();

  @$internal
  @override
  $FutureProviderElement<TrashService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrashService> create(Ref ref) {
    return trashService(ref);
  }
}

String _$trashServiceHash() => r'f48078e68feed4bcfda122a2f5d5a14f4c2ce8b9';

/// Live contents of the recycle bin, newest first.

@ProviderFor(trashEntries)
final trashEntriesProvider = TrashEntriesProvider._();

/// Live contents of the recycle bin, newest first.

final class TrashEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrashEntry>>,
          List<TrashEntry>,
          Stream<List<TrashEntry>>
        >
    with $FutureModifier<List<TrashEntry>>, $StreamProvider<List<TrashEntry>> {
  /// Live contents of the recycle bin, newest first.
  TrashEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<TrashEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TrashEntry>> create(Ref ref) {
    return trashEntries(ref);
  }
}

String _$trashEntriesHash() => r'891abc705f10ec8d9054ab6c7994e1c1c04461cb';

/// keepAlive per the project rule: a `ref.read(...).restore()` from a screen
/// would otherwise dispose this provider mid-await and the post-await
/// `state = ...` would throw UnmountedRefException.

@ProviderFor(TrashNotifier)
final trashProvider = TrashNotifierProvider._();

/// keepAlive per the project rule: a `ref.read(...).restore()` from a screen
/// would otherwise dispose this provider mid-await and the post-await
/// `state = ...` would throw UnmountedRefException.
final class TrashNotifierProvider
    extends $AsyncNotifierProvider<TrashNotifier, void> {
  /// keepAlive per the project rule: a `ref.read(...).restore()` from a screen
  /// would otherwise dispose this provider mid-await and the post-await
  /// `state = ...` would throw UnmountedRefException.
  TrashNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashNotifierHash();

  @$internal
  @override
  TrashNotifier create() => TrashNotifier();
}

String _$trashNotifierHash() => r'e0c78e056cfd4f22c7b0fa1b6c030a87dc39f833';

/// keepAlive per the project rule: a `ref.read(...).restore()` from a screen
/// would otherwise dispose this provider mid-await and the post-await
/// `state = ...` would throw UnmountedRefException.

abstract class _$TrashNotifier extends $AsyncNotifier<void> {
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
