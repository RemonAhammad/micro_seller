// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_channel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceChannel)
final deviceChannelProvider = DeviceChannelProvider._();

final class DeviceChannelProvider
    extends $FunctionalProvider<DeviceChannel, DeviceChannel, DeviceChannel>
    with $Provider<DeviceChannel> {
  DeviceChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceChannelHash();

  @$internal
  @override
  $ProviderElement<DeviceChannel> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceChannel create(Ref ref) {
    return deviceChannel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceChannel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceChannel>(value),
    );
  }
}

String _$deviceChannelHash() => r'fa2527c706fca0847c5f46f26059c12ccde719b2';

@ProviderFor(imagePicker)
final imagePickerProvider = ImagePickerProvider._();

final class ImagePickerProvider
    extends $FunctionalProvider<ImagePicker, ImagePicker, ImagePicker>
    with $Provider<ImagePicker> {
  ImagePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imagePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imagePickerHash();

  @$internal
  @override
  $ProviderElement<ImagePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImagePicker create(Ref ref) {
    return imagePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImagePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImagePicker>(value),
    );
  }
}

String _$imagePickerHash() => r'be60667b04027cd2a7d2e1b728a5c03b1bda8dc1';
