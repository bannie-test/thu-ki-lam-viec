/// Small date/time formatting helpers in Vietnamese.
library;

String two(int n) => n.toString().padLeft(2, '0');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime? parseDayKey(String s) {
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

const weekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];
const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String weekdayName(DateTime d) => weekdayNames[d.weekday - 1];

/// "Thứ Sáu, 27 tháng 11, 2026"
String longDate(DateTime d) =>
    '${weekdayName(d)}, ${d.day} tháng ${d.month}, ${d.year}';

/// "27/11/2026"
String shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// "07:30"
String clock(int minutes) => '${two(minutes ~/ 60)}:${two(minutes % 60)}';

/// Friendly relative day name: "Hôm nay", "Ngày mai", "Hôm qua", or the weekday + date.
String relativeDay(DateTime d, DateTime now) {
  final diff = dateOnly(d).difference(dateOnly(now)).inDays;
  return switch (diff) {
    0 => 'Hôm nay',
    1 => 'Ngày mai',
    2 => 'Ngày kia',
    -1 => 'Hôm qua',
    _ => '${weekdayName(d)}, ${d.day}/${d.month}',
  };
}

/// Greeting by hour of the day.
String greeting(DateTime now) {
  final h = now.hour;
  if (h < 11) return 'Chào buổi sáng';
  if (h < 13) return 'Chào buổi trưa';
  if (h < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}
