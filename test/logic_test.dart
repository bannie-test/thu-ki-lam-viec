import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_viec/core/format.dart';
import 'package:nhac_viec/core/lunar.dart';
import 'package:nhac_viec/models/category.dart';
import 'package:nhac_viec/models/task.dart';
import 'package:nhac_viec/services/local_parser.dart';

void main() {
  group('Âm lịch', () {
    test('Tết Bính Ngọ 2026 là 17/2/2026', () {
      expect(
        LunarDate.fromSolar(DateTime(2026, 2, 17)),
        const LunarDate(1, 1, 2026),
      );
      expect(const LunarDate(1, 1, 2026).toSolar(), DateTime(2026, 2, 17));
      expect(canChiYear(2026), 'Bính Ngọ');
      expect(canChiYear(2025), 'Ất Tỵ');
    });

    test('Tháng 2 nhuận năm 2023', () {
      final l = LunarDate.fromSolar(DateTime(2023, 3, 23));
      expect(l, const LunarDate(2, 2, 2023, leap: true));
      expect(l.toSolar(), DateTime(2023, 3, 23));
      expect(const LunarDate(2, 2, 2023).toSolar(), DateTime(2023, 2, 21));
    });

    test('Ngày không tồn tại trả về null', () {
      // Tháng Chạp năm Ất Tỵ (2025) có 29 ngày: 30 Tết rơi vào 29.
      final last = LunarDate.fromSolar(DateTime(2026, 2, 16));
      expect(last.month, 12);
      expect(LunarDate(30, 12, 2025).toSolar() == null, last.day == 29);
      expect(const LunarDate(5, 6, 2026, leap: true).toSolar(), isNull);
    });

    test('Tên ngày, tháng và ngày lễ', () {
      expect(lunarDayName(15), 'Rằm');
      expect(lunarDayName(3), 'Mùng 3');
      expect(lunarMonthName(1), 'Giêng');
      expect(lunarMonthName(12), 'Chạp');
      expect(
        holidaysOn(DateTime(2026, 2, 17)).map((h) => h.name),
        contains('Tết Nguyên Đán'),
      );
      expect(
        holidaysOn(DateTime(2026, 2, 16)).map((h) => h.name),
        contains('Giao thừa'),
      );
      expect(
        holidaysOn(DateTime(2026, 9, 2)).map((h) => h.name),
        contains('Quốc khánh'),
      );
      expect(
        holidaysOn(DateTime(2026, 9, 25)).map((h) => h.name),
        contains('Tết Trung Thu'),
      );
    });
  });

  group('Lặp lại', () {
    test('Mỗi ngày, chỉ tính từ ngày bắt đầu', () {
      final t = Task(
        id: '1',
        title: 'Thuốc',
        date: DateTime(2026, 1, 5),
        repeat: Repeat.daily,
      );
      expect(t.occursOn(DateTime(2026, 1, 4)), isFalse);
      expect(t.occursOn(DateTime(2026, 3, 1)), isTrue);
      t.done.add(dayKey(DateTime(2026, 1, 6)));
      expect(t.isDoneOn(DateTime(2026, 1, 6)), isTrue);
      expect(t.isDoneOn(DateTime(2026, 1, 7)), isFalse);
    });

    test('Mỗi tháng ngày 31 rơi vào ngày cuối tháng ngắn', () {
      final t = Task(
        id: '1',
        title: 'Tiền nhà',
        date: DateTime(2026, 1, 31),
        repeat: Repeat.monthly,
      );
      expect(t.occursOn(DateTime(2026, 2, 28)), isTrue);
      expect(t.occursOn(DateTime(2026, 4, 30)), isTrue);
      expect(t.occursOn(DateTime(2026, 4, 29)), isFalse);
    });

    test('Mỗi rằm âm lịch, kể cả tháng nhuận', () {
      final t = Task(
        id: '1',
        title: 'Đi chùa',
        date: DateTime(2026, 3, 3),
        repeat: Repeat.lunarMonthly,
      ); // 15/1 Bính Ngọ
      expect(LunarDate.fromSolar(DateTime(2026, 3, 3)).day, 15);
      var count = 0;
      for (
        var d = DateTime(2026, 3, 1);
        d.isBefore(DateTime(2027, 3, 1));
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        if (t.occursOn(d)) {
          count++;
          expect(LunarDate.fromSolar(d).day, 15);
        }
      }
      expect(count, greaterThanOrEqualTo(12));
    });

    test('Giỗ hằng năm theo âm lịch, bỏ qua tháng nhuận', () {
      // 10/2/2023 âm = 1/3/2023 dương
      final t = Task(
        id: '1',
        title: 'Giỗ ông',
        date: DateTime(2023, 3, 1),
        repeat: Repeat.lunarYearly,
      );
      expect(
        LunarDate.fromSolar(DateTime(2023, 3, 1)),
        const LunarDate(10, 2, 2023),
      );
      expect(
        t.occursOn(DateTime(2023, 3, 31)),
        isFalse,
        reason: '10/2 nhuận không phải ngày giỗ',
      );
      final next = t.nextOccurrence(DateTime(2023, 4, 1))!;
      expect(LunarDate.fromSolar(next), const LunarDate(10, 2, 2024));
    });

    test('Ngày 30 âm khi tháng chỉ có 29 ngày', () {
      final start = const LunarDate(30, 11, 2025).toSolar();
      expect(start, isNotNull);
      final t = Task(
        id: '1',
        title: 'Cúng cuối tháng',
        date: start!,
        repeat: Repeat.lunarMonthly,
      );
      final next = t.nextOccurrence(start.add(const Duration(days: 1)))!;
      final l = LunarDate.fromSolar(next);
      expect(l.day >= 29, isTrue);
      expect(LunarDate.fromSolar(next.add(const Duration(days: 1))).day, 1);
    });

    test('JSON giữ nguyên dữ liệu', () {
      final t = Task(
        id: 'a',
        title: 'Mua rau',
        date: DateTime(2026, 5, 2),
        time: 450,
        repeat: Repeat.weekly,
        important: true,
        note: 'Chợ Bến Thành',
      )..done.add('2026-05-09');
      final back = Task.fromJson(t.toJson());
      expect(back.toJson(), t.toJson());
    });
  });

  group('Hiểu câu tiếng Việt (không AI)', () {
    final now = DateTime(2026, 11, 27, 9, 0); // Thứ Sáu
    final cats = defaultCategories();

    test('Mai 7 giờ sáng uống thuốc huyết áp', () {
      final t = LocalParser.parse(
        'Mai 7 giờ sáng uống thuốc huyết áp',
        now,
        cats,
      ).single;
      expect(t.date, DateTime(2026, 11, 28));
      expect(t.time, 7 * 60);
      expect(t.categoryId, 'suc-khoe');
      expect(t.title, 'Uống thuốc huyết áp');
    });

    test('Giờ chiều, tối, rưỡi', () {
      expect(
        LocalParser.parse('3 giờ chiều đi chợ', now, cats).single.time,
        15 * 60,
      );
      expect(
        LocalParser.parse('8 giờ rưỡi tối xem thời sự', now, cats).single.time,
        20 * 60 + 30,
      );
      expect(
        LocalParser.parse('họp tổ dân phố 19:15', now, cats).single.time,
        19 * 60 + 15,
      );
    });

    test('Hằng ngày 6 giờ sáng đi bộ', () {
      final t = LocalParser.parse(
        'Hằng ngày 6 giờ sáng đi bộ',
        now,
        cats,
      ).single;
      expect(t.repeat, Repeat.daily);
      expect(t.time, 360);
      expect(t.categoryId, 'suc-khoe');
    });

    test('Giỗ theo âm lịch lặp mỗi năm', () {
      final t = LocalParser.parse(
        'Giỗ ông nội ngày 12/3 âm lịch',
        now,
        cats,
      ).single;
      expect(t.repeat, Repeat.lunarYearly);
      expect(t.lunarPicked, isTrue);
      final l = LunarDate.fromSolar(t.date);
      expect((l.day, l.month), (12, 3));
      expect(t.date.isAfter(now), isTrue);
      expect(t.categoryId, 'le-gio');
    });

    test('Rằm tới đi chùa', () {
      final t = LocalParser.parse('Rằm đi chùa', now, cats).single;
      expect(LunarDate.fromSolar(t.date).day, 15);
      expect(t.date.isBefore(now.add(const Duration(days: 31))), isTrue);
    });

    test('Thứ bảy và nhiều việc một lúc', () {
      final list = LocalParser.parse(
        'Thứ bảy 9 giờ đưa cháu đi khám răng\nNgày 5/12 đóng tiền điện',
        now,
        cats,
      );
      expect(list.length, 2);
      expect(list[0].date, DateTime(2026, 11, 28));
      expect(list[0].time, 9 * 60);
      expect(list[1].date, DateTime(2026, 12, 5));
      expect(list[1].categoryId, 'tien-nong');
    });

    test('Giờ đã qua trong ngày thì chuyển sang mai', () {
      final t = LocalParser.parse('6 giờ sáng tập thể dục', now, cats).single;
      expect(t.date, DateTime(2026, 11, 28));
    });
  });
}
