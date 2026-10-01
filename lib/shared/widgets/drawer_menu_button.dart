import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';

/// Global key used by the shell scaffold so any screen can open the drawer.
final shellScaffoldKey = GlobalKey<ScaffoldState>();

class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const ThinIcon(tabler.Menu2.new),
      tooltip: 'Menu',
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
