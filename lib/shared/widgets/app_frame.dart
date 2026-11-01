import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/system_ui_style.dart';
import '../../features/settings/providers/display_scale_provider.dart';
import 'app_zoom.dart';
import 'keyboard_accessory_bar.dart';
import 'tap_outside_unfocus.dart';

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

class _SystemUiStyleScope extends StatelessWidget {
  const _SystemUiStyleScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(Theme.brightnessOf(context)),
    child: child,
  );
}

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
