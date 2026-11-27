import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import 'calendar_page.dart';
import 'categories_page.dart';
import 'settings_page.dart';
import 'task_editor.dart';
import 'today_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  final selectedDay = ValueNotifier<DateTime>(dateOnly(DateTime.now()));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectedDay.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final s = Services.of(context);
      setState(() {}); // a new day may have started
      s.reminders.rebuild(s.store);
    }
  }

  Future<void> _welcome() async {
    final s = Services.of(context);
    if (s.store.onboarded) {
      await s.reminders.rebuild(s.store);
      return;
    }
    final name = TextEditingController(text: s.store.settings.name);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.favorite_rounded, size: 40),
        title: const Text('Chào mừng đến Việc của Mẹ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ứng dụng giúp ghi nhớ việc cần làm, có cả lịch âm. Ứng dụng nên gọi bạn là gì?',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Tên gọi',
                  hintText: 'Ví dụ: Mẹ',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bước tiếp theo, hãy cho phép thông báo để được nhắc đúng giờ.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
    s.store.settings.name = name.text.trim().isEmpty ? 'Mẹ' : name.text.trim();
    await s.store.finishOnboarding();
    try {
      await s.reminders.requestPermissions();
    } catch (_) {}
    await s.reminders.rebuild(s.store);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(onOpenCalendar: () => setState(() => tab = 1)),
      CalendarPage(selected: selectedDay),
      const CategoriesPage(),
    ];
    const titles = ['Việc của Mẹ', 'Lịch âm dương', 'Nhóm việc'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            iconSize: 30,
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add',
        onPressed: () => openTaskEditor(
          context,
          initialDate: tab == 1 ? selectedDay.value : null,
        ),
        icon: const Icon(Icons.add_rounded, size: 30),
        label: const Text('Thêm việc'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined, size: 28),
            selectedIcon: Icon(Icons.wb_sunny_rounded, size: 28),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, size: 28),
            selectedIcon: Icon(Icons.calendar_month_rounded, size: 28),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined, size: 28),
            selectedIcon: Icon(Icons.grid_view_rounded, size: 28),
            label: 'Nhóm việc',
          ),
        ],
      ),
    );
  }
}
