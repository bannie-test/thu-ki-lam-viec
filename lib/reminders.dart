import 'dart:convert';
import 'dart:typed_data';
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
      fullScreenIntent:kind=='alarm',
      ongoing:kind=='alarm',
      autoCancel:kind!='alarm',
      additionalFlags:kind=='alarm'?Int32List.fromList([4]):null,
      actions:!actions?null:[
        AndroidNotificationAction('done',kind=='water'?'Đã uống':kind=='alarm'?'Tắt':'Đã làm',showsUserInterface:true),
        const AndroidNotificationAction('snooze','10 phút nữa',showsUserInterface:true),
        const AndroidNotificationAction('skip','Bỏ qua',showsUserInterface:true),
      ],
    ));
  }
  int _id=1;
  List<Future<void> Function()>? _queue;
  List<DateTime>? _queueDates;
  Future<void> schedule(DateTime when,String title,String body,String kind,Map<String,dynamic> payload,{bool actions=true, DateTimeComponents? repeat}) async {
    if(!when.isAfter(DateTime.now())) return;
    if(_queue!=null) {
      _queueDates!.add(when);
      _queue!.add(()=>schedule(when,title,body,kind,payload,actions:actions,repeat:repeat));
      return;
    }
    final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact=await android?.canScheduleExactNotifications()??false;
    await plugin.zonedSchedule(_id++,title,body,tz.TZDateTime.from(when,tz.local),details(kind,actions:actions),
      androidScheduleMode:exact?AndroidScheduleMode.exactAllowWhileIdle:AndroidScheduleMode.inexactAllowWhileIdle,
      payload:jsonEncode({...payload,'kind':kind,'title':title,'body':body}), matchDateTimeComponents:repeat);
  }
  Future<void> rebuild() async {
    _queue=[]; _queueDates=[]; _id=1;
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
        final earlyAt=at.subtract(Duration(minutes:t.early));
        await schedule(earlyAt.isAfter(now)?earlyAt:at,t.category,t.title,'task',{'task':t.id,'day':dayKey(d)});
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
    final snoozes=(jsonDecode(store.prefs.getString('snoozes')??'[]') as List).cast<Map<String,dynamic>>();
    snoozes.removeWhere((p)=>!DateTime.parse(p['until']).isAfter(now));
    for(final p in snoozes) {
      final t=store.tasks.where((t)=>t.id==p['task']).firstOrNull;
      if(p['kind']=='task'&&(t==null||t.records[p['day']]=='done'||t.records[p['day']]=='skipped')) continue;
      await schedule(DateTime.parse(p['until']),p['title'],p['body'],p['kind'],p);
    }
    await store.prefs.setString('snoozes',jsonEncode(snoozes));
    final queue=_queue!, dates=_queueDates!;
    final order=List.generate(queue.length,(i)=>i)..sort((a,b)=>dates[a].compareTo(dates[b]));
    _queue=null; _queueDates=null;
    await plugin.cancelAll();
    // Keep below Samsung's 500-alarm limit; nearest reminders take priority.
    // The background worker replenishes this queue without needing to open the app.
    for(final i in order.take(400)) { await queue[i](); }
    await store.prefs.setString('scheduledAt',now.toIso8601String());
  }
  Future<void> handle(NotificationResponse response) async {
    if(response.payload==null) return;
    final p=jsonDecode(response.payload!) as Map<String,dynamic>;
    final action=response.actionId, kind=p['kind'] as String;
    if(action=='snooze') {
      final snoozes=jsonDecode(store.prefs.getString('snoozes')??'[]') as List;
      snoozes.removeWhere((x)=>x['kind']==kind&&x['task']==p['task']&&x['alarm']==p['alarm']);
      snoozes.add({...p,'until':DateTime.now().add(const Duration(minutes:10)).toIso8601String()});
      await store.prefs.setString('snoozes',jsonEncode(snoozes));
      await rebuild();
      return;
    }
    if(action=='done'||action=='skip') {
      final snoozes=jsonDecode(store.prefs.getString('snoozes')??'[]') as List;
      snoozes.removeWhere((x)=>x['kind']==kind&&x['task']==p['task']&&x['alarm']==p['alarm']);
      await store.prefs.setString('snoozes',jsonEncode(snoozes));
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
