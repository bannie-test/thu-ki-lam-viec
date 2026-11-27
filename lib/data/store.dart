import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/format.dart';
import '../models/category.dart';
import '../models/settings.dart';
import '../models/task.dart';

/// Single source of truth for tasks, categories and settings.
/// Everything is stored on the phone (SharedPreferences, JSON).
class AppStore extends ChangeNotifier {
  static const _key = 'so_viec_v2';
  final SharedPreferences prefs;

  List<Task> tasks = [];
  List<Category> categories = defaultCategories();
  AppSettings settings = AppSettings();
  bool onboarded = false;

  /// Called after every saved change (used to refresh reminders).
  Future<void> Function()? onSaved;

  AppStore(this.prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      tasks = [
        for (final t in (j['tasks'] as List? ?? const []))
          Task.fromJson(Map<String, dynamic>.from(t as Map)),
      ];
      final cats = [
        for (final c in (j['categories'] as List? ?? const []))
          Category.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
      if (cats.isNotEmpty) categories = cats;
      settings = AppSettings.fromJson(
        Map<String, dynamic>.from(j['settings'] as Map? ?? const {}),
      );
      onboarded = j['onboarded'] as bool? ?? false;
    } catch (e) {
      debugPrint('Không đọc được dữ liệu cũ: $e');
    }
    if (!categories.any((c) => c.id == otherCategoryId)) {
      categories.add(defaultCategories().last);
    }
  }

  Future<void> save() async {
    await prefs.setString(
      _key,
      jsonEncode({
        'tasks': [for (final t in tasks) t.toJson()],
        'categories': [for (final c in categories) c.toJson()],
        'settings': settings.toJson(),
        'onboarded': onboarded,
      }),
    );
    notifyListeners();
    await onSaved?.call();
  }

  // ---------------- Categories ----------------
  Category category(String id) => categories.firstWhere(
    (c) => c.id == id,
    orElse: () => categories.firstWhere((c) => c.id == otherCategoryId),
  );

  Future<void> upsertCategory(Category c) async {
    final i = categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      categories[i] = c;
    } else {
      categories.insert(categories.length - 1, c); // keep "Việc khác" last
    }
    await save();
  }

  Future<void> deleteCategory(String id) async {
    if (id == otherCategoryId) return;
    categories.removeWhere((c) => c.id == id);
    for (final t in tasks) {
      if (t.categoryId == id) t.categoryId = otherCategoryId;
    }
    await save();
  }

  /// Number of tasks in the category that still have something to do.
  int pendingIn(String categoryId, DateTime today) =>
      nextInCategory(categoryId, today).where((o) => !o.done).length;

  // ---------------- Tasks ----------------
  Future<void> upsertTask(Task t) async {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    await save();
  }

  Future<void> addTasks(Iterable<Task> list) async {
    tasks.addAll(list);
    await save();
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((t) => t.id == id);
    await save();
  }

  Future<void> setDone(Task t, DateTime day, bool value) async {
    final k = dayKey(day);
    value ? t.done.add(k) : t.done.remove(k);
    await save();
  }

  List<Occurrence> _sorted(List<Occurrence> list) => list
    ..sort((a, b) {
      final d = a.day.compareTo(b.day);
      if (d != 0) return d;
      final ta = a.task.time ?? -1, tb = b.task.time ?? -1;
      if (ta != tb) return ta.compareTo(tb);
      if (a.task.important != b.task.important) {
        return a.task.important ? -1 : 1;
      }
      return a.task.title.compareTo(b.task.title);
    });

  List<Occurrence> on(DateTime day) => _sorted([
    for (final t in tasks)
      if (t.occursOn(day)) Occurrence(t, dateOnly(day)),
  ]);

  /// One-off tasks from earlier days that were never ticked.
  List<Occurrence> overdue(DateTime today) {
    final d = dateOnly(today);
    return _sorted([
      for (final t in tasks)
        if (t.repeat == Repeat.none &&
            t.date.isBefore(d) &&
            !t.isDoneOn(t.date))
          Occurrence(t, t.date),
    ]);
  }

  /// Occurrences from tomorrow for [days] days.
  List<Occurrence> upcoming(DateTime today, {int days = 7}) {
    final result = <Occurrence>[];
    for (var i = 1; i <= days; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      result.addAll(on(d));
    }
    return result;
  }

  /// Next occurrence per task in a category, soonest first (for the category screen).
  List<Occurrence> nextInCategory(String categoryId, DateTime today) {
    final result = <Occurrence>[];
    for (final t in tasks.where((t) => t.categoryId == categoryId)) {
      if (t.repeat == Repeat.none) {
        result.add(Occurrence(t, t.date));
        continue;
      }
      var from = dateOnly(today);
      DateTime? n;
      // Skip occurrences already ticked off today.
      for (var guard = 0; guard < 3; guard++) {
        n = t.nextOccurrence(from);
        if (n == null || !t.isDoneOn(n)) break;
        from = n.add(const Duration(days: 1));
      }
      if (n != null) result.add(Occurrence(t, n));
    }
    return _sorted(result);
  }

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    await save();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await save();
  }
}
