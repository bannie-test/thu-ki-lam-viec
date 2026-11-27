import 'package:vnlunar/vnlunar.dart' as vn;

/// Vietnamese lunar calendar helpers (time zone UTC+7).
///
/// All conversions go through `vnlunar`, which implements Hồ Ngọc Đức's
/// algorithm used by Vietnamese calendars.
class LunarDate {
  final int day, month, year;
  final bool leap;
  const LunarDate(this.day, this.month, this.year, {this.leap = false});

  factory LunarDate.fromSolar(DateTime d) {
    final r = vn.convertSolar2Lunar(d.day, d.month, d.year, 7);
    return LunarDate(r[0], r[1], r[2], leap: r[3] == 1);
  }

  /// Converts back to the solar calendar. Returns null when this lunar date
  /// does not exist (for example day 30 of a 29-day month, or a leap month
  /// that the year does not have).
  DateTime? toSolar() {
    final r = vn.convertLunar2Solar(day, month, year, leap, 7);
    if (r.length < 3 || r[0] == 0) return null;
    final solar = DateTime(r[2], r[1], r[0]);
    final back = LunarDate.fromSolar(solar);
    if (back != this) return null;
    return solar;
  }

  /// Number of days in this lunar month (29 or 30).
  int get monthLength {
    final first = LunarDate(1, month, year, leap: leap).toSolar();
    if (first == null) return 29;
    final day30 = LunarDate.fromSolar(first.add(const Duration(days: 29)));
    return day30.day == 30 ? 30 : 29;
  }

  bool get isFirst => day == 1;
  bool get isFull => day == 15;

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.day == day &&
      other.month == month &&
      other.year == year &&
      other.leap == leap;

  @override
  int get hashCode => Object.hash(day, month, year, leap);

  @override
  String toString() => '$day/$month${leap ? ' nhuận' : ''}/$year';
}

const _can = [
  'Canh',
  'Tân',
  'Nhâm',
  'Quý',
  'Giáp',
  'Ất',
  'Bính',
  'Đinh',
  'Mậu',
  'Kỷ',
];
const _chi = [
  'Thân',
  'Dậu',
  'Tuất',
  'Hợi',
  'Tý',
  'Sửu',
  'Dần',
  'Mão',
  'Thìn',
  'Tỵ',
  'Ngọ',
  'Mùi',
];

/// "Bính Ngọ" for 2026.
String canChiYear(int lunarYear) =>
    '${_can[lunarYear % 10]} ${_chi[lunarYear % 12]}';

/// "Giêng", "Hai", … "Chạp".
String lunarMonthName(int month) => const [
  'Giêng',
  'Hai',
  'Ba',
  'Tư',
  'Năm',
  'Sáu',
  'Bảy',
  'Tám',
  'Chín',
  'Mười',
  'Một',
  'Chạp',
][(month - 1).clamp(0, 11)];

/// "Mùng 5", "Rằm", "20".
String lunarDayName(int day) {
  if (day == 15) return 'Rằm';
  if (day <= 10) return 'Mùng $day';
  return '$day';
}

/// Short cell label: "1/10" on the first day of a month, otherwise the day.
String lunarCellLabel(LunarDate l) =>
    l.day == 1 ? '1/${l.month}${l.leap ? 'N' : ''}' : '${l.day}';

/// "Mùng 8 tháng Mười năm Bính Ngọ".
String lunarLongLabel(LunarDate l) {
  final day = l.day == 15 ? 'Rằm' : lunarDayName(l.day);
  return '$day tháng ${lunarMonthName(l.month)}${l.leap ? ' (nhuận)' : ''} năm ${canChiYear(l.year)}';
}

/// "8/10 âm lịch" style short text.
String lunarShortLabel(LunarDate l) =>
    '${l.day}/${l.month}${l.leap ? ' nhuận' : ''} âm lịch';

class Holiday {
  final String name;
  final bool lunar;
  const Holiday(this.name, {this.lunar = false});
}

const _lunarHolidays = <(int, int), String>{
  (1, 1): 'Tết Nguyên Đán',
  (2, 1): 'Mùng 2 Tết',
  (3, 1): 'Mùng 3 Tết',
  (15, 1): 'Rằm tháng Giêng',
  (3, 3): 'Tết Hàn thực',
  (10, 3): 'Giỗ Tổ Hùng Vương',
  (15, 4): 'Lễ Phật Đản',
  (5, 5): 'Tết Đoan Ngọ',
  (15, 7): 'Lễ Vu Lan',
  (15, 8): 'Tết Trung Thu',
  (23, 12): 'Ông Công Ông Táo',
};

const _solarHolidays = <(int, int), String>{
  (1, 1): 'Tết Dương lịch',
  (14, 2): 'Lễ Tình nhân',
  (8, 3): 'Quốc tế Phụ nữ',
  (30, 4): 'Giải phóng miền Nam',
  (1, 5): 'Quốc tế Lao động',
  (1, 6): 'Quốc tế Thiếu nhi',
  (2, 9): 'Quốc khánh',
  (20, 10): 'Phụ nữ Việt Nam',
  (20, 11): 'Nhà giáo Việt Nam',
  (24, 12): 'Giáng sinh',
};

/// Holidays falling on [d]. Lunar holidays are never observed in leap months.
List<Holiday> holidaysOn(DateTime d, {LunarDate? lunar}) {
  final l = lunar ?? LunarDate.fromSolar(d);
  final result = <Holiday>[];
  if (!l.leap) {
    final name = _lunarHolidays[(l.day, l.month)];
    if (name != null) result.add(Holiday(name, lunar: true));
  }
  // Giao thừa: last day of lunar month 12.
  if (!l.leap &&
      l.month == 12 &&
      LunarDate.fromSolar(d.add(const Duration(days: 1))).day == 1) {
    result.add(const Holiday('Giao thừa', lunar: true));
  }
  final s = _solarHolidays[(d.day, d.month)];
  if (s != null) result.add(Holiday(s));
  return result;
}
