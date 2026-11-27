import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import '../core/lunar.dart';
import '../models/task.dart';
import '../services/ai_service.dart';
import '../services/speech.dart';
import '../theme/app_theme.dart';
import 'task_editor.dart';
import 'widgets.dart';

Future<void> openAiSheet(BuildContext context, {bool listen = false}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AiSheet(startListening: listen),
    );

const _examples = [
  'Mai 7 giờ sáng uống thuốc huyết áp',
  'Rằm tháng này đi chùa',
  'Giỗ ông nội ngày 12/3 âm lịch',
  'Thứ bảy 9 giờ đưa cháu đi khám răng',
  'Hằng ngày 6 giờ sáng đi bộ',
  'Mùng 5 đóng tiền điện',
];

/// Speak or type a request → review the drafts → save.
class AiSheet extends StatefulWidget {
  final bool startListening;
  const AiSheet({super.key, this.startListening = false});
  @override
  State<AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends State<AiSheet> {
  final input = TextEditingController();
  bool listening = false, working = false;
  String? message, error;
  List<Task> drafts = [];
  Set<String> keep = {};

  @override
  void initState() {
    super.initState();
    if (widget.startListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleMic());
    }
  }

  Voice? _voice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice = Services.of(context).voice;
  }

  @override
  void dispose() {
    if (listening) _voice?.stop();
    input.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final voice = Services.of(context).voice;
    if (listening) {
      await voice.stop();
      setState(() => listening = false);
      return;
    }
    setState(() {
      listening = true;
      error = null;
    });
    final ok = await voice.start((words, done) {
      if (!mounted) return;
      setState(() {
        input.text = words;
        if (done) listening = false;
      });
    });
    if (!ok && mounted) {
      setState(() {
        listening = false;
        error =
            'Không mở được micro. Mẹ cho phép ứng dụng dùng micro, hoặc gõ chữ cũng được nhé.';
      });
    }
  }

  Future<void> _create() async {
    final text = input.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'Mẹ nói hoặc gõ việc cần làm trước nhé.');
      return;
    }
    final s = Services.of(context);
    if (listening) {
      await s.voice.stop();
      listening = false;
    }
    setState(() {
      working = true;
      error = null;
    });
    try {
      final r = await s.ai.createTasks(
        text,
        now: DateTime.now(),
        categories: s.store.categories,
        useAi: s.store.settings.aiEnabled,
        defaultRemind: s.store.settings.defaultRemind,
      );
      setState(() {
        drafts = r.tasks;
        keep = {for (final t in r.tasks) t.id};
        message = r.message;
      });
    } on AiException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Có lỗi khi tạo việc. Mẹ thử lại nhé.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _save() async {
    final store = Services.of(context).store;
    final chosen = drafts.where((t) => keep.contains(t.id)).toList();
    if (chosen.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await store.addTasks(chosen);
    nav.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Đã thêm ${chosen.length} việc ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = Look.of(context);
    final aiOn = s.store.settings.aiEnabled;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .92,
        maxChildSize: .96,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            look.gap + 4,
            0,
            look.gap + 4,
            look.gap * 2,
          ),
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trợ lý ghi việc',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FutureBuilder<bool>(
              future: s.ai.hasKey(),
              builder: (context, snap) {
                final smart = aiOn && (snap.data ?? false);
                return Text(
                  smart
                      ? 'Mẹ cứ nói tự nhiên, có thể nhiều việc một lúc. Trợ lý AI sẽ hiểu cả ngày âm lịch.'
                      : 'Đang dùng chế độ hiểu đơn giản (không cần mạng). Bật AI trong Cài đặt để hiểu tốt hơn.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                );
              },
            ),
            SizedBox(height: look.gap),
            TextField(
              controller: input,
              minLines: 3,
              maxLines: 6,
              style: theme.textTheme.titleMedium,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: listening
                    ? 'Đang nghe… Mẹ nói đi ạ'
                    : 'Ví dụ: Chủ nhật 8 giờ sáng đi ăn cỗ nhà bác Hai',
              ),
            ),
            SizedBox(height: look.gap * .75),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: working ? null : _toggleMic,
                    style: listening
                        ? OutlinedButton.styleFrom(
                            backgroundColor: scheme.errorContainer,
                            foregroundColor: scheme.onErrorContainer,
                          )
                        : null,
                    icon: Icon(
                      listening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 28,
                    ),
                    label: Text(listening ? 'Dừng nghe' : 'Nói'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: working ? null : _create,
                    icon: working
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(working ? 'Đang nghĩ…' : 'Tạo việc'),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              SizedBox(height: look.gap),
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (drafts.isEmpty && !working) ...[
              SizedBox(height: look.gap * 1.5),
              Text('Thử một câu mẫu:', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _examples)
                    ActionChip(
                      label: Text(e),
                      onPressed: () => setState(() => input.text = e),
                    ),
                ],
              ),
            ],
            if (message != null && !working) ...[
              SizedBox(height: look.gap * 1.5),
              Text(
                message!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
            if (drafts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Bỏ chọn việc không cần, chạm vào việc để sửa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              for (final (i, t) in drafts.indexed)
                _DraftCard(
                  task: t,
                  kept: keep.contains(t.id),
                  onToggle: (v) =>
                      setState(() => v ? keep.add(t.id) : keep.remove(t.id)),
                  onEdit: () async {
                    final edited = await editDraft(context, t);
                    if (edited != null) setState(() => drafts[i] = edited);
                  },
                ),
              SizedBox(height: look.gap),
              FilledButton.icon(
                onPressed: keep.isEmpty ? null : _save,
                icon: const Icon(Icons.check_rounded, size: 28),
                label: Text('Lưu ${keep.length} việc'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final Task task;
  final bool kept;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  const _DraftCard({
    required this.task,
    required this.kept,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final cat = store.category(task.categoryId);
    final now = DateTime.now();
    final lunar = LunarDate.fromSolar(task.date);
    final diff = task.date
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final day = diff >= -1 && diff <= 2
        ? '${relativeDay(task.date, now)} (${shortDate(task.date)})'
        : '${weekdayName(task.date)}, ${shortDate(task.date)}';
    final when = '$day · ${task.time == null ? 'cả ngày' : clock(task.time!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Checkbox(value: kept, onChanged: (v) => onToggle(v ?? false)),
                CategoryBadge(category: cat, size: 46, faded: !kept),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task.important ? '⭐ ' : ''}${task.title}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(when, style: theme.textTheme.bodyMedium),
                      Text(
                        [
                          'Âm ${lunar.day}/${lunar.month}',
                          cat.name,
                          if (task.isRepeating) repeatShort(task.repeat),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (task.note.isNotEmpty)
                        Text(
                          task.note,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
