import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import '../core/lunar.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'ai_sheet.dart';
import 'widgets.dart';

class TodayPage extends StatelessWidget {
  final VoidCallback onOpenCalendar;
  const TodayPage({super.key, required this.onOpenCalendar});

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final look = Look.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final today = store.on(now);
        final overdue = store.overdue(now);
        final upcoming = store.upcoming(now, days: 7);
        final byDay = <DateTime, List<Occurrence>>{};
        for (final o in upcoming) {
          byDay.putIfAbsent(o.day, () => []).add(o);
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(look.gap, 4, look.gap, 120),
          children: [
            _DayHeader(
              now: now,
              done: today.where((o) => o.done).length,
              total: today.length,
              onTap: onOpenCalendar,
            ),
            SizedBox(height: look.gap),
            const _AssistantCard(),
            if (overdue.isNotEmpty) ...[
              SectionTitle(
                'Chưa làm từ hôm trước',
                icon: Icons.history_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              for (final o in overdue) TaskTile(o, overdue: true),
            ],
            SectionTitle('Hôm nay', icon: Icons.wb_sunny_rounded),
            if (today.isEmpty)
              const EmptyNote(
                icon: Icons.spa_rounded,
                text:
                    'Hôm nay chưa có việc nào. Nghỉ ngơi thôi, hoặc nhờ trợ lý ghi thêm việc nhé!',
              )
            else
              for (final o in today) TaskTile(o),
            if (byDay.isNotEmpty) ...[
              const SectionTitle('Sắp tới', icon: Icons.event_note_rounded),
              for (final e in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8, left: 4),
                  child: Text(
                    '${relativeDay(e.key, now)} · ${lunarShortLabel(LunarDate.fromSolar(e.key))}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final o in e.value) TaskTile(o),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime now;
  final int done, total;
  final VoidCallback onTap;
  const _DayHeader({
    required this.now,
    required this.done,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = Look.of(context);
    final lunar = LunarDate.fromSolar(now);
    final holidays = store.settings.showHolidays
        ? holidaysOn(now, lunar: lunar)
        : const <Holiday>[];
    final special = lunar.isFirst
        ? 'Hôm nay mùng Một'
        : (lunar.isFull ? 'Hôm nay ngày Rằm' : null);
    final onC = scheme.onPrimaryContainer;

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(look.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(look.gap + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.settings.address.greet(greeting(now)),
                style: theme.textTheme.headlineSmall?.copyWith(color: onC),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(look.radius * .7),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${now.day}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: scheme.primary,
                            height: 1.1,
                          ),
                        ),
                        FittedBox(
                          child: Text(
                            'Âm ${lunar.day}/${lunar.month}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          longDate(now),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onC,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.nightlight_round, size: 18, color: onC),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lunarLongLabel(lunar),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: onC,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (special != null || holidays.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (special != null)
                      _Pill(icon: Icons.brightness_2_rounded, text: special),
                    for (final h in holidays)
                      _Pill(icon: Icons.celebration_rounded, text: h.name),
                  ],
                ),
              ],
              if (total > 0) ...[
                const SizedBox(height: 16),
                Text(
                  done == total
                      ? 'Xong hết việc hôm nay rồi! 🎉'
                      : 'Đã xong $done / $total việc hôm nay',
                  style: theme.textTheme.titleMedium?.copyWith(color: onC),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 12,
                    backgroundColor: scheme.surface.withValues(alpha: .7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big, inviting entry point for the AI assistant.
class _AssistantCard extends StatelessWidget {
  const _AssistantCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = Look.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAiSheet(context),
        child: Padding(
          padding: EdgeInsets.all(look.gap),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.onSecondaryContainer,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhờ trợ lý ghi việc',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Nói hoặc gõ, ví dụ: "Mai 7 giờ sáng uống thuốc"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Nói để thêm việc',
                iconSize: 30,
                style: IconButton.styleFrom(
                  minimumSize: Size(look.touch, look.touch),
                ),
                onPressed: () => openAiSheet(context, listen: true),
                icon: const Icon(Icons.mic_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
