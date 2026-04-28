import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/sidebar_items.dart';
import '../providers/settings_provider.dart';

/// Lets the user drag-reorder the sidebar tabs. Persists immediately on each
/// drop; the sidebar updates live since it watches the same provider.
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
    await ref.read(settingsProvider.notifier).resetSidebarOrder();
    setState(() {
      _order = List<String>.from(defaultSidebarOrder);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                return Padding(
                  key: ValueKey(item.key),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: Icon(item.icon, color: cs.primary),
                      title: Text(
                        item.label(context),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: cs.onSurfaceVariant,
                        ),
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
