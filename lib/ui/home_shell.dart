import 'package:flutter/material.dart';
import '../app.dart';
import '../core/format.dart';
import 'address_form.dart';
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
    final a = await askAddress(
      context,
      s.store.settings.address,
      firstRun: true,
    );
    if (a != null) {
      s.store.settings
        ..name = a.name
        ..selfPronoun = a.self;
    }
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
    final a = Services.of(context).store.settings.address;
    final titles = [
      a.hasName ? 'Việc của ${a.You}' : 'Sổ việc',
      'Lịch âm dương',
      'Nhóm việc',
    ];
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
