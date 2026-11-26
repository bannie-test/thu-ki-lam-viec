import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'store.dart';

class Reminders {
  final plugin=FlutterLocalNotificationsPlugin();
  final AppStore store;
  Future<void> Function(NotificationResponse)? onAction;
  Reminders(this.store);
  Future<void> init() async {
    tzdata.initializeTimeZones();
    // This personal app uses Vietnam's civil time, including lunar reminders.
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await plugin.initialize(const InitializationSettings(android:AndroidInitializationSettings('ic_stat_reminder')),
      onDidReceiveNotificationResponse:(r) async { await onAction?.call(r); });
  }
  Future<void> requestPermissions() async {
    final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }
  Future<NotificationResponse?> launchAction() async {
    final info=await plugin.getNotificationAppLaunchDetails();
    return info?.didNotificationLaunchApp==true ? info?.notificationResponse : null;
  }
  NotificationDetails details(String kind,{bool actions=true}) {
    final s=store.settings;
    return NotificationDetails(android:AndroidNotificationDetails(
      '${kind}_${s.sound}_${s.vibration}_v1',
      kind=='alarm'?'Báo thức':kind=='water'?'Uống nước':'Việc cần làm',
      channelDescription:'Nhắc việc cá nhân', importance:Importance.max, priority:Priority.high,
      playSound:s.sound, enableVibration:s.vibration,
      category:kind=='alarm'?AndroidNotificationCategory.alarm:AndroidNotificationCategory.reminder,
      sound:kind=='alarm'?const UriAndroidNotificationSound('content://settings/system/alarm_alert'):null,
      styleInformation:const BigTextStyleInformation(''),
      actions:!actions?null:[
        AndroidNotificationAction('done',kind=='water'?'Đã uống':kind=='alarm'?'Tắt':'Đã làm',showsUserInterface:true),
        const AndroidNotificationAction('snooze','10 phút nữa',showsUserInterface:true),
        const AndroidNotificationAction('skip','Bỏ qua',showsUserInterface:true),
      ],
    ));
  }
  int _id=1;
  Future<void> schedule(DateTime when,String title,String body,String kind,Map<String,dynamic> payload,{bool actions=true, DateTimeComponents? repeat}) async {
    if(!when.isAfter(DateTime.now())) return;
    final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact=await android?.canScheduleExactNotifications()??false;
    await plugin.zonedSchedule(_id++,title,body,tz.TZDateTime.from(when,tz.local),details(kind,actions:actions),
      androidScheduleMode:exact?AndroidScheduleMode.exactAllowWhileIdle:AndroidScheduleMode.inexactAllowWhileIdle,
      payload:jsonEncode({...payload,'kind':kind,'title':title,'body':body}), matchDateTimeComponents:repeat);
  }
  Future<void> rebuild() async {
    await plugin.cancelAll(); _id=1;
    final s=store.settings, now=DateTime.now();
    // Rolling horizon bounds vendor-specific pending-notification limits.
    // Refresh on app start/resume and every edit/action. Annual items get a next occurrence.
    for(final t in store.tasks) {
      if(!s.tasks) break;
      int count=0;
      final horizon=t.repeat.startsWith('Hằng năm')?2922:21;
      for(int n=0;n<horizon;n++) {
        final d=DateTime(now.year,now.month,now.day+n);
        if(!t.occurs(d)||t.status(d)!='pending') continue;
        final at=t.at(d);
        await schedule(at.subtract(Duration(minutes:t.early)),t.category,t.title,'task',{'task':t.id,'day':dayKey(d)});
        if(++count>= (horizon>21?1:21)) break;
      }
    }
    if(s.alarms) {
      for(final a in store.alarms.where((a)=>a.enabled)) {
        for(final weekday in a.weekdays) {
          var d=DateTime(now.year,now.month,now.day,a.hour,a.minute);
          while(d.weekday!=weekday||!d.isAfter(now)) { d=d.add(const Duration(days:1)); }
          await schedule(d,'Báo thức',a.label,'alarm',{'alarm':a.id},repeat:DateTimeComponents.dayOfWeekAndTime);
        }
      }
    }
    if(s.water) {
      for(int m=s.waterStart*60;m<=s.waterEnd*60;m+=s.waterEvery) {
        var d=DateTime(now.year,now.month,now.day,m~/60,m%60);
        if(!d.isAfter(now)) d=d.add(const Duration(days:1));
        await schedule(d,'Đến giờ uống nước','Uống từng ngụm, ghi nhận khi đã uống.','water',{'ml':s.cup},repeat:DateTimeComponents.time);
      }
    }
    for(int n=0;n<21;n++) {
      final day=DateTime(now.year,now.month,now.day+n);
      final pending=store.on(day).where((t)=>t.status(day)=='pending').toList();
      if(s.review&&s.tasks&&pending.isNotEmpty) {
        for(final time in s.reviewTimes.where((t)=>t.compareTo(s.reviewStop)<=0)) {
          final parts=time.split(':').map(int.parse).toList();
          final at=DateTime(day.year,day.month,day.day,parts[0],parts[1]);
          final due=pending.where((t)=>!t.at(day).isAfter(at)).toList();
          if(due.isEmpty) continue;
          await schedule(at,'Bạn đã làm những việc này chưa?',due.map((t)=>t.title).join('\n'),'review',{'day':dayKey(day)},actions:false);
        }
      }
      if(s.summary) {
        final p=s.summaryTime.split(':').map(int.parse).toList();
        await schedule(DateTime(day.year,day.month,day.day,p[0],p[1]),'Tổng kết ${dateLabel(day)}',store.summary(day),'summary',{'day':dayKey(day)},actions:false);
      }
    }
    await store.prefs.setString('scheduledAt',now.toIso8601String());
  }
  Future<void> handle(NotificationResponse response) async {
    if(response.payload==null) return;
    final p=jsonDecode(response.payload!) as Map<String,dynamic>;
    final action=response.actionId, kind=p['kind'] as String;
    if(action=='snooze') {
      _id=DateTime.now().millisecondsSinceEpoch%1000000000;
      await schedule(DateTime.now().add(const Duration(minutes:10)),p['title'],p['body'],kind,p);
      return;
    }
    if(action=='done'||action=='skip') {
      if(kind=='water'&&action=='done') await store.drink(p['ml'] as int);
      if(kind=='task') {
        final t=store.tasks.where((t)=>t.id==p['task']).firstOrNull;
        if(t!=null) { t.records[p['day']]=action=='done'?'done':'skipped'; await store.save(); }
      }
      // Dismiss only this alarm occurrence; retain its weekly repetition.
      if(response.id!=null) await plugin.cancel(response.id!);
      await rebuild();
    }
  }
}
