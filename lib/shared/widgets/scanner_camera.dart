import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/device_channel.dart';
import 'app_button.dart';

class CameraSession with WidgetsBindingObserver {
  CameraSession(this.controller, this.device) {
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_followCamera);
  }

  final MobileScannerController controller;
  final DeviceChannel device;

  final access = ValueNotifier<CameraAccess?>(null);

  final error = ValueNotifier<MobileScannerException?>(null);

  void _followCamera() {
    final camera = controller.value;
    if (camera.isRunning) {
      error.value = null;
    } else if (camera.error case final failed?) {
      error.value = failed;
    }
  }

  bool _visible = false;
  bool _resumed = switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed => true,
    _ => false,
  };

  bool _refused = false;
  bool _disposed = false;
  Future<void> _op = Future.value();

  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    _sync(askAgain: visible);
  }

  void retry() => _sync(askAgain: true);

  Future<bool> openSettings() => device.openAppSettings();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    _resumed = resumed;
    _sync();
  }

  void _sync({bool askAgain = false}) {

    _op = _op.then((_) => _apply(askAgain)).catchError((Object _) {});
  }

  Future<void> _apply(bool askAgain) async {
    if (_disposed) return;
    if (!_visible || !_resumed) {
      await controller.stop();
      return;
    }
    if (_refused) {
      final now = await device.cameraAccess();
      if (_disposed) return;
      if (now != CameraAccess.granted) {
        access.value = now;

        if (!askAgain ||
            now == CameraAccess.permanentlyDenied ||
            now == CameraAccess.restricted) {
          return;
        }
      }
    }
    try {
      await controller.start();
    } catch (_) {

    }
    if (_disposed) return;
    _refused = controller.value.error?.errorCode ==
        MobileScannerErrorCode.permissionDenied;
    final refusedAs = _refused ? await device.cameraAccess() : null;
    if (_disposed) return;
    access.value = refusedAs;
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_followCamera);
    access.dispose();
    error.dispose();
  }
}

class ScannerPreview extends StatelessWidget {
  const ScannerPreview({
    super.key,
    required this.session,
    required this.onDetect,
    required this.overlay,
  });

  final CameraSession session;
  final void Function(BarcodeCapture capture) onDetect;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(

      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: session.controller,
          onDetect: onDetect,

          errorBuilder: (_, _) => const ColoredBox(color: Colors.black),
        ),
        ValueListenableBuilder<MobileScannerException?>(
          valueListenable: session.error,
          builder: (context, error, overlay) => error == null
              ? overlay!
              : ScannerErrorView(error: error, session: session),
          child: overlay,
        ),
      ],
    );
  }
}

enum _Blocked {

  askable,

  inSettings,

  restricted,

  checking,

  noCamera,

  failed,
}

_Blocked _blockedBy(MobileScannerErrorCode code, CameraAccess? access) =>
    switch (code) {
      MobileScannerErrorCode.permissionDenied => switch (access) {
        null => _Blocked.checking,
        CameraAccess.denied || CameraAccess.notDetermined => _Blocked.askable,
        CameraAccess.permanentlyDenied ||
        CameraAccess.unknown => _Blocked.inSettings,
        CameraAccess.restricted => _Blocked.restricted,

        CameraAccess.granted => _Blocked.failed,
      },
      MobileScannerErrorCode.unsupported => _Blocked.noCamera,
      _ => _Blocked.failed,
    };

class ScannerErrorView extends StatelessWidget {
  const ScannerErrorView({
    super.key,
    required this.error,
    required this.session,
  });

  final MobileScannerException error;
  final CameraSession session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraAccess?>(
      valueListenable: session.access,
      builder: (context, access, _) {
        final s = AppStrings.of(context);
        final theme = Theme.of(context);
        final blocked = _blockedBy(error.errorCode, access);
        final message = switch (blocked) {
          _Blocked.askable => s.cameraAllowPrompt,
          _Blocked.inSettings => s.cameraAllowInSettings,
          _Blocked.restricted => s.cameraRestricted,
          _Blocked.checking => null,
          _Blocked.noCamera => s.noCameraAvailable,
          _Blocked.failed => s.cameraStartFailed,
        };

        final refused = switch (blocked) {
          _Blocked.noCamera || _Blocked.failed => false,
          _ => true,
        };
        final headline = refused ? s.cameraAccessOff : message!;
        final body = refused ? message : null;

        Widget label(String text) => Text(text, textAlign: TextAlign.center);
        final buttons = switch (blocked) {
          _Blocked.askable => [
            FilledButton(
              onPressed: session.retry,
              child: label(s.allowCamera),
            ),
            OutlinedButton(
              onPressed: session.openSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              child: label(s.openSettings),
            ),
          ],
          _Blocked.inSettings => [
            FilledButton(
              onPressed: session.openSettings,
              child: label(s.openSettings),
            ),
          ],
          _Blocked.failed => [
            FilledButton(onPressed: session.retry, child: label(s.tryAgain)),
          ],
          _Blocked.restricted || _Blocked.checking || _Blocked.noCamera =>
            const <Widget>[],
        };

        return ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ThinIcon(
                        tabler.CameraOff.new,
                        size: 48,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (body != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      for (var i = 0; i < buttons.length; i++) ...[
                        SizedBox(height: i == 0 ? 24 : 12),
                        buttons[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TorchButton extends StatelessWidget {
  const TorchButton({super.key, required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (!state.isRunning || state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final s = AppStrings.of(context);
        final on = state.torchState == TorchState.on;
        return IconButton(
          tooltip: on ? s.torchOff : s.torchOn,
          icon: ThinIcon(
            on ? tabler.Bolt.new : tabler.BoltOff.new,
            color: on ? Colors.yellow : Colors.white,
          ),
          onPressed: () async {
            try {
              await controller.toggleTorch();
            } on Exception {

            }
          },
        );
      },
    );
  }
}

Future<void> showCameraBlockedDialog(
  BuildContext context,
  CameraAccess access,
  DeviceChannel device,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CameraBlockedDialog(access: access, device: device),
  );
}

class _CameraBlockedDialog extends StatelessWidget {
  const _CameraBlockedDialog({required this.access, required this.device});

  final CameraAccess access;
  final DeviceChannel device;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final restricted = access == CameraAccess.restricted;
    final message = switch (access) {
      CameraAccess.denied || CameraAccess.notDetermined => s.cameraAllowPrompt,
      CameraAccess.restricted => s.cameraRestricted,
      _ => s.cameraAllowInSettings,
    };
    return AlertDialog(

      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      icon: ThinIcon(
        tabler.CameraOff.new,
        size: 40,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        s.cameraAccessOff,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        if (restricted)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.close),
            ),
          )
        else

          ButtonPair(
            first: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.cancel),
            ),
            second: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(device.openAppSettings());
              },
              child: Text(s.openSettings),
            ),
          ),
      ],
    );
  }
}
