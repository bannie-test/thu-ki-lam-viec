import '../core/format.dart';
import '../core/lunar.dart';
import '../models/category.dart';
import '../models/task.dart';

/// Offline, rule-based understanding of short Vietnamese sentences such as
/// "Mai 7 giờ sáng uống thuốc huyết áp" or "Giỗ bà nội 12/3 âm lịch".
/// Used when AI is off, has no key, or fails. The user always reviews the
/// result before it is saved.
class LocalParser {
  static const _keywords = <String, List<String>>{
    'suc-khoe': [
      'thuốc',
      'khám',
      'bác sĩ',
      'bệnh viện',
      'huyết áp',
      'tiểu đường',
      'tập',
      'đi bộ',
      'dưỡng sinh',
      'yoga',
      'răng',
      'tiêm',
    ],
    'le-gio': [
      'giỗ',
      'chùa',
      'cúng',
      'lễ',
      'rằm',
      'mùng một',
      'thắp hương',
      'thắp nhang',
      'đền',
      'nhà thờ',
      'tết',
    ],
    'nha-cua': [
      'chợ',
      'mua',
      'siêu thị',
      'nấu',
      'dọn',
      'giặt',
      'lau',
      'tưới',
      'sửa',
      'rau',
      'thịt',
      'cá',
    ],
    'gia-dinh': [
      'con',
      'cháu',
      'ông',
      'bà',
      'sinh nhật',
      'gọi điện',
      'gọi cho',
      'đón',
      'đưa',
    ],
    'hen-gap': [
      'hẹn',
      'họp',
      'gặp',
      'cà phê',
      'ăn cỗ',
      'đám cưới',
      'đám',
      'tiệc',
      'bạn',
    ],
    'tien-nong': [
      'tiền',
      'điện',
      'nước',
      'internet',
      'hóa đơn',
      'ngân hàng',
      'trả',
      'đóng',
      'gửi tiết kiệm',
      'lương',
      'hụi',
      'họ',
    ],
  };

  static String guessCategory(String text, List<Category> categories) {
    final t = text.toLowerCase();
    final ids = categories.map((c) => c.id).toSet();
    var best = otherCategoryId;
    var bestScore = 0;
    _keywords.forEach((id, words) {
      if (!ids.contains(id)) return;
      final score = words.where(t.contains).length;
      if (score > bestScore) {
        best = id;
        bestScore = score;
      }
    });
    if (bestScore == 0) {
      // Custom categories: match by their name.
      for (final c in categories) {
        if (c.name.length > 2 && t.contains(c.name.toLowerCase())) return c.id;
      }
    }
    return best;
  }

  static List<Task> parse(
    String input,
    DateTime now,
    List<Category> categories, {
    int defaultRemind = 0,
  }) {
    // Several tasks can be separated by new lines or ';'.
    final parts = input
        .split(RegExp(r'[\n;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return [for (final p in parts) _one(p, now, categories, defaultRemind)];
  }

  static Task _one(
    String text,
    DateTime now,
    List<Category> categories,
    int defaultRemind,
  ) {
    final t = ' ${text.toLowerCase()} ';
    final today = dateOnly(now);
    var date = today;
    var lunar = false;
    var repeat = Repeat.none;
    var dateFound = false;

    // ---- repeat ----
    final everyLunarMonth =
        RegExp(r'(mỗi|hằng|hàng) tháng').hasMatch(t) && t.contains('âm');
    if (RegExp(r'(mỗi|hằng|hàng) (ngày|sáng|tối|đêm)').hasMatch(t)) {
      repeat = Repeat.daily;
    }
    if (RegExp(r'(mỗi|hằng|hàng) tuần').hasMatch(t)) repeat = Repeat.weekly;
    if (RegExp(r'(mỗi|hằng|hàng) tháng').hasMatch(t)) {
      repeat = everyLunarMonth ? Repeat.lunarMonthly : Repeat.monthly;
    }
    if (RegExp(r'(mỗi|hằng|hàng) năm').hasMatch(t)) repeat = Repeat.yearly;
    if (t.contains('giỗ')) repeat = Repeat.lunarYearly;

    // ---- relative days ----
    if (t.contains('ngày mai') || RegExp(r'\smai\s').hasMatch(t)) {
      date = today.add(const Duration(days: 1));
      dateFound = true;
    } else if (t.contains('ngày kia') ||
        t.contains('ngày mốt') ||
        RegExp(r'\smốt\s').hasMatch(t)) {
      date = today.add(const Duration(days: 2));
      dateFound = true;
    } else if (t.contains('tuần sau') || t.contains('tuần tới')) {
      date = today.add(const Duration(days: 7));
      dateFound = true;
    }

    // ---- weekday: "thứ hai" … "chủ nhật" ----
    const weekdays = {
      'thứ hai': 1,
      'thứ 2': 1,
      'thứ ba': 2,
      'thứ 3': 2,
      'thứ tư': 3,
      'thứ 4': 3,
      'thứ năm': 4,
      'thứ 5': 4,
      'thứ sáu': 5,
      'thứ 6': 5,
      'thứ bảy': 6,
      'thứ 7': 6,
      'chủ nhật': 7,
    };
    for (final e in weekdays.entries) {
      if (t.contains(e.key)) {
        var diff = (e.value - today.weekday) % 7;
        if (diff == 0 && repeat == Repeat.none) diff = 7;
        if (t.contains('tuần sau') || t.contains('tuần tới')) {
          // The given weekday in next calendar week (weeks start on Monday).
          diff = (8 - today.weekday) + (e.value - 1);
        }
        date = today.add(Duration(days: diff));
        dateFound = true;
        if (repeat == Repeat.none &&
            RegExp(r'(mỗi|hằng|hàng|các) ').hasMatch(t)) {
          repeat = Repeat.weekly;
        }
        break;
      }
    }

    // ---- lunar specifics: "rằm", "mùng 1", "12/3 âm" ----
    final isLunarText =
        t.contains('âm lịch') ||
        RegExp(r'\d\s*âm').hasMatch(t) ||
        t.contains(' âm ');
    int? lunarDay, lunarMonth;
    if (t.contains('rằm')) {
      lunarDay = 15;
      final m = RegExp(r'rằm tháng (\d{1,2}|giêng|chạp)').firstMatch(t);
      if (m != null) lunarMonth = _monthWord(m[1]!);
      if (t.contains('mỗi') || t.contains('hằng') || t.contains('hàng')) {
        repeat = Repeat.lunarMonthly;
      }
    }
    final mung = RegExp(
      r'mùng\s*(\d{1,2}|một|hai|ba|bốn|năm|sáu|bảy|tám|chín|mười)(?:\s*tháng\s*(\d{1,2}|giêng|chạp))?',
    ).firstMatch(t);
    if (mung != null) {
      lunarDay = _numberWord(mung[1]!);
      if (mung[2] != null) lunarMonth = _monthWord(mung[2]!);
      if (t.contains('mỗi') || t.contains('hằng') || t.contains('hàng')) {
        repeat = Repeat.lunarMonthly;
      }
    }
    final slash = RegExp(
      r'(?:ngày\s*)?(\d{1,2})\s*[/\-]\s*(\d{1,2})(?:\s*[/\-]\s*(\d{4}))?',
    ).firstMatch(t);
    if (slash != null) {
      final d = int.parse(slash[1]!), m = int.parse(slash[2]!);
      final y = slash[3] == null ? null : int.parse(slash[3]!);
      if (isLunarText || t.contains('giỗ')) {
        lunarDay = d;
        lunarMonth = m;
      } else if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        var candidate = DateTime(y ?? today.year, m, d);
        if (y == null && candidate.isBefore(today)) {
          candidate = DateTime(today.year + 1, m, d);
        }
        date = candidate;
        dateFound = true;
      }
    }
    if (lunarDay != null && lunarDay >= 1 && lunarDay <= 30) {
      final solar = nextLunar(today, lunarDay, lunarMonth);
      if (solar != null) {
        date = solar;
        lunar = true;
        dateFound = true;
      }
    } else if (isLunarText && repeat == Repeat.yearly) {
      repeat = Repeat.lunarYearly;
    }
    if (lunar && repeat == Repeat.yearly) repeat = Repeat.lunarYearly;
    if (lunar && repeat == Repeat.monthly) repeat = Repeat.lunarMonthly;
    if (!dateFound && t.contains('hôm nay')) date = today;

    // ---- time ----
    int? minutes;
    final tm = RegExp(
      r'(\d{1,2})\s*(?:giờ|g|h|:)\s*(\d{1,2}|rưỡi|kém\s*\d{1,2})?\s*(?:phút)?',
    ).firstMatch(t);
    if (tm != null && !(slash != null && tm.start == slash.start)) {
      var h = int.parse(tm[1]!);
      var m = 0;
      final rest = tm[2];
      if (rest != null) {
        if (rest == 'rưỡi') {
          m = 30;
        } else if (rest.startsWith('kém')) {
          final k = int.tryParse(rest.replaceAll(RegExp(r'\D'), '')) ?? 0;
          h -= 1;
          m = 60 - k;
        } else {
          m = int.tryParse(rest) ?? 0;
        }
      }
      if (RegExp(r'chiều|tối|đêm').hasMatch(t) && h < 12) h += 12;
      if (t.contains('trưa') && h < 11) h += 12;
      if (h >= 0 && h < 24 && m >= 0 && m < 60) minutes = h * 60 + m;
    } else if (t.contains('sáng sớm')) {
      minutes = 6 * 60;
    } else if (t.contains('buổi sáng') || RegExp(r'\ssáng\s').hasMatch(t)) {
      minutes = 7 * 60;
    } else if (t.contains('trưa')) {
      minutes = 11 * 60 + 30;
    } else if (t.contains('chiều')) {
      minutes = 15 * 60;
    } else if (t.contains('tối')) {
      minutes = 19 * 60;
    }
    // "Hôm nay" with a time already passed → assume tomorrow for one-off tasks.
    if (!dateFound && minutes != null && repeat == Repeat.none) {
      final m = DateTime(
        date.year,
        date.month,
        date.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (m.isBefore(now)) date = date.add(const Duration(days: 1));
    }

    final title = _cleanTitle(text);
    return Task(
      id: newId(),
      title: title.isEmpty ? text.trim() : title,
      date: date,
      time: minutes,
      repeat: repeat,
      lunarPicked: lunar,
      remindBefore: minutes == null ? -1 : defaultRemind,
      categoryId: guessCategory(text, categories),
    );
  }

  /// Next solar date (on/after [from]) whose lunar day is [day] and, when
  /// given, lunar month is [month]. Leap months are skipped for a fixed month.
  static DateTime? nextLunar(DateTime from, int day, int? month) {
    var d = dateOnly(from);
    for (var i = 0; i < 400; i++) {
      final l = LunarDate.fromSolar(d);
      if (l.day == day && (month == null || (l.month == month && !l.leap))) {
        return d;
      }
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return null;
  }

  static int _numberWord(String s) =>
      int.tryParse(s) ??
      const {
        'một': 1,
        'hai': 2,
        'ba': 3,
        'bốn': 4,
        'năm': 5,
        'sáu': 6,
        'bảy': 7,
        'tám': 8,
        'chín': 9,
        'mười': 10,
      }[s] ??
      1;

  static int _monthWord(String s) =>
      s == 'giêng' ? 1 : (s == 'chạp' ? 12 : int.tryParse(s) ?? 1);

  /// Removes time/date phrases so the title reads naturally.
  static String _cleanTitle(String text) {
    var s = text;
    final patterns = [
      RegExp(
        r'\b(nhắc( mẹ| tôi| em)?|nhớ|ghi chú|thêm việc)\b[:,]?\s*',
        caseSensitive: false,
      ),
      RegExp(
        r'(vào\s+)?(lúc\s+)?\d{1,2}\s*(giờ|g|h|:)\s*(\d{1,2}|rưỡi|kém\s*\d{1,2})?\s*(phút)?(\s*(sáng|trưa|chiều|tối|đêm))?',
        caseSensitive: false,
      ),
      RegExp(
        r'(vào\s+)?(ngày\s+)?(mai|ngày kia|ngày mốt|hôm nay|tuần sau|tuần tới)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(mỗi|hằng|hàng)\s+(ngày|tuần|tháng|năm)(\s+âm( lịch)?)?',
        caseSensitive: false,
      ),
      RegExp(
        r'(vào\s+)?(ngày\s+)?\d{1,2}\s*[/\-]\s*\d{1,2}(\s*[/\-]\s*\d{4})?(\s*(âm lịch|âm|dương lịch|dương))?',
        caseSensitive: false,
      ),
      RegExp(
        r'(vào\s+)?(ngày\s+)?(rằm|mùng\s*\S+)(\s+tháng\s+(\d{1,2}|giêng|chạp|này|sau|tới))?(\s+âm( lịch)?)?',
        caseSensitive: false,
      ),
      RegExp(
        r'(vào\s+)?(thứ\s+(hai|ba|tư|năm|sáu|bảy|[2-7])|chủ nhật)(\s+(tuần sau|tuần tới|này))?',
        caseSensitive: false,
      ),
      RegExp(r'\b(âm lịch|lúc|vào)\b', caseSensitive: false),
    ];
    for (final p in patterns) {
      s = s.replaceAll(p, ' ');
    }
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    s = s.replaceAll(RegExp(r'^[,.\-:\s]+|[,.\-:\s]+$'), '');
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}
