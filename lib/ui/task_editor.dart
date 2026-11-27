import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import '../core/lunar.dart';
import '../models/task.dart';
import '../services/local_parser.dart';
import '../theme/app_theme.dart';

/// Opens the editor and saves the result to the store.
Future<void> openTaskEditor(
  BuildContext context, {
  Task? existing,
  DateTime? initialDate,
  String? categoryId,
}) async {
  await Navigator.push<Task>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TaskEditorPage(
        existing: existing,
        initialDate: initialDate,
        categoryId: categoryId,
      ),
    ),
  );
}

/// Edits an unsaved draft (from the AI sheet) and returns the edited copy.
Future<Task?> editDraft(BuildContext context, Task draft) =>
    Navigator.push<Task>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TaskEditorPage(existing: draft, draftOnly: true),
      ),
    );

class TaskEditorPage extends StatefulWidget {
  final Task? existing;
  final DateTime? initialDate;
  final String? categoryId;
  final bool draftOnly;
  const TaskEditorPage({
    super.key,
    this.existing,
    this.initialDate,
    this.categoryId,
    this.draftOnly = false,
  });
  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late Task task;
  late final TextEditingController title, note;
  bool get isNew => widget.existing == null || widget.draftOnly;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final store = Services.of(context).store;
    task =
        widget.existing?.copy() ??
        Task(
          id: newId(),
          title: '',
          date: widget.initialDate ?? DateTime.now(),
          categoryId: widget.categoryId ?? store.categories.first.id,
          time: 8 * 60,
          remindBefore: store.settings.defaultRemind,
        );
    title = TextEditingController(text: task.title);
    note = TextEditingController(text: task.note);
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = title.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mẹ ghi tên việc giúp con nhé.')),
      );
      return;
    }
    task
      ..title = text
      ..note = note.text.trim();
    if (task.time == null && task.remindBefore > 0 && task.remindBefore < 1440)
      task.remindBefore = 0;
    final nav = Navigator.of(context);
    if (!widget.draftOnly) {
      await Services.of(context).store.upsertTask(task);
    }
    nav.pop(task);
  }

  Future<void> _delete() async {
    final store = Services.of(context).store;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa việc này?'),
        content: Text(
          task.isRepeating
              ? 'Việc lặp lại sẽ bị xóa ở tất cả các ngày.'
              : 'Không thể hoàn tác sau khi xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    await store.deleteTask(task.id);
    nav.pop();
  }

  Future<void> _pickSolar() async {
    final d = await showDatePicker(
      context: context,
      initialDate: task.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2199),
      helpText: 'Chọn ngày (dương lịch)',
      cancelText: 'Thôi',
      confirmText: 'Chọn',
    );
    if (d != null)
      setState(
        () => task
          ..date = d
          ..lunarPicked = false,
      );
  }

  Future<void> _pickLunar() async {
    final d = await showDialog<DateTime>(
      context: context,
      builder: (_) => LunarPickerDialog(initial: task.date),
    );
    if (d != null)
      setState(
        () => task
          ..date = d
          ..lunarPicked = true,
      );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (task.time ?? 480) ~/ 60,
        minute: (task.time ?? 480) % 60,
      ),
      helpText: 'Chọn giờ',
      cancelText: 'Thôi',
      confirmText: 'Chọn',
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => task.time = t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = Look.of(context);
    final now = DateTime.now();
    final lunar = LunarDate.fromSolar(task.date);
    final today = dateOnly(now);
    final nextFull = LocalParser.nextLunar(today, 15, null)!;
    final nextFirst = LocalParser.nextLunar(today, 1, null)!;

    Widget label(String text, IconData icon) => Padding(
      padding: EdgeInsets.only(top: look.gap * 1.4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: theme.textTheme.titleMedium)),
        ],
      ),
    );

    ChoiceChip chip(
      String text,
      bool selected,
      VoidCallback onTap, {
      IconData? icon,
    }) => ChoiceChip(
      label: Text(text),
      avatar: icon == null ? null : Icon(icon, size: 20),
      selected: selected,
      showCheckmark: icon == null,
      onSelected: (_) => onTap(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draftOnly
              ? 'Xem lại việc'
              : (isNew ? 'Thêm việc mới' : 'Sửa việc'),
        ),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: 'Xóa việc',
              iconSize: 28,
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(look.gap, 8, look.gap, look.gap),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 28),
            label: Text(widget.draftOnly ? 'Xong' : 'Lưu việc'),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(look.gap, 8, look.gap, 24),
        children: [
          TextField(
            controller: title,
            autofocus: isNew && task.title.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Việc cần làm',
              hintText: 'Ví dụ: Uống thuốc huyết áp',
            ),
          ),

          label('Nhóm việc', Icons.grid_view_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in store.categories)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: c.colorValue,
                    child: Icon(c.iconData, size: 16, color: Colors.white),
                  ),
                  label: Text(c.name),
                  selected: task.categoryId == c.id,
                  showCheckmark: false,
                  selectedColor: c.colorValue.withValues(alpha: .25),
                  side: BorderSide(
                    color: task.categoryId == c.id
                        ? c.colorValue
                        : scheme.outlineVariant,
                    width: task.categoryId == c.id ? 2 : 1,
                  ),
                  onSelected: (_) => setState(() => task.categoryId = c.id),
                ),
            ],
          ),

          label('Ngày', Icons.calendar_month_rounded),
          Card(
            child: Padding(
              padding: EdgeInsets.all(look.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(longDate(task.date), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Âm lịch: ${lunarLongLabel(lunar)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickSolar,
                          icon: const Icon(Icons.wb_sunny_rounded),
                          label: const Text('Dương lịch'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickLunar,
                          icon: const Icon(Icons.nightlight_round),
                          label: const Text('Âm lịch'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                'Hôm nay',
                task.date == today,
                () => setState(
                  () => task
                    ..date = today
                    ..lunarPicked = false,
                ),
              ),
              chip(
                'Ngày mai',
                task.date == today.add(const Duration(days: 1)),
                () => setState(
                  () => task
                    ..date = today.add(const Duration(days: 1))
                    ..lunarPicked = false,
                ),
              ),
              chip(
                'Rằm tới (${nextFull.day}/${nextFull.month})',
                task.date == nextFull,
                () => setState(
                  () => task
                    ..date = nextFull
                    ..lunarPicked = true,
                ),
              ),
              chip(
                'Mùng 1 tới (${nextFirst.day}/${nextFirst.month})',
                task.date == nextFirst,
                () => setState(
                  () => task
                    ..date = nextFirst
                    ..lunarPicked = true,
                ),
              ),
            ],
          ),

          label('Giờ', Icons.schedule_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                'Cả ngày',
                task.time == null,
                () => setState(() => task.time = null),
              ),
              for (final m in const [
                6 * 60 + 30,
                8 * 60,
                11 * 60 + 30,
                17 * 60,
                20 * 60,
              ])
                chip(
                  clock(m),
                  task.time == m,
                  () => setState(() => task.time = m),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_calendar_rounded, size: 20),
                label: Text(
                  task.time != null &&
                          ![390, 480, 690, 1020, 1200].contains(task.time)
                      ? 'Giờ khác: ${clock(task.time!)}'
                      : 'Giờ khác…',
                ),
                onPressed: _pickTime,
              ),
            ],
          ),

          label('Lặp lại', Icons.repeat_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in Repeat.values)
                chip(
                  r.label,
                  task.repeat == r,
                  () => setState(() => task.repeat = r),
                  icon: r.isLunar ? Icons.nightlight_round : null,
                ),
            ],
          ),
          if (task.repeat.isLunar)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                task.repeat == Repeat.lunarMonthly
                    ? 'Lặp vào ngày ${lunarDayName(lunar.day).toLowerCase()} mỗi tháng âm lịch.'
                    : 'Lặp vào ngày ${lunar.day} tháng ${lunarMonthName(lunar.month)} âm lịch mỗi năm.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),

          label('Nhắc trên điện thoại', Icons.notifications_active_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in reminderOptions.entries)
                if (task.time != null ||
                    e.key == -1 ||
                    e.key == 0 ||
                    e.key == 1440)
                  chip(
                    task.time == null && e.key == 0
                        ? 'Sáng hôm đó (8:00)'
                        : e.value,
                    task.remindBefore == e.key,
                    () => setState(() => task.remindBefore = e.key),
                  ),
            ],
          ),

          SizedBox(height: look.gap),
          Card(
            child: SwitchListTile(
              value: task.important,
              onChanged: (v) => setState(() => task.important = v),
              secondary: Icon(
                Icons.star_rounded,
                color: Colors.amber.shade700,
                size: 32,
              ),
              title: const Text('Việc quan trọng'),
              subtitle: const Text('Hiện ngôi sao và đưa lên đầu danh sách'),
            ),
          ),

          label('Ghi chú', Icons.sticky_note_2_rounded),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Địa điểm, đồ cần mang, số điện thoại…',
            ),
          ),
          if (!isNew && task.isRepeating) ...[
            SizedBox(height: look.gap),
            Text(
              'Đã làm ${task.done.length} lần.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pick a date on the Vietnamese lunar calendar.
class LunarPickerDialog extends StatefulWidget {
  final DateTime initial;
  const LunarPickerDialog({super.key, required this.initial});
  @override
  State<LunarPickerDialog> createState() => _LunarPickerDialogState();
}

class _LunarPickerDialogState extends State<LunarPickerDialog> {
  late LunarDate value = LunarDate.fromSolar(widget.initial);

  DateTime? get solar => value.toSolar();

  bool _hasLeap(int year, int month) =>
      LunarDate(1, month, year, leap: true).toSolar() != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thisYear = LunarDate.fromSolar(DateTime.now()).year;
    final years = [for (var y = thisYear - 1; y <= thisYear + 5; y++) y];
    if (!years.contains(value.year)) years.add(value.year);
    final leapPossible = _hasLeap(value.year, value.month);
    final s = solar;

    Widget dropdown<T>(
      String label,
      T v,
      List<T> items,
      String Function(T) text,
      ValueChanged<T> onChanged,
    ) => DropdownButtonFormField<T>(
      initialValue: v,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      style: theme.textTheme.titleMedium,
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(text(i))),
      ],
      onChanged: (x) => x == null ? null : onChanged(x),
    );

    return AlertDialog(
      icon: const Icon(Icons.nightlight_round, size: 36),
      title: const Text('Chọn ngày âm lịch'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: dropdown<int>(
                    'Ngày',
                    value.day,
                    [for (var i = 1; i <= 30; i++) i],
                    lunarDayName,
                    (d) => setState(
                      () => value = LunarDate(
                        d,
                        value.month,
                        value.year,
                        leap: value.leap,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: dropdown<int>(
                    'Tháng',
                    value.month,
                    [for (var i = 1; i <= 12; i++) i],
                    (m) => lunarMonthName(m),
                    (m) => setState(
                      () => value = LunarDate(value.day, m, value.year),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            dropdown<int>(
              'Năm',
              value.year,
              years,
              (y) => '$y (${canChiYear(y)})',
              (y) =>
                  setState(() => value = LunarDate(value.day, value.month, y)),
            ),
            if (leapPossible)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: value.leap,
                title: Text('Tháng ${lunarMonthName(value.month)} nhuận'),
                onChanged: (v) => setState(
                  () => value = LunarDate(
                    value.day,
                    value.month,
                    value.year,
                    leap: v ?? false,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              s == null
                  ? 'Tháng này không có ngày 30, chọn ngày 29 nhé.'
                  : 'Tức là ${longDate(s)} (dương lịch)',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: s == null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Thôi'),
        ),
        FilledButton(
          onPressed: s == null ? null : () => Navigator.pop(context, s),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}
