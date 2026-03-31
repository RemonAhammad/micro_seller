import 'package:flutter/material.dart';

/// Global key used by the shell scaffold so any screen can open the drawer.
final shellScaffoldKey = GlobalKey<ScaffoldState>();

class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Menu',
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
