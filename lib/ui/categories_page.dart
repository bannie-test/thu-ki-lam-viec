import 'package:flutter/material.dart';
import '../app.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'task_editor.dart';
import 'widgets.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final look = Look.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final width = MediaQuery.sizeOf(context).width;
        final columns = width > 700 ? 4 : (width > 420 ? 3 : 2);
        return ListView(
          padding: EdgeInsets.fromLTRB(look.gap, 4, look.gap, 120),
          children: [
            Text(
              'Chạm vào một nhóm để xem các việc trong nhóm.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: look.gap),
            // Cards size to their content so very large text never gets cut off.
            LayoutBuilder(
              builder: (context, box) {
                final spacing = look.gap * .75;
                final w = (box.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final c in store.categories)
                      SizedBox(
                        width: w,
                        child: _CategoryCard(
                          category: c,
                          pending: store.pendingIn(c.id, now),
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: look.gap),
            OutlinedButton.icon(
              onPressed: () => editCategory(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Tạo nhóm mới'),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final int pending;
  const _CategoryCard({required this.category, required this.pending});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CategoryTasksPage(categoryId: category.id),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                category.colorValue.withValues(alpha: .16),
                category.colorValue.withValues(alpha: .04),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryBadge(category: category, size: 68),
              const SizedBox(height: 10),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                pending == 0 ? 'Không có việc' : '$pending việc sắp tới',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryTasksPage extends StatelessWidget {
  final String categoryId;
  const CategoryTasksPage({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final look = Look.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.category(categoryId);
        final now = DateTime.now();
        final all = store.nextInCategory(c.id, now);
        final open = all.where((o) => !o.done).toList();
        final finished = all.where((o) => o.done).toList();
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CategoryBadge(category: c, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Text(c.name)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Sửa nhóm',
                iconSize: 28,
                onPressed: () => editCategory(context, existing: c),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add-cat',
            onPressed: () => openTaskEditor(context, categoryId: c.id),
            icon: const Icon(Icons.add_rounded, size: 30),
            label: const Text('Thêm việc'),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(look.gap, 8, look.gap, 120),
            children: [
              if (open.isEmpty)
                const EmptyNote(
                  icon: Icons.inbox_rounded,
                  text: 'Nhóm này chưa có việc nào đang chờ.',
                ),
              for (final o in open)
                TaskTile(
                  o,
                  showDate: true,
                  overdue:
                      o.task.repeat == Repeat.none &&
                      o.day.isBefore(DateTime(now.year, now.month, now.day)),
                ),
              if (finished.isNotEmpty) ...[
                const SectionTitle(
                  'Đã xong',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
                for (final o in finished) TaskTile(o, showDate: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet to create or edit a category, with the grouped icon picker.
Future<void> editCategory(BuildContext context, {Category? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditor(existing: existing),
  );
}

class _CategoryEditor extends StatefulWidget {
  final Category? existing;
  const _CategoryEditor({this.existing});
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late String icon = widget.existing?.icon ?? 'star';
  late int color = widget.existing?.color ?? categoryColors[5];

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = Services.of(context).store;
    final text = name.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy đặt tên cho nhóm nhé.')),
      );
      return;
    }
    await store.upsertCategory(
      Category(
        id: widget.existing?.id ?? 'nhom-${newId()}',
        name: text,
        icon: icon,
        color: color,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final store = Services.of(context).store;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa nhóm này?'),
        content: const Text(
          'Các việc trong nhóm sẽ được chuyển sang "Việc khác", không bị mất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa nhóm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    await store.deleteCategory(widget.existing!.id);
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = Category(id: '', name: name.text, icon: icon, color: color);
    final canDelete =
        widget.existing != null && widget.existing!.id != otherCategoryId;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        maxChildSize: .95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                CategoryBadge(category: preview, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.existing == null ? 'Nhóm mới' : 'Sửa nhóm',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                labelText: 'Tên nhóm',
                hintText: 'Ví dụ: Cháu nội',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text('Màu', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in categoryColors)
                  Semantics(
                    button: true,
                    selected: c == color,
                    label: 'Màu',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => color = c),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == color
                                ? scheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: c == color
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final g in iconGroups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(g.name, style: theme.textTheme.titleMedium),
              ),
              IconGroupPicker(
                group: g,
                selected: icon,
                color: Color(color),
                onPick: (k) => setState(() => icon = k),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Lưu nhóm'),
            ),
            if (canDelete) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Xóa nhóm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IconGroupPicker extends StatelessWidget {
  final IconGroup group;
  final String selected;
  final Color color;
  final ValueChanged<String> onPick;
  const IconGroupPicker({
    super.key,
    required this.group,
    required this.selected,
    required this.color,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in group.icons)
          Tooltip(
            message: i.label,
            child: Semantics(
              button: true,
              selected: i.key == selected,
              label: i.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPick(i.key),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: i.key == selected
                        ? color
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    i.icon,
                    size: 30,
                    color: i.key == selected
                        ? Colors.white
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
