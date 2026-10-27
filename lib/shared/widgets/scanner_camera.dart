import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/device_channel.dart';
import 'app_button.dart';

// The camera of the two scanners (the Scanner tab and the product form's QR
// scanner): when it runs, what the seller sees when it can't, and the
// flashlight. Also the dialog for a product photo taken with a refused
// camera.

/// Runs a scanner's camera while its screen is shown ([setVisible]) and the
/// app is in the foreground, and stops it otherwise: a branch stays mounted
/// offstage after a visit. One start or stop at a time (the controller's
/// start() throws while a start is in flight), each applying the latest
/// wanted state.
///
/// A refused camera is asked for again only when the screen opens and when
/// the seller taps Allow camera ([retry]). Android shows its permission
/// prompt on every ask, and the prompt pauses and resumes the app: asking
/// on resume would loop. Back from the system's Settings with the camera
/// allowed, the camera starts by itself.
///
/// The screen owns [controller] and disposes it after the session.
class CameraSession with WidgetsBindingObserver {
  CameraSession(this.controller, this.device) {
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_followCamera);
  }

  final MobileScannerController controller;
  final DeviceChannel device;

  /// Whether the app may use the camera, while the camera is refused: null
  /// when it isn't, and until the check after a refusal answers.
  final access = ValueNotifier<CameraAccess?>(null);

  /// Why the camera won't run: the error its last start failed with, kept
  /// until a start succeeds. The controller's own error isn't enough:
  /// mobile_scanner clears it with any later change of the camera's state,
  /// such as an iPad turning, although the camera is still off.
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

  /// The last start was refused the camera.
  bool _refused = false;
  bool _disposed = false;
  Future<void> _op = Future.value();

  /// Whether the scanner's screen is shown: false while another branch is,
  /// or a route covers it. Opening it asks for a refused camera again.
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    _sync(askAgain: visible);
  }

  /// Starts the camera again (Allow camera, Try again). A refused camera is
  /// asked for again, unless only Settings can allow it.
  void retry() => _sync(askAgain: true);

  /// Opens the app's page in the system's Settings, where the camera is
  /// allowed. False when it couldn't.
  Future<bool> openSettings() => device.openAppSettings();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    _resumed = resumed;
    _sync();
  }

  void _sync({bool askAgain = false}) {
    // A stop that fails leaves the camera as it is; the next change tries
    // again.
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
        // Not the time to ask, or only Settings can allow it.
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
      // A camera that doesn't start shows why in the preview.
    }
    if (_disposed) return;
    _refused = controller.value.error?.errorCode ==
        MobileScannerErrorCode.permissionDenied;
    final refusedAs = _refused ? await device.cameraAccess() : null;
    if (_disposed) return;
    access.value = refusedAs;
  }

  /// Stops following the app's lifecycle. The camera stops with its
  /// controller.
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_followCamera);
    access.dispose();
    error.dispose();
  }
}

/// A scanner's camera, with [overlay] (its frame and hint) over the camera
/// while it runs or starts, and why it won't run ([ScannerErrorView]) in
/// their place when it can't: from [session], which keeps why, rather than
/// from the controller, which forgets it.
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
      // The camera, or why it won't run, fills the space.
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: session.controller,
          onDetect: onDetect,
          // Why is drawn above, from the session.
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

/// Why a camera won't run, as the seller is told.
enum _Blocked {
  /// Refused, and the app may ask again: Android after a first "Deny", iOS
  /// before it asked.
  askable,

  /// Refused for good: only the system's Settings can allow it.
  inSettings,

  /// A device policy forbids it.
  restricted,

  /// Refused, and the check of how hasn't answered yet.
  checking,

  /// The device has no camera.
  noCamera,

  /// It didn't start.
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
        // Allowed meanwhile: starting again will do.
        CameraAccess.granted => _Blocked.failed,
      },
      MobileScannerErrorCode.unsupported => _Blocked.noCamera,
      _ => _Blocked.failed,
    };

/// What a scanner shows instead of its preview when the camera won't run
/// ([ScannerPreview]): why, in the app's language, and the buttons that fix
/// it. A refused camera offers Allow camera while Android may still ask,
/// and Open Settings; a camera that failed, Try again.
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
        // A camera that is there but refused is "off"; one that is missing
        // or broken is told as such.
        final refused = switch (blocked) {
          _Blocked.noCamera || _Blocked.failed => false,
          _ => true,
        };
        final headline = refused ? s.cameraAccessOff : message!;
        final body = refused ? message : null;
        // A label wraps between its words on a narrow layout.
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

        // White on the camera's black, centered, and scrolling when large
        // text on a short window needs it.
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

/// The flashlight switch of a scanner's app bar. Shown only while the camera
/// runs and has a flashlight (iPads and some Android phones have none), and
/// drawn from what the camera reports, so it can't fall out of step.
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
              // The flashlight stays as it was, and its icon with it.
            }
          },
        );
      },
    );
  }
}

/// Tells the seller the camera is off ([access]) and how to turn it on: Open
/// Settings, or only Close when a device policy forbids it. For the camera
/// used outside a scanner (a product photo).
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
      // A long message scrolls above the buttons when the dialog can't fit
      // it (large text on a short or zoomed-in screen).
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
          // Side by side, or stacked when a label wouldn't fit its half.
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
