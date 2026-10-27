import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/system_ui_style.dart';
import '../../features/settings/providers/display_scale_provider.dart';
import 'app_zoom.dart';
import 'keyboard_accessory_bar.dart';
import 'tap_outside_unfocus.dart';

/// What the app puts around its router (MaterialApp.router's `builder`), so
/// every route, dialog, sheet, menu and snackbar gets it. From the outside
/// in:
///
/// 1. the status bar's style for the app's theme ([appSystemUiStyle]),
///    outside the zoom, so it doesn't rebuild on every keyboard frame;
/// 2. a tap outside the focused text field closes the keyboard
///    ([TapOutsideUnfocus]);
/// 3. the saved Display size / Text size ([AppZoom]);
/// 4. inside the zoom, iOS's bar over the number pads
///    ([KeyboardAccessoryHost]);
/// 5. [child], the router.
///
/// The widget tree is the same at every size and whatever the keyboard
/// does, so nothing here ever remounts the router.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _SystemUiStyleScope(
    child: TapOutsideUnfocus(
      child: _DisplayScaleScope(child: KeyboardAccessoryHost(child: child)),
    ),
  );
}

/// The status bar over the app, from the theme's brightness (System already
/// resolved to the phone's). A region nearer the status bar wins over this
/// one: the first-launch splash puts its own over itself.
class _SystemUiStyleScope extends StatelessWidget {
  const _SystemUiStyleScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(Theme.brightnessOf(context)),
    child: child,
  );
}

/// Applies the saved Display size / Text size around the router. Its own
/// widget, so a size change rebuilds only the zoom — not MaterialApp, its
/// theme and the Router.
class _DisplayScaleScope extends ConsumerWidget {
  const _DisplayScaleScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(displayScaleProvider);
    return AppZoom(
      displayPercent: scale.displayPercent,
      textPercent: scale.textPercent,
      child: child,
    );
  }
}
