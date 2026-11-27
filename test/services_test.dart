import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nhac_viec/core/address.dart';
import 'package:nhac_viec/core/lunar.dart';
import 'package:nhac_viec/data/store.dart';
import 'package:nhac_viec/models/category.dart';
import 'package:nhac_viec/models/settings.dart';
import 'package:nhac_viec/models/task.dart';
import 'package:nhac_viec/services/ai_service.dart';
import 'package:nhac_viec/services/notifications.dart';
import 'package:nhac_viec/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryVault implements KeyVault {
  String? value;
  MemoryVault([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

String claudeReply(Map<String, dynamic> out, {String stop = 'end_turn'}) =>
    jsonEncode({
      'id': 'msg_1',
      'type': 'message',
      'role': 'assistant',
      'model': AiService.model,
      'stop_reason': stop,
      'content': [
        {'type': 'thinking', 'thinking': '', 'signature': 'x'},
        {'type': 'text', 'text': jsonEncode(out)},
      ],
    });

void main() {
  final now = DateTime(2026, 11, 27, 9);
  final cats = defaultCategories();

  group('Claude API', () {
    test('Yêu cầu dùng structured output và model mặc định', () {
      final body = AiService.buildRequest('Mai đi chợ', now, cats);
      expect(body['model'], 'claude-opus-5-5');
      expect(body.containsKey('thinking'), isFalse);
      expect(body['fallbacks'], 'default');
      final format = (body['output_config'] as Map)['format'] as Map;
      expect(format['type'], 'json_schema');
      expect(jsonEncode(format['schema']), contains('lunarYearly'));
      expect(body['system'] as String, contains('âm lịch 19/10'));
      expect(body['system'] as String, contains('suc-khoe'));
    });

    test('Đọc kết quả: dương lịch, âm lịch, dữ liệu sai', () {
      final r = AiService.parseResponse(
        claudeReply({
          'message': 'Cháu đã ghi 3 việc cho Bà ạ.',
          'tasks': [
            {
              'title': 'Uống thuốc',
              'category_id': 'suc-khoe',
              'calendar': 'solar',
              'date': '2026-11-28',
              'lunar_day': 0,
              'lunar_month': 0,
              'time': '07:00',
              'repeat': 'daily',
              'remind_before': 0,
              'important': true,
              'note': '',
            },
            {
              'title': 'Giỗ bà',
              'category_id': 'le-gio',
              'calendar': 'lunar',
              'date': '',
              'lunar_day': 12,
              'lunar_month': 3,
              'time': '',
              'repeat': 'lunarYearly',
              'remind_before': 1440,
              'important': true,
              'note': 'Mua hoa',
            },
            {
              'title': 'Việc lạ',
              'category_id': 'khong-co',
              'calendar': 'solar',
              'date': 'abc',
              'lunar_day': 0,
              'lunar_month': 0,
              'time': '25:99',
              'repeat': 'weird',
              'remind_before': 7,
              'important': false,
              'note': '',
            },
            {
              'title': '  ',
              'category_id': 'khac',
              'calendar': 'solar',
              'date': '2026-11-28',
              'lunar_day': 0,
              'lunar_month': 0,
              'time': '',
              'repeat': 'none',
              'remind_before': 0,
              'important': false,
              'note': '',
            },
          ],
        }),
        now,
        cats,
      );
      expect(r.usedAi, isTrue);
      expect(r.message, 'Cháu đã ghi 3 việc cho Bà ạ.');
      expect(r.tasks.length, 3);
      final a = r.tasks[0], b = r.tasks[1], c = r.tasks[2];
      expect(
        (a.date, a.time, a.repeat, a.important),
        (DateTime(2026, 11, 28), 420, Repeat.daily, true),
      );
      expect(b.lunarPicked, isTrue);
      expect(
        LunarDate.fromSolar(b.date),
        isA<LunarDate>().having((l) => (l.day, l.month), 'd/m', (12, 3)),
      );
      expect((b.time, b.remindBefore, b.note), (null, 1440, 'Mua hoa'));
      expect(
        (c.date, c.time, c.repeat, c.remindBefore, c.categoryId),
        (DateTime(2026, 11, 27), null, Repeat.none, 0, otherCategoryId),
      );
    });

    test('Từ chối và lỗi được báo bằng tiếng Việt', () {
      expect(
        () => AiService.parseResponse(
          claudeReply({}, stop: 'refusal'),
          now,
          cats,
        ),
        throwsA(isA<AiException>()),
      );
      expect(
        () => AiService.parseResponse('not json', now, cats),
        throwsA(isA<AiException>()),
      );
    });

    test('Gọi API với header đúng, có khóa', () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response.bytes(
          utf8.encode(
            claudeReply({
              'message': 'Xong',
              'tasks': [
                {
                  'title': 'Đi chợ',
                  'category_id': 'nha-cua',
                  'calendar': 'solar',
                  'date': '2026-11-28',
                  'lunar_day': 0,
                  'lunar_month': 0,
                  'time': '06:30',
                  'repeat': 'none',
                  'remind_before': 15,
                  'important': false,
                  'note': '',
                },
              ],
            }),
          ),
          200,
        );
      });
      final ai = AiService(vault: MemoryVault('sk-ant-test'), client: client);
      final r = await ai.createTasks(
        'Mai 6 rưỡi đi chợ',
        now: now,
        categories: cats,
        useAi: true,
      );
      expect(sent.headers['x-api-key'], 'sk-ant-test');
      expect(sent.headers['anthropic-version'], isNotEmpty);
      expect(r.tasks.single.title, 'Đi chợ');
      expect(r.tasks.single.remindBefore, 15);
    });

    test('Không có khóa thì dùng bộ hiểu đơn giản', () async {
      final ai = AiService(
        vault: MemoryVault(),
        client: MockClient((_) async => fail('không được gọi mạng')),
      );
      final r = await ai.createTasks(
        'Mai 7 giờ uống thuốc',
        now: now,
        categories: cats,
        useAi: true,
      );
      expect(r.usedAi, isFalse);
      expect(r.tasks.single.time, 420);
    });

    test('Khóa sai báo lỗi dễ hiểu', () async {
      final ai = AiService(
        vault: MemoryVault('bad'),
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      expect(
        () => ai.createTasks('x', now: now, categories: cats, useAi: true),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Mã khóa'),
          ),
        ),
      );
    });
  });

  group('Kho dữ liệu', () {
    late AppStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore(await SharedPreferences.getInstance());
    });

    test('Lưu và đọc lại', () async {
      await store.upsertTask(
        Task(id: '1', title: 'A', date: DateTime(2026, 11, 27), time: 600),
      );
      await store.upsertCategory(
        Category(
          id: 'moi',
          name: 'Cháu nội',
          icon: 'child',
          color: categoryColors.first,
        ),
      );
      await store.updateSettings(
        (s) => s
          ..preset = 'tra'
          ..textScale = 1.5,
      );
      final again = AppStore(store.prefs);
      expect(again.tasks.single.title, 'A');
      expect(again.categories.map((c) => c.id), contains('moi'));
      expect(again.categories.last.id, otherCategoryId);
      expect(again.settings.preset, 'tra');
      expect(again.settings.textScale, 1.5);
    });

    test('Việc quá hạn, xóa nhóm chuyển việc sang "Việc khác"', () async {
      await store.addTasks([
        Task(
          id: '1',
          title: 'Cũ',
          date: DateTime(2026, 11, 20),
          categoryId: 'tien-nong',
        ),
        Task(id: '2', title: 'Đã xong', date: DateTime(2026, 11, 21))
          ..done.add('2026-11-21'),
        Task(
          id: '3',
          title: 'Hằng ngày',
          date: DateTime(2026, 11, 1),
          repeat: Repeat.daily,
        ),
      ]);
      expect(store.overdue(now).map((o) => o.task.id), ['1']);
      expect(store.on(now).map((o) => o.task.id), ['3']);
      expect(store.upcoming(now, days: 3).length, 3);
      await store.deleteCategory('tien-nong');
      expect(store.tasks.first.categoryId, otherCategoryId);
      await store.deleteCategory(otherCategoryId);
      expect(store.categories.any((c) => c.id == otherCategoryId), isTrue);
    });

    test('Lịch nhắc: chỉ việc sắp tới, chưa xong, có nhắc', () async {
      final t0 = DateTime.now();
      final tomorrow = DateTime(t0.year, t0.month, t0.day + 1);
      await store.addTasks([
        Task(
          id: 'a',
          title: 'Nhắc',
          date: tomorrow,
          time: 480,
          remindBefore: 15,
        ),
        Task(
          id: 'b',
          title: 'Không nhắc',
          date: tomorrow,
          time: 480,
          remindBefore: -1,
        ),
        Task(id: 'c', title: 'Xong rồi', date: tomorrow, time: 480)
          ..done.add(
            '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}',
          ),
        Task(
          id: 'd',
          title: 'Mỗi ngày',
          date: tomorrow,
          time: 600,
          repeat: Repeat.daily,
        ),
      ]);
      final plan = PhoneReminders.plan(store, t0);
      expect(plan.first.$2.task.id, 'a');
      expect(
        plan.first.$1,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7, 45),
      );
      expect(
        plan.any((p) => p.$2.task.id == 'b' || p.$2.task.id == 'c'),
        isFalse,
      );
      expect(plan.length, lessThanOrEqualTo(PhoneReminders.maxScheduled));
    });
  });

  group('Giao diện theo cài đặt', () {
    test('Mọi bảng màu, sáng/tối, tương phản cao đều dựng được', () {
      for (final p in [...themePresets.map((p) => p.id), 'custom']) {
        for (final b in Brightness.values) {
          for (final hc in [false, true]) {
            final s = AppSettings(
              preset: p,
              highContrast: hc,
              roundCorners: !hc,
              comfortable: hc,
            );
            final t = buildTheme(s, b);
            expect(t.colorScheme.brightness, b);
            expect(t.extension<Look>(), isNotNull);
          }
        }
      }
    });

    test('Đổi cài đặt thì đổi màu và kích thước', () {
      final a = buildTheme(AppSettings(preset: 'sen'), Brightness.light);
      final b = buildTheme(AppSettings(preset: 'tra'), Brightness.light);
      expect(a.colorScheme.primary, isNot(b.colorScheme.primary));
      final square = buildTheme(
        AppSettings(roundCorners: false, comfortable: false),
        Brightness.light,
      ).extension<Look>()!;
      final round = buildTheme(
        AppSettings(),
        Brightness.light,
      ).extension<Look>()!;
      expect(square.radius, lessThan(round.radius));
      expect(square.touch, lessThan(round.touch));
      final custom = buildTheme(
        AppSettings(preset: 'custom', seedColor: 0xFF1565C0),
        Brightness.light,
      );
      expect(custom.colorScheme.primary, isNot(a.colorScheme.primary));
    });
  });

  group('Xưng hô', () {
    test('Có tên và xưng cháu', () {
      const a = Address(name: 'bà', self: 'cháu');
      expect(a.greet('Chào buổi sáng'), 'Chào buổi sáng, Bà!');
      expect(a.call, 'Bà ơi, ');
      expect(a.a, ' ạ');
    });

    test('Không có tên thì trung tính', () {
      const a = Address();
      expect(a.greet('Chào buổi tối'), 'Chào buổi tối!');
      expect((a.you, a.call, a.a), ('bạn', '', ''));
    });

    test('Thông báo dùng cách xưng hô đã chọn', () {
      final day = DateTime(2026, 11, 28);
      final t = Task(
        id: '1',
        title: 'Uống thuốc',
        date: day,
        time: 420,
        remindBefore: 0,
        important: true,
      );
      final at = DateTime(2026, 11, 28, 7);
      final (title, body) = PhoneReminders.reminderText(
        Occurrence(t, day),
        at,
        const Address(name: 'Bà', self: 'cháu'),
        'Sức khỏe',
      );
      expect(title, '⭐ Uống thuốc');
      expect(body, 'Bà ơi, đến giờ rồi ạ · Hôm nay lúc 07:00 · Sức khỏe');
      final (_, plain) = PhoneReminders.reminderText(
        Occurrence(t..remindBefore = 15, day),
        at,
        const Address(),
        'Sức khỏe',
      );
      expect(plain, 'Sắp đến giờ rồi · Hôm nay lúc 07:00 · Sức khỏe');
    });

    test('Trợ lý AI được báo cách xưng hô', () {
      final body = AiService.buildRequest(
        'x',
        now,
        cats,
        address: const Address(name: 'Cô Lan', self: 'em'),
      );
      expect(
        body['system'] as String,
        contains('gọi người dùng là "Cô Lan", tự xưng là "em"'),
      );
      expect(body['system'] as String, isNot(contains('mẹ')));
    });

    test('Lưu và đọc lại cách xưng hô', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      await store.updateSettings(
        (s) => s
          ..name = 'Bà'
          ..selfPronoun = 'cháu',
      );
      final again = AppStore(store.prefs);
      expect((again.settings.name, again.settings.selfPronoun), ('Bà', 'cháu'));
      expect(AppSettings().name, '');
    });
  });
}
