import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_viec/models.dart';
import 'package:nhac_viec/store.dart';

void main() {
  test('Vietnamese Tet 2026 and leap month conversion',(){
    expect(lunar(DateTime(2026,2,17)).take(3),[1,1,2026]);
    expect(lunar(DateTime(2023,3,23)),[2,2,2023,1]);
  });
  test('Daily completion belongs to one occurrence only',(){
    final t=Task(id:'1',title:'Thuốc',due:DateTime(2026,1,1,7),repeat:'Mỗi ngày');
    t.records[dayKey(DateTime(2026,1,2))]='done';
    expect(t.status(DateTime(2026,1,2)),'done');
    expect(t.status(DateTime(2026,1,3)),'pending');
    expect(t.occurs(DateTime(2025,12,31)),false);
    expect(t.occurs(DateTime(2026,1,3)),true);
  });
  test('Anniversary follows Vietnamese lunar date',(){
    final t=Task(id:'1',title:'Giỗ',due:DateTime(2025,1,29),repeat:'Hằng năm (âm)');
    expect(t.occurs(DateTime(2026,2,17)),true);
    expect(t.occurs(DateTime(2026,1,29)),false);
  });
  test('Leap lunar anniversary does not silently become ordinary month',(){
    final t=Task(id:'1',title:'Giỗ',due:DateTime(2023,3,23),repeat:'Hằng năm (âm)');
    expect(t.occurs(DateTime(2024,3,11)),false);
  });
  test('Draft parser keeps user text and extracts time for review',(){
    final t=parseDraft('Uống thuốc ngày mai lúc 7 giờ 15 mỗi ngày',DateTime(2026,11,26));
    expect(t.due,DateTime(2026,11,27,7,15));
    expect(t.category,'Uống thuốc'); expect(t.repeat,'Mỗi ngày');
    expect(parseDraft('Đi bộ lúc 6 giờ chiều',DateTime(2026,11,26)).due.hour,18);
  });
  test('Persistence retains task history and water by day',() async {
    SharedPreferences.setMockInitialValues({});
    final prefs=await SharedPreferences.getInstance(),store=AppStore(prefs);
    store.tasks.add(Task(id:'1',title:'Đọc',due:DateTime(2026,11,26)));
    await store.mark(store.tasks.first,DateTime(2026,11,26),'done');
    await store.drink(200); await store.drink(-500);
    final restored=AppStore(prefs);
    expect(restored.tasks.first.status(DateTime(2026,11,26)),'done');
    expect(restored.waterOn(DateTime.now()),0);
  });
}
