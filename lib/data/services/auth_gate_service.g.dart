// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_gate_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The security gate's service, overridden with a fake in tests.

@ProviderFor(authGateService)
final authGateServiceProvider = AuthGateServiceProvider._();

/// The security gate's service, overridden with a fake in tests.

final class AuthGateServiceProvider
    extends
        $FunctionalProvider<AuthGateService, AuthGateService, AuthGateService>
    with $Provider<AuthGateService> {
  /// The security gate's service, overridden with a fake in tests.
  AuthGateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authGateServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authGateServiceHash();

  @$internal
  @override
  $ProviderElement<AuthGateService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthGateService create(Ref ref) {
    return authGateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthGateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthGateService>(value),
    );
  }
}

String _$authGateServiceHash() => r'0c33b41eaae0daa5f4cb76088452b995fb204201';
