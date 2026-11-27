import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:nhac_viec/app.dart';
import 'package:nhac_viec/data/store.dart';
import 'package:nhac_viec/models/task.dart';
import 'package:nhac_viec/services/ai_service.dart';
import 'package:nhac_viec/services/notifications.dart';
import 'package:nhac_viec/services/speech.dart';
import 'package:nhac_viec/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services_test.dart' show MemoryVault;

Future<AppStore> pumpApp(WidgetTester tester, {bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance());
  store.onboarded = onboarded;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SoViecApp(
      store: store,
      reminders: NoReminders(),
      ai: AiService(
        vault: MemoryVault(),
        client: MockClient((_) async => throw StateError('offline')),
      ),
      voice: NoVoice(),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// Scrolls the visible list until [f] is built and visible, then taps it.
Future<void> tapIn(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      250,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Lần đầu mở: hỏi cách xưng hô rồi chào', (tester) async {
    final store = await pumpApp(tester, onboarded: false);
    expect(find.text('Chào mừng đến Sổ việc'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Bà Lan');
    await tapIn(tester, find.textContaining('Cháu (gọi ông bà'));
    // Live example in the dialog.
    expect(find.textContaining('Bà Lan ơi, cháu nhắc Bà Lan'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(store.onboarded, isTrue);
    expect(
      (store.settings.name, store.settings.selfPronoun),
      ('Bà Lan', 'cháu'),
    );
    expect(find.textContaining('Bà Lan!'), findsOneWidget);
    expect(find.text('Việc của Bà Lan'), findsOneWidget);
  });

  testWidgets('Không đặt tên thì chào trung tính, đổi được trong Cài đặt', (
    tester,
  ) async {
    final store = await pumpApp(tester, onboarded: false);
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(store.settings.name, '');
    expect(find.text('Sổ việc'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Chào buổi \S+!$')), findsOneWidget);

    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    await tapIn(tester, find.text('Ứng dụng gọi bạn là'));
    await tester.enterText(find.byType(TextField), 'anh Tuấn');
    await tapIn(tester, find.textContaining('Em (gọi anh chị'));
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(
      (store.settings.name, store.settings.selfPronoun),
      ('anh Tuấn', 'em'),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.textContaining(', Anh Tuấn!'), findsOneWidget);
  });

  testWidgets('Nhờ trợ lý tạo việc rồi đánh dấu xong', (tester) async {
    final store = await pumpApp(tester);
    expect(find.text('Nhờ trợ lý ghi việc'), findsOneWidget);
    await tester.tap(find.text('Nhờ trợ lý ghi việc'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Hôm nay 11 giờ tối uống thuốc huyết áp',
    );
    await tester.tap(find.text('Tạo việc'));
    await tester.pumpAndSettle();
    expect(find.text('Uống thuốc huyết áp'), findsOneWidget);
    await tapIn(tester, find.text('Lưu 1 việc'));
    await tester.pumpAndSettle();
    expect(store.tasks.single.categoryId, 'suc-khoe');

    // Task shows on today's list; tick it.
    final now = DateTime.now();
    if (store.tasks.single.occursOn(now)) {
      await tapIn(tester, find.byType(DoneButton));
      await tester.pumpAndSettle();
      expect(store.tasks.single.isDoneOn(now), isTrue);
    }
  });

  testWidgets('Thêm việc bằng tay', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Thêm việc'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Đi ăn cỗ nhà bác Hai',
    );
    await tapIn(tester, find.text('Hẹn & gặp gỡ'));
    await tapIn(tester, find.text('Mỗi tuần'));
    await tester.tap(find.text('Lưu việc'));
    await tester.pumpAndSettle();
    final t = store.tasks.single;
    expect(
      (t.title, t.categoryId, t.repeat),
      ('Đi ăn cỗ nhà bác Hai', 'hen-gap', Repeat.weekly),
    );
    expect(find.text('Đi ăn cỗ nhà bác Hai'), findsWidgets);
  });

  testWidgets('Lịch âm dương, nhóm việc và đổi giao diện', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Lịch'));
    await tester.pumpAndSettle();
    expect(find.text('Dương lịch'), findsOneWidget);
    await tester.tap(find.text('Âm lịch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dương lịch:'), findsOneWidget);
    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhóm việc').last);
    await tester.pumpAndSettle();
    expect(find.text('Giỗ, lễ & chùa'), findsOneWidget);

    final before = Theme.of(
      tester.element(find.text('Giỗ, lễ & chùa')),
    ).colorScheme.primary;
    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    await tapIn(tester, find.text('Trà xanh'));
    await tester.pumpAndSettle();
    expect(store.settings.preset, 'tra');
    final after = Theme.of(
      tester.element(find.text('Trà xanh')),
    ).colorScheme.primary;
    expect(after, isNot(before));
    await tapIn(tester, find.text('Tối'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Cài đặt'))).brightness,
      Brightness.dark,
    );
  });
}
