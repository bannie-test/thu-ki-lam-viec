import '../core/format.dart';
import '../core/lunar.dart';

enum Repeat {
  none('Không lặp lại'),
  daily('Mỗi ngày'),
  weekly('Mỗi tuần'),
  monthly('Mỗi tháng (dương)'),
  yearly('Mỗi năm (dương)'),
  lunarMonthly('Mỗi tháng (âm lịch)'),
  lunarYearly('Mỗi năm (âm lịch)');

  final String label;
  const Repeat(this.label);

  bool get isLunar => this == lunarMonthly || this == lunarYearly;

  static Repeat parse(String? s) =>
      Repeat.values.firstWhere((r) => r.name == s, orElse: () => Repeat.none);
}

/// Reminder offsets, in minutes before the task time. -1 means no reminder.
const reminderOptions = <int, String>{
  -1: 'Không nhắc',
  0: 'Đúng giờ',
  15: 'Trước 15 phút',
  60: 'Trước 1 giờ',
  1440: 'Trước 1 ngày',
};

class Task {
  final String id;
  String title;
  String note;
  String categoryId;

  /// First (or only) day the task happens, solar calendar, date only.
  DateTime date;

  /// Minutes after midnight, or null for an all-day task.
  int? time;
  Repeat repeat;
  int remindBefore;
  bool important;

  /// True when the date was chosen on the lunar calendar; used for display.
  bool lunarPicked;

  /// Completed occurrences, by [dayKey].
  Set<String> done;
  DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required DateTime date,
    this.note = '',
    this.categoryId = 'khac',
    this.time,
    this.repeat = Repeat.none,
    this.remindBefore = 0,
    this.important = false,
    this.lunarPicked = false,
    Set<String>? done,
    DateTime? createdAt,
  }) : date = dateOnly(date),
       done = done ?? <String>{},
       createdAt = createdAt ?? DateTime.now();

  Task copy() => Task.fromJson(toJson());

  bool get isRepeating => repeat != Repeat.none;

  /// Whether the task falls on solar day [day].
  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(date)) return false;
    switch (repeat) {
      case Repeat.none:
        return d == date;
      case Repeat.daily:
        return true;
      case Repeat.weekly:
        return d.weekday == date.weekday;
      case Repeat.monthly:
        final last = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (date.day > last ? last : date.day);
      case Repeat.yearly:
        if (d.month != date.month) return false;
        final last = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (date.day > last ? last : date.day);
      case Repeat.lunarMonthly:
      case Repeat.lunarYearly:
        final start = LunarDate.fromSolar(date);
        final l = LunarDate.fromSolar(d);
        if (repeat == Repeat.lunarYearly) {
          // Anniversaries (giỗ) are observed in the regular month, not the leap one.
          if (l.leap || l.month != start.month) return false;
        }
        if (l.day == start.day) return true;
        // Day 30 in a 29-day month moves to the last day of that month.
        if (start.day == 30 && l.day == 29) {
          return LunarDate.fromSolar(d.add(const Duration(days: 1))).day == 1;
        }
        return false;
    }
  }

  bool isDoneOn(DateTime day) => done.contains(dayKey(day));

  /// The moment the occurrence on [day] happens (09:00 for all-day tasks
  /// when a reminder time is needed).
  DateTime momentOn(DateTime day, {int allDayMinutes = 8 * 60}) {
    final m = time ?? allDayMinutes;
    return DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
  }

  /// Next day on/after [from] when the task happens, searching up to [days].
  DateTime? nextOccurrence(DateTime from, {int days = 800}) {
    var d = dateOnly(from);
    if (d.isBefore(date)) d = date;
    if (repeat == Repeat.none) return d == date ? d : null;
    for (var i = 0; i < days; i++) {
      if (occursOn(d)) return d;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'categoryId': categoryId,
    'date': dayKey(date),
    'time': time,
    'repeat': repeat.name,
    'remindBefore': remindBefore,
    'important': important,
    'lunarPicked': lunarPicked,
    'done': done.toList()..sort(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    note: j['note'] as String? ?? '',
    categoryId: j['categoryId'] as String? ?? 'khac',
    date: parseDayKey(j['date'] as String? ?? '') ?? DateTime.now(),
    time: j['time'] as int?,
    repeat: Repeat.parse(j['repeat'] as String?),
    remindBefore: j['remindBefore'] as int? ?? 0,
    important: j['important'] as bool? ?? false,
    lunarPicked: j['lunarPicked'] as bool? ?? false,
    done: {...((j['done'] as List?) ?? const []).cast<String>()},
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
  );
}

/// One task on one particular day.
class Occurrence {
  final Task task;
  final DateTime day;
  const Occurrence(this.task, this.day);
  bool get done => task.isDoneOn(day);
}

int _idCounter = 0;
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idCounter++).toRadixString(36)}';
