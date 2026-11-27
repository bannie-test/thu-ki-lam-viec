import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import '../core/lunar.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'task_editor.dart';

/// Coloured circle with the category icon.
class CategoryBadge extends StatelessWidget {
  final Category category;
  final double size;
  final bool faded;
  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 52,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = category.colorValue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: faded ? c.withValues(alpha: .35) : c,
        shape: BoxShape.circle,
      ),
      child: Icon(category.iconData, color: Colors.white, size: size * .55),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  const SectionTitle(
    this.text, {
    super.key,
    this.icon,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: c, size: 26),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleLarge?.copyWith(color: c),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

String repeatShort(Repeat r) => switch (r) {
  Repeat.none => '',
  Repeat.daily => 'Hằng ngày',
  Repeat.weekly => 'Hằng tuần',
  Repeat.monthly => 'Hằng tháng',
  Repeat.yearly => 'Hằng năm',
  Repeat.lunarMonthly => 'Hằng tháng âm',
  Repeat.lunarYearly => 'Hằng năm âm',
};

/// Big, readable task card with a large tick button.
class TaskTile extends StatelessWidget {
  final Occurrence occurrence;
  final bool showDate;
  final bool overdue;
  const TaskTile(
    this.occurrence, {
    super.key,
    this.showDate = false,
    this.overdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final look = Look.of(context);
    final t = occurrence.task;
    final cat = store.category(t.categoryId);
    final done = occurrence.done;
    final now = DateTime.now();
    final meta = <(IconData, String)>[
      if (showDate || overdue)
        (Icons.calendar_today_rounded, relativeDay(occurrence.day, now)),
      (Icons.schedule_rounded, t.time == null ? 'Cả ngày' : clock(t.time!)),
      if (t.lunarPicked || t.repeat.isLunar)
        (
          Icons.nightlight_round,
          lunarShortLabel(LunarDate.fromSolar(occurrence.day)),
        ),
      if (t.isRepeating) (Icons.repeat_rounded, repeatShort(t.repeat)),
    ];
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(bottom: look.gap * .75),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openTaskEditor(context, existing: t),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cat.colorValue, width: 6)),
            ),
            padding: EdgeInsets.fromLTRB(12, look.gap * .8, 8, look.gap * .8),
            child: Row(
              children: [
                CategoryBadge(category: cat, faded: done),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            if (t.important && !done)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade700,
                                    size: 24,
                                  ),
                                ),
                              ),
                            TextSpan(text: t.title),
                          ],
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize:
                              (theme.textTheme.titleMedium?.fontSize ?? 16) *
                              1.12,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? muted : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          for (final (icon, label) in meta)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: overdue
                                      ? theme.colorScheme.error
                                      : muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: overdue
                                        ? theme.colorScheme.error
                                        : muted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (t.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          t.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DoneButton(occurrence: occurrence),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoneButton extends StatelessWidget {
  final Occurrence occurrence;
  const DoneButton({super.key, required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final scheme = Theme.of(context).colorScheme;
    final done = occurrence.done;
    final size = Look.of(context).touch;
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Đã xong. Chạm để bỏ đánh dấu' : 'Chạm để đánh dấu đã xong',
      child: InkResponse(
        radius: size * .6,
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          await store.setDone(occurrence.task, occurrence.day, !done);
          if (!done) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Giỏi quá! Đã xong "${occurrence.task.title}" 🎉',
                ),
                action: SnackBarAction(
                  label: 'Hoàn tác',
                  onPressed: () =>
                      store.setDone(occurrence.task, occurrence.day, false),
                ),
              ),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? Colors.green.shade600 : Colors.transparent,
            border: Border.all(
              color: done ? Colors.green.shade600 : scheme.outline,
              width: 3,
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: size * .6,
            color: done ? Colors.white : scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyNote({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}
