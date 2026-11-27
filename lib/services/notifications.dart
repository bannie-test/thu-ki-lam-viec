import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/address.dart';
import '../core/format.dart';
import '../data/store.dart';
import '../models/task.dart';

/// Schedules phone notifications for upcoming tasks.
abstract class Reminders {
  Future<void> init();
  Future<void> requestPermissions();
  Future<void> rebuild(AppStore store);
}

class NoReminders implements Reminders {
  @override
  Future<void> init() async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> rebuild(AppStore store) async {}
}

class PhoneReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _queue = Future.value();

  /// Android limits pending alarms per app; keep the nearest ones.
  static const maxScheduled = 60;
  static const horizonDays = 45;

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_reminder'),
      ),
    );
  }

  @override
  Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  /// Serialised so quick successive edits cannot interleave.
  @override
  Future<void> rebuild(AppStore store) {
    _queue = _queue.then((_) => _rebuild(store)).catchError((Object _) {});
    return _queue;
  }

  static List<(DateTime, Occurrence)> plan(AppStore store, DateTime now) {
    final items = <(DateTime, Occurrence)>[];
    for (var i = 0; i <= horizonDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      for (final o in store.on(day)) {
        final t = o.task;
        if (t.remindBefore < 0 || o.done) continue;
        final at = t.momentOn(day).subtract(Duration(minutes: t.remindBefore));
        if (at.isAfter(now)) items.add((at, o));
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    return items.take(maxScheduled).toList();
  }

  /// Notification title and body, addressed the way the user chose,
  /// e.g. "Bà ơi, đến giờ rồi ạ · Hôm nay lúc 07:00 · Sức khỏe".
  static (String, String) reminderText(
    Occurrence o,
    DateTime at,
    Address a,
    String categoryName,
  ) {
    final t = o.task;
    final lead = t.time == null
        ? (sameDay(o.day, at) ? 'hôm nay có việc này' : 'sắp có việc này')
        : (t.remindBefore > 0 ? 'sắp đến giờ rồi' : 'đến giờ rồi');
    final opening = a.call.isEmpty
        ? '${lead[0].toUpperCase()}${lead.substring(1)}'
        : '${a.call}$lead';
    final when = t.time == null
        ? relativeDay(o.day, at)
        : '${relativeDay(o.day, at)} lúc ${clock(t.time!)}';
    final title = '${t.important ? '⭐ ' : ''}${t.title}';
    final body =
        '$opening${a.a} · $when · $categoryName${t.note.isEmpty ? '' : '\n${t.note}'}';
    return (title, body);
  }

  Future<void> _rebuild(AppStore store) async {
    await _plugin.cancelAll();
    if (!store.settings.notifications) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'viec_can_lam_v2',
        'Việc cần làm',
        channelDescription: 'Nhắc các việc đã ghi trong Sổ việc',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    var id = 1;
    final address = store.settings.address;
    for (final (at, o) in plan(store, DateTime.now())) {
      final (title, body) = reminderText(
        o,
        at,
        address,
        store.category(o.task.categoryId).name,
      );
      await _plugin.zonedSchedule(
        id++,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: o.task.id,
      );
    }
  }
}
