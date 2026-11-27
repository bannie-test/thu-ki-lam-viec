import 'package:flutter/material.dart';
import '../app.dart';
import '../models/settings.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final look = Look.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          void set(void Function(AppSettings s) f) => store.updateSettings(f);
          return ListView(
            padding: EdgeInsets.fromLTRB(look.gap, 8, look.gap, 48),
            children: [
              const _Header('Giao diện', Icons.palette_rounded),
              const _PreviewCard(),
              SizedBox(height: look.gap),
              _Group(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Bảng màu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in themePresets)
                          _PresetTile(
                            name: p.name,
                            color: Color(p.seed),
                            background: Color(p.lightBackground),
                            selected: s.preset == p.id,
                            onTap: () => set((x) => x.preset = p.id),
                          ),
                        _PresetTile(
                          name: 'Tự chọn',
                          color: Color(s.seedColor),
                          background: Theme.of(context).colorScheme.surface,
                          selected: s.preset == 'custom',
                          icon: Icons.colorize_rounded,
                          onTap: () => set((x) => x.preset = 'custom'),
                        ),
                      ],
                    ),
                  ),
                  if (s.preset == 'custom')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in customSeeds)
                            Semantics(
                              button: true,
                              selected: s.seedColor == c,
                              label: 'Chọn màu',
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => set((x) => x.seedColor = c),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: s.seedColor == c
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: s.seedColor == c
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
                    ),
                ],
              ),
              SizedBox(height: look.gap),
              _Group(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Chế độ sáng tối',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        minimumSize: Size(0, look.touch - 6),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: 'light',
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Sáng'),
                        ),
                        ButtonSegment(
                          value: 'dark',
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Tối'),
                        ),
                        ButtonSegment(
                          value: 'system',
                          icon: Icon(Icons.phone_android_rounded),
                          label: Text('Theo máy'),
                        ),
                      ],
                      selected: {s.mode},
                      onSelectionChanged: (v) => set((x) => x.mode = v.first),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cỡ chữ',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          _sizeName(s.textScale),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text('A', style: TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        child: Slider(
                          value: s.textScale,
                          min: 1.0,
                          max: 1.6,
                          divisions: 6,
                          label: _sizeName(s.textScale),
                          onChanged: (v) => set((x) => x.textScale = v),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  _Switch(
                    'Chữ đậm hơn',
                    'Dễ đọc hơn khi nhìn xa',
                    Icons.format_bold_rounded,
                    s.boldText,
                    (v) => set((x) => x.boldText = v),
                  ),
                  _Switch(
                    'Tương phản cao',
                    'Màu đậm, viền rõ — dễ nhìn ngoài nắng',
                    Icons.contrast_rounded,
                    s.highContrast,
                    (v) => set((x) => x.highContrast = v),
                  ),
                  _Switch(
                    'Bo góc mềm mại',
                    'Tắt để dùng góc vuông',
                    Icons.rounded_corner_rounded,
                    s.roundCorners,
                    (v) => set((x) => x.roundCorners = v),
                  ),
                  _Switch(
                    'Nút to, rộng rãi',
                    'Dễ chạm trúng hơn',
                    Icons.touch_app_rounded,
                    s.comfortable,
                    (v) => set((x) => x.comfortable = v),
                  ),
                ],
              ),

              const _Header('Xưng hô', Icons.person_rounded),
              _Group(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_rounded),
                    title: const Text('Ứng dụng gọi là'),
                    subtitle: Text(s.name),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: () async {
                      final c = TextEditingController(text: s.name);
                      final v = await showDialog<String>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('Ứng dụng nên gọi là gì?'),
                          content: TextField(
                            controller: c,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Ví dụ: Mẹ, Bà, Cô Lan',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d),
                              child: const Text('Thôi'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(d, c.text.trim()),
                              child: const Text('Lưu'),
                            ),
                          ],
                        ),
                      );
                      if (v != null && v.isNotEmpty) set((x) => x.name = v);
                    },
                  ),
                ],
              ),

              const _Header('Lịch', Icons.calendar_month_rounded),
              _Group(
                children: [
                  _Switch(
                    'Hiện ngày âm trên lịch',
                    'Số nhỏ dưới mỗi ngày dương',
                    Icons.nightlight_round,
                    s.showLunarInGrid,
                    (v) => set((x) => x.showLunarInGrid = v),
                  ),
                  _Switch(
                    'Hiện ngày lễ, Tết',
                    'Tết, Rằm tháng Giêng, Vu Lan, Trung Thu…',
                    Icons.celebration_rounded,
                    s.showHolidays,
                    (v) => set((x) => x.showHolidays = v),
                  ),
                  _Switch(
                    'Tuần bắt đầu từ thứ Hai',
                    'Tắt để bắt đầu từ Chủ nhật',
                    Icons.view_week_rounded,
                    s.weekStartsMonday,
                    (v) => set((x) => x.weekStartsMonday = v),
                  ),
                ],
              ),

              const _Header('Nhắc việc', Icons.notifications_rounded),
              _Group(
                children: [
                  _Switch(
                    'Thông báo nhắc việc',
                    'Điện thoại sẽ báo khi đến giờ',
                    Icons.notifications_active_rounded,
                    s.notifications,
                    (v) => set((x) => x.notifications = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Mặc định cho việc mới',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in reminderOptions.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: s.defaultRemind == e.key,
                            onSelected: (_) =>
                                set((x) => x.defaultRemind = e.key),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const _Header('Trợ lý AI', Icons.auto_awesome_rounded),
              const _AiSettings(),
              SizedBox(height: look.gap * 2),
              Center(
                child: Text(
                  'Việc của Mẹ · dữ liệu lưu trên điện thoại',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _sizeName(double v) {
    if (v < 1.1) return 'Vừa';
    if (v < 1.25) return 'Lớn';
    if (v < 1.45) return 'Rất lớn';
    return 'Cực lớn';
  }
}

class _Header extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Header(this.text, this.icon);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Switch extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch(
    this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.onChanged,
  );
  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon, size: 28),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class _PresetTile extends StatelessWidget {
  final String name;
  final Color color, background;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _PresetTile({
    required this.name,
    required this.color,
    required this.background,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Bảng màu $name',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Icon(
                  selected ? Icons.check_rounded : (icon ?? Icons.circle),
                  color: Colors.white,
                  size: selected || icon != null ? 22 : 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small live sample so changes are visible right away.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = Look.of(context);
    return Container(
      padding: EdgeInsets.all(look.gap),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(look.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_florist_rounded,
              color: scheme.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xem trước',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Chữ và màu sẽ trông như thế này.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: () {}, child: const Text('Nút')),
        ],
      ),
    );
  }
}

class _AiSettings extends StatefulWidget {
  const _AiSettings();
  @override
  State<_AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<_AiSettings> {
  bool? hasKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Services.of(context).ai.hasKey().then((v) {
      if (mounted) setState(() => hasKey = v);
    });
  }

  Future<void> _enterKey() async {
    final ai = Services.of(context).ai;
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nhập mã khóa AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mã khóa Claude API (bắt đầu bằng "sk-ant-"). Nhờ con cháu tạo tại console.anthropic.com.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Mã khóa'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    await ai.vault.write(v);
    if (mounted) setState(() => hasKey = true);
  }

  Future<void> _removeKey() async {
    await Services.of(context).ai.vault.write(null);
    if (mounted) setState(() => hasKey = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = Services.of(context).store;
    final theme = Theme.of(context);
    final s = store.settings;
    return _Group(
      children: [
        _Switch(
          'Dùng trợ lý AI',
          'Hiểu lời nói tự nhiên tốt hơn (cần mạng)',
          Icons.auto_awesome_rounded,
          s.aiEnabled,
          (v) => store.updateSettings((x) => x.aiEnabled = v),
        ),
        ListTile(
          leading: Icon(
            hasKey == true ? Icons.key_rounded : Icons.key_off_rounded,
            size: 28,
          ),
          title: Text(
            hasKey == true ? 'Đã có mã khóa AI' : 'Chưa có mã khóa AI',
          ),
          subtitle: Text(
            hasKey == true
                ? 'Lưu an toàn trong điện thoại'
                : 'Không có mã khóa vẫn dùng được chế độ đơn giản',
          ),
          trailing: hasKey == true
              ? TextButton(onPressed: _removeKey, child: const Text('Xóa'))
              : FilledButton.tonal(
                  onPressed: _enterKey,
                  child: const Text('Nhập'),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Trợ lý dùng Claude của Anthropic. Chỉ câu Mẹ nói hoặc gõ khi bấm "Tạo việc" mới được gửi đi; danh sách việc và cài đặt luôn ở trên máy. Phí dùng API tính riêng theo tài khoản của mã khóa.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
