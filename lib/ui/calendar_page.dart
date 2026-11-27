import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import '../core/lunar.dart';
import '../theme/app_theme.dart';
import 'task_editor.dart';
import 'widgets.dart';

/// Month calendar showing both the solar and the Vietnamese lunar date.
class CalendarPage extends StatefulWidget {
  final ValueNotifier<DateTime> selected;
  const CalendarPage({super.key, required this.selected});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool lunarMode = false;
  late DateTime anchor = widget.selected.value;

  DateTime get selected => widget.selected.value;
  set selected(DateTime d) => widget.selected.value = dateOnly(d);

  /// Days shown in the grid for the current mode.
  List<DateTime> _days() {
    if (!lunarMode) {
      final count = DateTime(anchor.year, anchor.month + 1, 0).day;
      return [
        for (var i = 1; i <= count; i++) DateTime(anchor.year, anchor.month, i),
      ];
    }
    final l = LunarDate.fromSolar(anchor);
    final first = anchor.subtract(Duration(days: l.day - 1));
    final len = LunarDate.fromSolar(first).monthLength;
    return [
      for (var i = 0; i < len; i++)
        DateTime(first.year, first.month, first.day + i),
    ];
  }

  void _move(int delta) {
    setState(() {
      if (!lunarMode) {
        anchor = DateTime(anchor.year, anchor.month + delta, 1);
      } else {
        final days = _days();
        anchor = delta < 0
            ? days.first.subtract(const Duration(days: 1))
            : days.last.add(const Duration(days: 1));
        anchor = anchor.subtract(
          Duration(days: LunarDate.fromSolar(anchor).day - 1),
        );
      }
    });
  }

  void _today() => setState(() {
    selected = DateTime.now();
    anchor = selected;
  });

  String _header(List<DateTime> days) {
    if (!lunarMode) return 'Tháng ${anchor.month}, ${anchor.year}';
    final l = LunarDate.fromSolar(days.first);
    return 'Tháng ${lunarMonthName(l.month)}${l.leap ? ' nhuận' : ''} · ${canChiYear(l.year)}';
  }

  String _subHeader(List<DateTime> days) {
    if (!lunarMode) {
      final a = LunarDate.fromSolar(days.first),
          b = LunarDate.fromSolar(days.last);
      final m = a.month == b.month
          ? 'tháng ${a.month}'
          : 'tháng ${a.month} – ${b.month}';
      return 'Âm lịch: $m năm ${canChiYear(b.year)}';
    }
    final a = days.first, b = days.last;
    return 'Dương lịch: ${a.day}/${a.month} – ${b.day}/${b.month}/${b.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final look = Look.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.selected]),
      builder: (context, _) {
        final days = _days();
        final mondayFirst = store.settings.weekStartsMonday;
        final firstCol = mondayFirst
            ? days.first.weekday - 1
            : days.first.weekday % 7;
        final labels = mondayFirst
            ? weekdayShort
            : ['CN', ...weekdayShort.take(6)];
        final dayTasks = store.on(selected);
        final lunarSel = LunarDate.fromSolar(selected);
        final holidays = store.settings.showHolidays
            ? holidaysOn(selected, lunar: lunarSel)
            : const <Holiday>[];

        return ListView(
          padding: EdgeInsets.fromLTRB(look.gap, 4, look.gap, 120),
          children: [
            SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                minimumSize: Size(0, look.touch - 4),
                textStyle: theme.textTheme.titleMedium,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.wb_sunny_rounded),
                  label: Text('Dương lịch'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.nightlight_round),
                  label: Text('Âm lịch'),
                ),
              ],
              selected: {lunarMode},
              onSelectionChanged: (v) => setState(() {
                lunarMode = v.first;
                anchor = selected;
              }),
            ),
            SizedBox(height: look.gap * .75),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Tháng trước',
                  iconSize: 30,
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _header(days),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        _subHeader(days),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Tháng sau',
                  iconSize: 30,
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final (i, l) in labels.indexed)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                l,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: l == 'CN'
                                      ? theme.colorScheme.error
                                      : (i == 5 && mondayFirst
                                            ? theme.colorScheme.primary
                                            : null),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: firstCol + days.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: .78,
                          ),
                      itemBuilder: (context, i) {
                        if (i < firstCol) return const SizedBox.shrink();
                        final d = days[i - firstCol];
                        return _DayCell(
                          day: d,
                          lunarMode: lunarMode,
                          selected: sameDay(d, selected),
                          onTap: () => setState(() => selected = d),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _today,
                icon: const Icon(Icons.today_rounded),
                label: const Text('Về hôm nay'),
              ),
            ),
            Text(longDate(selected), style: theme.textTheme.titleLarge),
            Text(
              'Âm lịch: ${lunarLongLabel(lunarSel)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (holidays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '🎉 ${holidays.map((h) => h.name).join(' · ')}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            SizedBox(height: look.gap * .75),
            if (dayTasks.isEmpty)
              const EmptyNote(
                icon: Icons.event_available_rounded,
                text: 'Ngày này chưa có việc nào.',
              )
            else
              for (final o in dayTasks) TaskTile(o),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openTaskEditor(context, initialDate: selected),
              icon: const Icon(Icons.add_rounded),
              label: Text('Thêm việc ngày ${selected.day}/${selected.month}'),
            ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool lunarMode, selected;
  final VoidCallback onTap;
  const _DayCell({
    required this.day,
    required this.lunarMode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = Look.of(context);
    final l = LunarDate.fromSolar(day);
    final isToday = sameDay(day, DateTime.now());
    final special = l.isFirst || l.isFull;
    final holiday =
        store.settings.showHolidays && holidaysOn(day, lunar: l).isNotEmpty;
    final tasks = store.on(day);
    final colors = {
      for (final o in tasks) store.category(o.task.categoryId).colorValue,
    }.take(3).toList();
    final showSmall = lunarMode || store.settings.showLunarInGrid;

    final big = lunarMode ? '${l.day}' : '${day.day}';
    final small = lunarMode ? '${day.day}/${day.month}' : lunarCellLabel(l);
    final fg = selected
        ? scheme.onPrimary
        : (day.weekday == 7 || holiday ? scheme.error : scheme.onSurface);
    final smallColor = selected
        ? scheme.onPrimary
        : (special ? scheme.error : scheme.onSurfaceVariant);

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${longDate(day)}, âm lịch ${l.day} tháng ${l.month}${tasks.isEmpty ? '' : ', ${tasks.length} việc'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(look.radius * .6),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary
                : (special && !lunarMode
                      ? scheme.errorContainer.withValues(alpha: .35)
                      : null),
            borderRadius: BorderRadius.circular(look.radius * .6),
            border: isToday && !selected
                ? Border.all(color: scheme.primary, width: 2.5)
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    big,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: fg,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                if (showSmall)
                  FittedBox(
                    child: Text(
                      small,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: smallColor,
                        fontWeight: special ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in colors)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: selected ? scheme.onPrimary : c,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
