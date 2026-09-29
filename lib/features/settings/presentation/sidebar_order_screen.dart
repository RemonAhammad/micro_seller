import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/sidebar_items.dart';
import '../providers/settings_provider.dart';

/// Lets the user (a) drag-reorder the sidebar tabs and (b) toggle each tab's
/// visibility with a Cupertino switch. Both persist immediately; the sidebar
/// rebuilds live since it watches the same provider.
///
/// The Settings tab itself can never be hidden — the toggle is shown but
/// disabled — so the user can't soft-lock themselves out of this screen.
class SidebarOrderScreen extends ConsumerStatefulWidget {
  const SidebarOrderScreen({super.key});

  @override
  ConsumerState<SidebarOrderScreen> createState() => _SidebarOrderScreenState();
}

class _SidebarOrderScreenState extends ConsumerState<SidebarOrderScreen> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    // Snapshot once; we drive the local list from gestures and persist on drop.
    _order = List<String>.from(
        ref.read(settingsProvider.notifier).sidebarOrder);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    await ref
        .read(settingsProvider.notifier)
        .updateSidebarOrder(List<String>.from(_order));
  }

  Future<void> _resetToDefault() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.resetSidebarOrder();
    // Also clear all hidden flags on reset.
    for (final k in notifier.hiddenSidebarItems.toList()) {
      await notifier.toggleSidebarItemHidden(k, false);
    }
    setState(() {
      _order = List<String>.from(defaultSidebarOrder);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Watching settings here lets the toggles reflect the current persisted
    // state on every build (including immediately after a tap).
    ref.watch(settingsProvider);
    final hidden =
        ref.read(settingsProvider.notifier).hiddenSidebarItems.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.sidebarOrder),
        actions: [
          IconButton(
            tooltip: s.resetToDefault,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              s.sidebarOrderDesc,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _order.length,
              onReorder: _onReorder,
              itemBuilder: (ctx, i) {
                final item = sidebarItemByKey(_order[i]);
                final isVisible = !hidden.contains(item.key);
                final isSettings = item.key == 'settings';
                return Padding(
                  key: ValueKey(item.key),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            isVisible ? item.selectedIcon : item.icon,
                            color: isVisible
                                ? item.color
                                : cs.onSurface.withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label(context),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isVisible
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          // Visibility toggle. Disabled for the Settings tab
                          // — pinned visible so the user always has a way
                          // back to this screen.
                          CupertinoSwitch(
                            value: isVisible,
                            activeTrackColor: cs.primary,
                            onChanged: isSettings
                                ? null
                                : (v) async {
                                    await ref
                                        .read(settingsProvider.notifier)
                                        .toggleSidebarItemHidden(
                                            item.key, !v);
                                  },
                          ),
                          const SizedBox(width: 8),
                          ReorderableDragStartListener(
                            index: i,
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
