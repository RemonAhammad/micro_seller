import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category.dart';
import '../providers/category_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../settings/providers/trash_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.categories),
      ),
      body: categoriesAsync.when(
        data: (cats) {
          if (cats.isEmpty) {
            return EmptyState(
              icon: tabler.Category.new,
              title: s.noCategoriesYet,
              subtitle: s.addCategoriesToOrganise,
              actionLabel: s.addCategory,
              onAction: () => _showDialog(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => AnimatedEntrance(
              index: i,
              child: _CategoryTile(category: cats[i], ref: ref),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context, ref),
        tooltip: s.addCategory,
        child: const ThinIcon(tabler.Plus.new),
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref,
      {Category? existing}) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? s.addCategory : s.editCategory),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.categoryName,
          ),
          onSubmitted: (_) => _save(ctx, ref, ctrl, existing),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => _save(ctx, ref, ctrl, existing),
            child: Text(existing == null ? s.add : s.save),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext ctx, WidgetRef ref, TextEditingController ctrl,
      Category? existing) {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    if (existing == null) {
      ref
          .read(categoryProvider.notifier)
          .addCategory(Category(name: name));
    } else {
      ref
          .read(categoryProvider.notifier)
          .updateCategory(existing.copyWith(name: name));
    }
    Navigator.pop(ctx);
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final WidgetRef ref;

  const _CategoryTile({required this.category, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(category.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const ThinIcon(tabler.Trash.new,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        final s = AppStrings.of(context);
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.deleteCategory),
            content: Text(
                '${s.delete} "${category.name}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    Text(s.delete, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final s = AppStrings.of(context);
        final trashId =
            await ref.read(categoryProvider.notifier).deleteCategory(category.id);
        if (trashId != null && context.mounted) {
          context.showUndoSnackBar(
            '${s.itemDeleted}: ${category.name}',
            onUndo: () => ref.read(trashProvider.notifier).restore(trashId),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ThinIcon(tabler.Tag.new,
                  color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.name,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const ThinIcon(tabler.Pencil.new, size: 20),
              onPressed: () => _showEditDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.editCategory),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: s.categoryName),
          onSubmitted: (_) => _saveEdit(ctx, ctrl),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => _saveEdit(ctx, ctrl),
              child: Text(s.save)),
        ],
      ),
    );
  }

  void _saveEdit(BuildContext ctx, TextEditingController ctrl) {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    ref
        .read(categoryProvider.notifier)
        .updateCategory(category.copyWith(name: name));
    Navigator.pop(ctx);
  }
}
