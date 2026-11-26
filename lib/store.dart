import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  List<Task> tasks=[];
  List<Alarm> alarms=[];
  Map<String,int> drinks={};
  Settings settings=Settings();
  AppStore(this.prefs) {
    final raw=prefs.getString('state');
    if(raw!=null) {
      final j=jsonDecode(raw) as Map<String,dynamic>;
      tasks=(j['tasks'] as List).map((x)=>Task.fromJson(Map<String,dynamic>.from(x))).toList();
      alarms=(j['alarms'] as List).map((x)=>Alarm.fromJson(Map<String,dynamic>.from(x))).toList();
      drinks=Map<String,int>.from(j['drinks']??{});
      settings=Settings.fromJson(Map<String,dynamic>.from(j['settings']??{}));
    }
  }
  Future<void> save() async {
    await prefs.setString('state',jsonEncode({'tasks':tasks.map((x)=>x.toJson()).toList(),'alarms':alarms.map((x)=>x.toJson()).toList(),'drinks':drinks,'settings':settings.toJson()}));
    notifyListeners();
  }
  List<Task> on(DateTime d) => tasks.where((t)=>t.occurs(d)).toList()..sort((a,b)=>a.at(d).compareTo(b.at(d)));
  int waterOn(DateTime d) => drinks[dayKey(d)]??0;
  Future<void> drink(int ml) async {
    final k=dayKey(DateTime.now());
    drinks[k]=((drinks[k]??0)+ml).clamp(0,20000);
    await save();
  }
  Future<void> mark(Task task, DateTime day, String status) async {
    task.records[dayKey(day)]=status;
    await save();
  }
  String summary(DateTime day) {
    final items=on(day), done=items.where((t)=>t.status(day)=='done').toList();
    final pending=items.where((t)=>t.status(day)=='pending').toList();
    final skipped=items.where((t)=>t.status(day)=='skipped').length;
    return 'Đã làm: ${done.length}/${items.length}${done.isEmpty?'': '\n${done.map((t)=>t.title).join(', ')}'}\nChưa xác nhận: ${pending.isEmpty?'Không có':pending.map((t)=>t.title).join(', ')}\nBỏ qua: $skipped\nĐã uống: ${waterOn(day)}/${settings.waterGoal} ml';
  }
}
