import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vnlunar/vnlunar.dart';
import 'models.dart';
import 'store.dart';
import 'reminders.dart';
import 'ai.dart';

@pragma('vm:entry-point')
void refreshDispatcher() {
  Workmanager().executeTask((name,input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final prefs=await SharedPreferences.getInstance();
      await prefs.reload();
      final reminders=Reminders(AppStore(prefs));
      await reminders.init();
      await reminders.rebuild();
      return true;
    } catch(_) { return false; }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store=AppStore(await SharedPreferences.getInstance());
  final reminders=Reminders(store);
  await reminders.init();
  await Workmanager().initialize(refreshDispatcher);
  await Workmanager().registerPeriodicTask('nhac-viec-refresh','refresh-reminders',frequency:const Duration(hours:12));
  runApp(NhacViec(store:store,reminders:reminders));
}

IconData taskIcon(String c) => switch(c) {
  'Uống thuốc'=>Icons.medication_outlined,
  'Tập thể dục'=>Icons.directions_walk,
  'Làm giỗ'=>Icons.local_florist_outlined,
  'Mua sắm'=>Icons.shopping_cart_outlined,
  'Đi ăn cỗ'=>Icons.restaurant,
  'Chấm bài'=>Icons.rate_review_outlined,
  'Điểm danh trên ứng dụng'=>Icons.app_registration,
  _=>Icons.checklist,
};

class NhacViec extends StatefulWidget {
  final AppStore store;
  final Reminders reminders;
  const NhacViec({super.key,required this.store,required this.reminders});
  @override State<NhacViec> createState()=>_NhacViecState();
}
class _NhacViecState extends State<NhacViec> {
  @override Widget build(BuildContext context) => ListenableBuilder(listenable:widget.store,builder:(context,_) {
    final s=widget.store.settings;
    return MaterialApp(title:'Nhắc việc',debugShowCheckedModeBanner:false,
      locale:const Locale('vi'),supportedLocales:const [Locale('vi')],
      localizationsDelegates:GlobalMaterialLocalizations.delegates,
      theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:Color(s.color),brightness:Brightness.light),
        scaffoldBackgroundColor:Color(s.background),
        textTheme:ThemeData.light().textTheme.apply(fontFamily:'BeVietnamPro',bodyColor:const Color(0xff302634),displayColor:const Color(0xff302634),fontSizeFactor:s.textSize/14),
        filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(56,56))),
        outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(minimumSize:const Size(56,56))),
        inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(),filled:true,fillColor:Colors.white),
      ),home:Home(store:widget.store,reminders:widget.reminders));
  });
}

class Mascot extends StatelessWidget {
  final double size;
  const Mascot({super.key,this.size=90});
  @override Widget build(BuildContext context) => Semantics(label:'Bạn đồng hồ nhắc việc',child:SizedBox(width:size,height:size,child:CustomPaint(painter:_ClockPainter(Theme.of(context).colorScheme.primary))));
}
class _ClockPainter extends CustomPainter {
  final Color color;
  _ClockPainter(this.color);
  @override void paint(Canvas canvas,Size size) {
    final c=Offset(size.width/2,size.height/2),r=size.width*.33;
    final p=Paint()..color=color..strokeWidth=4..strokeCap=StrokeCap.round;
    canvas.drawLine(c+Offset(-r,-r*.7),c+Offset(-r*1.3,-r),p);
    canvas.drawLine(c+Offset(r,-r*.7),c+Offset(r*1.3,-r),p);
    canvas.drawLine(c+Offset(-r*.5,r*.8),c+Offset(-r*.7,r*1.3),p);
    canvas.drawLine(c+Offset(r*.5,r*.8),c+Offset(r*.7,r*1.3),p);
    canvas.drawCircle(c,r+4,p);
    canvas.drawCircle(c,r,Paint()..color=const Color(0xfffff1d6));
    canvas.drawCircle(c+Offset(-r*.32,-r*.1),2.5,p);
    canvas.drawCircle(c+Offset(r*.32,-r*.1),2.5,p);
    final path=Path()..moveTo(c.dx-r*.25,c.dy+r*.3)..quadraticBezierTo(c.dx,c.dy+r*.6,c.dx+r*.25,c.dy+r*.3);
    canvas.drawPath(path,p..style=PaintingStyle.stroke);
    canvas.drawOval(Rect.fromCenter(center:c+Offset(0,-r-9),width:r,height:12),Paint()..color=const Color(0xffc56530));
  }
  @override bool shouldRepaint(covariant _ClockPainter oldDelegate)=>color!=oldDelegate.color;
}

class Home extends StatefulWidget {
  final AppStore store; final Reminders reminders;
  const Home({super.key,required this.store,required this.reminders});
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab=0;
  DateTime selected=DateTime.now(),month=DateTime(DateTime.now().year,DateTime.now().month);
  bool lunarOnly=false,busy=false,refreshPending=false;
  AppStore get db=>widget.store;
  Reminders get reminders=>widget.reminders;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    reminders.onAction=(r) async { await reminders.handle(r); if(mounted) { setState(()=>tab=0); if(r.actionId==null||r.actionId!.isEmpty) showSummaryOrReview(r.payload); } };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final response=await reminders.launchAction();
      if(response!=null) await reminders.onAction?.call(response);
      await reschedule();
      if(!db.prefs.containsKey('onboarded')&&mounted) {
        await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Chào mừng đến Nhắc việc'),content:const Text('Cho phép thông báo và báo thức đúng giờ để nhận lời nhắc. App dùng giờ Việt Nam. Bạn có thể thay đổi màu, nền, cỡ chữ và khóa API trong nút bánh răng.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tiếp tục'))]));
        await reminders.requestPermissions(); await db.prefs.setBool('onboarded',true); await reschedule();
      }
    });
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if(state==AppLifecycleState.resumed) { setState((){}); reschedule(); } }
  void message(String text) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text))); }
  Future<void> reschedule() async { if(busy) { refreshPending=true; return; } busy=true; try { await reminders.rebuild(); } catch(_) { message('Chưa đặt được một số lời nhắc. Kiểm tra quyền thông báo/báo thức trong Cài đặt.'); } finally { busy=false; if(refreshPending) { refreshPending=false; await reschedule(); } } }
  Future<void> persist() async { await db.save(); await reschedule(); if(mounted) setState((){}); }
  Future<void> showSummaryOrReview(String? payload) async {
    // Full details use live local data for the date carried by the notification.
    var date=DateTime.now();
    if(payload!=null) {
      final p=jsonDecode(payload) as Map<String,dynamic>;
      if(p['kind']=='alarm') {
        await showDialog<void>(context:context,barrierDismissible:false,builder:(c)=>AlertDialog(title:const Text('Đến giờ rồi!'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Mascot(size:120),Text(p['body']??'Báo thức')]),actions:[
          TextButton(onPressed:() async { Navigator.pop(c); await reminders.handle(NotificationResponse(notificationResponseType:NotificationResponseType.selectedNotificationAction,actionId:'snooze',payload:payload)); },child:const Text('10 phút nữa')),
          FilledButton(onPressed:() async { Navigator.pop(c); await reminders.handle(NotificationResponse(notificationResponseType:NotificationResponseType.selectedNotificationAction,actionId:'done',payload:payload)); },child:const Text('Tắt báo thức')),
        ]));
        return;
      }
      if(p['day']!=null) { final parts=(p['day'] as String).split('-').map(int.parse).toList(); date=DateTime(parts[0],parts[1],parts[2]); }
    }
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('Công việc ${dateLabel(date)}'),content:SingleChildScrollView(child:Text(db.summary(date))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
  }
  @override Widget build(BuildContext context) {
    final image=db.settings.image;
    return Scaffold(appBar:AppBar(title:const Text('Nhắc việc'),actions:[IconButton(tooltip:'Cài đặt',icon:const Icon(Icons.settings_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>SettingsPage(store:db,reminders:reminders))).then((_)=>reschedule()))]),
      body:Stack(children:[
        if(image.isNotEmpty&&File(image).existsSync()) Positioned.fill(child:Opacity(opacity:db.settings.opacity,child:Image.file(File(image),fit:BoxFit.cover))),
        SafeArea(child:ListenableBuilder(listenable:db,builder:(c,_)=>switch(tab){0=>today(),1=>calendar(),2=>alarms(),_=>water()})),
      ]),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.checklist),label:'Hôm nay'),NavigationDestination(icon:Icon(Icons.calendar_month),label:'Lịch'),NavigationDestination(icon:Icon(Icons.alarm),label:'Báo thức'),NavigationDestination(icon:Icon(Icons.water_drop_outlined),label:'Uống nước')]));
  }
  Widget panel(Widget child)=>Card(color:Colors.white.withValues(alpha:.96),child:Padding(padding:const EdgeInsets.all(16),child:child));
  Widget today() {
    final now=DateTime.now(),list=db.on(DateTime.now());
    return ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[const Mascot(),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Chào bạn!',style:Theme.of(context).textTheme.headlineSmall),Text(dateLabel(now)),Text('Đã làm ${list.where((t)=>t.status(now)=='done').length}/${list.length} việc')]))]),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:voiceDraft,icon:const Icon(Icons.mic),label:const Text('Nói để thêm việc')),
      const SizedBox(height:8),FilledButton.icon(onPressed:()=>editTask(),icon:const Icon(Icons.add),label:const Text('Thêm công việc')),
      const SizedBox(height:16),if(list.isEmpty) panel(const Text('Hôm nay chưa có công việc. Thêm một việc nhỏ để bắt đầu.')),
      ...list.map((t)=>taskTile(t,now)),
      OutlinedButton.icon(onPressed:()=>showSummaryOrReview(null),icon:const Icon(Icons.summarize_outlined),label:const Text('Xem tổng kết hôm nay')),
    ]);
  }
  Widget taskTile(Task t,DateTime day) {
    final status=t.status(day);
    return panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(taskIcon(t.category),size:30),const SizedBox(width:10),Expanded(child:Text(t.title,style:TextStyle(fontWeight:FontWeight.w600,decoration:status=='done'?TextDecoration.lineThrough:null))),PopupMenuButton<String>(tooltip:'Tùy chọn công việc',onSelected:(v) async { if(v=='edit') { editTask(existing:t); } else if(v=='delete') { final ok=await confirm('Xóa công việc này và các lần lặp?'); if(ok) { db.tasks.remove(t); await persist(); } } else { await db.mark(t,day,v); await reschedule(); } },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Chỉnh sửa')),PopupMenuItem(value:'pending',child:Text('Đặt lại chưa làm')),PopupMenuItem(value:'skipped',child:Text('Bỏ qua hôm nay')),PopupMenuItem(value:'delete',child:Text('Xóa công việc'))])]),
      Text('${clock(t.at(day))} · ${t.category}'),if(t.note.isNotEmpty) Text(t.note),
      CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:Text(status=='done'?'Đã làm':status=='skipped'?'Đã bỏ qua':'Xác nhận đã làm'),value:status=='done',onChanged:(v) async { await db.mark(t,day,v==true?'done':'pending'); await reschedule(); }),
    ]));
  }
  Future<bool> confirm(String title) async => await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Đồng ý'))]))??false;

  Widget calendar() {
    var days=<DateTime>[];
    String header;
    if(lunarOnly) {
      final anchor=lunar(selected); var first=DateTime(selected.year,selected.month,selected.day);
      while(lunar(first)[0]!=1) { first=first.subtract(const Duration(days:1)); }
      var d=first;
      do { days.add(d); d=d.add(const Duration(days:1)); } while(lunar(d)[0]!=1&&days.length<31);
      header='Tháng ${anchor[1]}${anchor[3]==1?' nhuận':''}, ${anchor[2]} (âm)';
    } else {
      final count=DateTime(month.year,month.month+1,0).day;
      days=List.generate(count,(i)=>DateTime(month.year,month.month,i+1));
      header='Tháng ${month.month}, ${month.year}';
    }
    final offset=days.first.weekday-1,list=db.on(selected);
    return ListView(padding:const EdgeInsets.all(12),children:[
      SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Lịch dương')),ButtonSegment(value:true,label:Text('Lịch âm'))],selected:{lunarOnly},onSelectionChanged:(v)=>setState(()=>lunarOnly=v.first)),
      Row(children:[IconButton(tooltip:'Tháng trước',onPressed:()=>moveMonth(-1,days),icon:const Icon(Icons.chevron_left)),Expanded(child:Text(header,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(tooltip:'Tháng sau',onPressed:()=>moveMonth(1,days),icon:const Icon(Icons.chevron_right))]),
      const Row(children:[Expanded(child:Center(child:Text('T2'))),Expanded(child:Center(child:Text('T3'))),Expanded(child:Center(child:Text('T4'))),Expanded(child:Center(child:Text('T5'))),Expanded(child:Center(child:Text('T6'))),Expanded(child:Center(child:Text('T7'))),Expanded(child:Center(child:Text('CN')))]),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:offset+days.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:.65),itemBuilder:(c,i){
        if(i<offset) return const SizedBox.shrink();
        final d=days[i-offset],l=lunar(d),active=sameDay(d,selected);
        final color=active?Colors.white:Theme.of(context).colorScheme.primary;
        return Semantics(label:'${dateLabel(d)}, âm lịch ${l[0]}/${l[1]}',button:true,child:InkWell(onTap:()=>setState(()=>selected=d),child:Container(margin:const EdgeInsets.all(2),decoration:BoxDecoration(color:active?Theme.of(context).colorScheme.primary:Colors.white.withValues(alpha:.9),borderRadius:BorderRadius.circular(12)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('${lunarOnly?l[0]:d.day}',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:color)),if(!lunarOnly) Text('${l[0]}${l[0]==1?'/${l[1]}':''}',style:TextStyle(fontSize:14,color:color)),if(db.on(d).isNotEmpty) Icon(Icons.circle,size:6,color:color)]))));
      }),
      TextButton(onPressed:()=>setState(() { selected=DateTime.now(); month=DateTime(selected.year,selected.month); }),child:const Text('Về hôm nay')),
      Text('Ngày ${dateLabel(selected)}',style:Theme.of(context).textTheme.titleLarge),
      if(list.isEmpty) panel(const Text('Chưa có việc trong ngày này.')),...list.map((t)=>taskTile(t,selected)),
      FilledButton.icon(onPressed:()=>editTask(initial:Task(id:DateTime.now().microsecondsSinceEpoch.toString(),title:'',due:DateTime(selected.year,selected.month,selected.day,9))),icon:const Icon(Icons.add),label:const Text('Thêm việc vào ngày này')),
    ]);
  }
  void moveMonth(int step,List<DateTime> days) { setState(() { if(lunarOnly) { selected=step>0?days.last.add(const Duration(days:1)):days.first.subtract(const Duration(days:1)); month=DateTime(selected.year,selected.month); } else { month=DateTime(month.year,month.month+step); selected=month; } }); }

  Future<void> voiceDraft() async {
    final text=TextEditingController();
    final speech=SpeechToText(); bool listening=false,working=false;
    try {
      if(!mounted) return;
      await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:const Text('Nói hoặc nhập yêu cầu'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('Ví dụ: Nhắc tôi uống thuốc lúc 7 giờ mỗi ngày. Bạn được sửa văn bản trước khi gửi AI.'),const SizedBox(height:12),
        TextField(controller:text,maxLines:5,decoration:const InputDecoration(labelText:'Nội dung bạn muốn tạo')),
        const SizedBox(height:12),OutlinedButton.icon(onPressed:working?null:() async {
          if(listening) { await speech.stop(); update(()=>listening=false); return; }
          final available=await speech.initialize(onError:(_){ if(dialogContext.mounted) update(()=>listening=false); },onStatus:(status){ if(status=='done'||status=='notListening') { if(dialogContext.mounted) update(()=>listening=false); } });
          if(!available) { message('Không nhận dạng được giọng nói. Kiểm tra quyền mic và dịch vụ giọng nói của máy.'); return; }
          if(!dialogContext.mounted) return;
          update(()=>listening=true);
          await speech.listen(localeId:'vi_VN',onResult:(r){ if(dialogContext.mounted) update(()=>text.text=r.recognizedWords); });
        },icon:Icon(listening?Icons.stop:Icons.mic),label:Text(listening?'Dừng ghi âm':'Bắt đầu nói')),
        if(working) const Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator()),
        if(db.settings.ai) const Text('Gửi AI chỉ gửi văn bản ở trên và thời gian hiện tại. Không gửi danh sách việc hay thông tin sức khỏe.'),
      ])),actions:[
        TextButton(onPressed:working?null:()=>Navigator.pop(c),child:const Text('Hủy')),
        FilledButton(onPressed:working?null:() async {
          if(text.text.trim().isEmpty) return;
          await speech.stop(); update(()=>working=true);
          try {
            final draft=db.settings.ai?await AiService.draft(text.text,db.settings.model):parseDraft(text.text,DateTime.now());
            if(!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            await editTask(initial:draft);
          } catch(e) { message(e.toString()); if(dialogContext.mounted) update(()=>working=false); }
        },child:Text(db.settings.ai?'Gửi AI':'Tạo bản nháp')),
      ])));
    } finally { await speech.stop(); text.dispose(); }
  }

  Future<void> editTask({Task? existing,Task? initial}) async {
    final original=existing??initial??Task(id:DateTime.now().microsecondsSinceEpoch.toString(),title:'',due:DateTime.now().add(const Duration(hours:1)));
    final title=TextEditingController(text:original.title),note=TextEditingController(text:original.note);
    var due=original.due,category=original.category,repeat=original.repeat,early=original.early;
    bool useLunar=false;
    await showDialog<void>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:Text(existing==null?'Tạo công việc':'Sửa công việc'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'Tên công việc')),const SizedBox(height:12),
      DropdownButtonFormField<String>(initialValue:category,isExpanded:true,decoration:const InputDecoration(labelText:'Biểu tượng / loại việc'),items:categories.map((x)=>DropdownMenuItem(value:x,child:Row(children:[Icon(taskIcon(x)),const SizedBox(width:8),Flexible(child:Text(x))]))).toList(),onChanged:(v)=>update(()=>category=v!)),
      SwitchListTile(title:const Text('Chọn ngày theo lịch âm'),value:useLunar,onChanged:(v)=>update(()=>useLunar=v)),
      OutlinedButton.icon(onPressed:() async {
        DateTime? d;
        if(useLunar) { d=await pickLunar(due); } else { d=await showDatePicker(context:c,initialDate:due,firstDate:DateTime(2020),lastDate:DateTime(2199)); }
        if(d!=null) { final picked=d; update(()=>due=DateTime(picked.year,picked.month,picked.day,due.hour,due.minute)); }
      },icon:const Icon(Icons.calendar_month),label:Text('Ngày dương: ${dateLabel(due)}')),
      Builder(builder:(_){ final l=lunar(due); return Text('Âm: ${l[0]}/${l[1]}/${l[2]}${l[3]==1?' (nhuận)':''}'); }),
      OutlinedButton.icon(onPressed:() async { final t=await showTimePicker(context:c,initialTime:TimeOfDay.fromDateTime(due)); if(t!=null) update(()=>due=DateTime(due.year,due.month,due.day,t.hour,t.minute)); },icon:const Icon(Icons.schedule),label:Text('Giờ: ${clock(due)}')),
      const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:repeat,isExpanded:true,decoration:const InputDecoration(labelText:'Lặp lại'),items:repeats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>update(()=>repeat=v!)),
      const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:early,decoration:const InputDecoration(labelText:'Nhắc trước'),items:[0,5,10,15,30,60].map((x)=>DropdownMenuItem(value:x,child:Text('$x phút'))).toList(),onChanged:(v)=>update(()=>early=v!)),
      const SizedBox(height:12),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Ghi chú')),
      if(repeat=='Hằng năm (âm)') const Text('Ngày 30 chỉ nhắc ở năm có ngày đó. Ngày thuộc tháng nhuận chỉ nhắc khi tháng nhuận tương ứng tồn tại.'),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Hủy')),FilledButton(onPressed:() async {
      if(title.text.trim().isEmpty) { message('Hãy nhập tên công việc.'); return; }
      if(repeat=='Không lặp'&&!due.isAfter(DateTime.now())) { message('Hãy chọn thời gian trong tương lai.'); return; }
      final t=Task(id:original.id,title:title.text.trim(),due:due,category:category,repeat:repeat,early:early,note:note.text,records:Map.from(original.records));
      final index=db.tasks.indexWhere((x)=>x.id==t.id); if(index<0) { db.tasks.add(t); } else { db.tasks[index]=t; }
      Navigator.pop(c); await persist();
    },child:const Text('Lưu công việc'))])));
    title.dispose(); note.dispose();
  }
  Future<DateTime?> pickLunar(DateTime initial) async {
    final l=lunar(initial),day=TextEditingController(text:'${l[0]}'),month=TextEditingController(text:'${l[1]}'),year=TextEditingController(text:'${l[2]}');
    bool leap=l[3]==1; String? error;
    final result=await showDialog<DateTime>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:const Text('Chọn ngày âm'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:day,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Ngày âm')),TextField(controller:month,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Tháng âm')),TextField(controller:year,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Năm âm')),SwitchListTile(title:const Text('Tháng nhuận'),value:leap,onChanged:(v)=>update(()=>leap=v)),if(error!=null) Text(error!,style:const TextStyle(color:Colors.red))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Hủy')),FilledButton(onPressed:(){ try { final y=int.parse(year.text),m=int.parse(month.text),d=int.parse(day.text); if(y<2020||y>2198) throw ArgumentError(); final s=convertLunar2Solar(d,m,y,leap,7); final result=DateTime(s[2],s[1],s[0]); final back=lunar(result); if(back[0]!=d||back[1]!=m||back[2]!=y||back[3]!=(leap?1:0)) throw ArgumentError(); Navigator.pop(c,result); } catch(_) { update(()=>error='Ngày âm không tồn tại. Kiểm tra ngày, tháng, năm và tháng nhuận.'); } },child:const Text('Chọn'))])));
    day.dispose(); month.dispose(); year.dispose(); return result;
  }

  Widget alarms()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Báo thức',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold)),const Text('Chạm vào giờ để chỉnh sửa. Âm báo phụ thuộc cài đặt thông báo của điện thoại.'),...db.alarms.map((a)=>panel(Column(children:[SwitchListTile(title:Text('${two(a.hour)}:${two(a.minute)}',style:const TextStyle(fontSize:36,fontWeight:FontWeight.bold)),subtitle:Text('${a.label}\n${a.weekdays.map((d)=>d==7?'CN':'T${d+1}').join(' · ')}'),value:a.enabled,onChanged:(v) async { a.enabled=v; await persist(); }),Row(children:[TextButton.icon(onPressed:()=>editAlarm(a),icon:const Icon(Icons.edit),label:const Text('Sửa')),TextButton.icon(onPressed:() async { if(await confirm('Xóa báo thức này?')) { db.alarms.remove(a); await persist(); } },icon:const Icon(Icons.delete_outline),label:const Text('Xóa'))])]))),FilledButton.icon(onPressed:()=>editAlarm(null),icon:const Icon(Icons.add_alarm),label:const Text('Thêm báo thức'))]);
  Future<void> editAlarm(Alarm? alarm) async {
    var t=TimeOfDay(hour:alarm?.hour??6,minute:alarm?.minute??30);
    final label=TextEditingController(text:alarm?.label??'Thức dậy'); final days={...alarm?.weekdays??[1,2,3,4,5,6,7]};
    await showDialog<void>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:const Text('Báo thức'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:label,decoration:const InputDecoration(labelText:'Tên báo thức')),OutlinedButton(onPressed:() async { final next=await showTimePicker(context:c,initialTime:t); if(next!=null) update(()=>t=next); },child:Text(t.format(c),style:const TextStyle(fontSize:32))),Wrap(spacing:6,children:List.generate(7,(i)=>FilterChip(label:Text(i==6?'CN':'T${i+2}'),selected:days.contains(i+1),onSelected:(v)=>update(() { if(v) { days.add(i+1); } else { days.remove(i+1); } })))),const Text('Báo thức lặp vào những ngày được chọn.') ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Hủy')),FilledButton(onPressed:() async { if(days.isEmpty) { message('Chọn ít nhất một ngày.'); return; } final a=Alarm(id:alarm?.id??DateTime.now().microsecondsSinceEpoch.toString(),label:label.text.trim().isEmpty?'Báo thức':label.text.trim(),hour:t.hour,minute:t.minute,weekdays:days.toList()..sort()); final index=db.alarms.indexWhere((x)=>x.id==a.id); if(index<0) { db.alarms.add(a); } else { db.alarms[index]=a; } Navigator.pop(c); await persist(); },child:const Text('Lưu'))]))); label.dispose();
  }

  Widget water() {
    final s=db.settings,total=db.waterOn(DateTime.now());
    return ListView(padding:const EdgeInsets.all(16),children:[const Center(child:Mascot(size:120)),Text('Uống nước',style:Theme.of(context).textTheme.headlineMedium),panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Đã uống $total ml',style:const TextStyle(fontSize:30,fontWeight:FontWeight.bold)),Text('Mục tiêu ${s.waterGoal} ml'),const SizedBox(height:12),LinearProgressIndicator(value:(total/s.waterGoal).clamp(0,1),minHeight:18),const SizedBox(height:12),FilledButton.icon(onPressed:() async { await db.drink(s.cup); await reschedule(); },icon:const Icon(Icons.add),label:Text('Đã uống ${s.cup} ml')),const SizedBox(height:8),OutlinedButton(onPressed:()=>customDrink(),child:const Text('Nhập lượng khác')),TextButton(onPressed:() async { await db.drink(-s.cup); await reschedule(); },child:const Text('Trừ một cốc vừa ghi'))])),Text('Nhắc từ ${s.waterStart}:00 đến ${s.waterEnd}:00, mỗi ${s.waterEvery} phút.'),OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>SettingsPage(store:db,reminders:reminders,initialSection:2))).then((_)=>reschedule()),icon:const Icon(Icons.settings_outlined),label:const Text('Thiết lập mục tiêu và giờ nhắc')),const Text('Ghi nhận nước và đồ uống thực tế. Mục tiêu tham khảo không thay thế hướng dẫn của bác sĩ; không cần cố uống bù dồn vào cuối ngày.')]);
  }
  Future<void> customDrink() async { final c=TextEditingController(); await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Lượng vừa uống'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'ml')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),FilledButton(onPressed:() async { final n=int.tryParse(c.text); if(n==null||n<1||n>2000) { message('Nhập từ 1 đến 2.000 ml.'); return; } Navigator.pop(ctx); await db.drink(n); await reschedule(); },child:const Text('Ghi nhận'))])); c.dispose(); }
}

class SettingsPage extends StatefulWidget {
  final AppStore store; final Reminders reminders; final int initialSection;
  const SettingsPage({super.key,required this.store,required this.reminders,this.initialSection=0});
  @override State<SettingsPage> createState()=>_SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  late final Settings s; late final TextEditingController key,model;
  bool reveal=false,testing=false,hasKey=false;
  Timer? refresh;
  @override void initState() { super.initState(); s=widget.store.settings; key=TextEditingController(); model=TextEditingController(text:s.model); secure.containsKey(key:'openai_key').then((v){ if(mounted) setState(()=>hasKey=v); }); }
  @override void dispose() { refresh?.cancel(); key.dispose(); model.dispose(); super.dispose(); }
  void message(String t) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t))); }
  Future<void> save() async {
    await widget.store.save();
    refresh?.cancel();
    refresh=Timer(const Duration(milliseconds:500),() async {
      try { await widget.reminders.rebuild(); }
      catch(_) { if(mounted) message('Chưa cập nhật được lời nhắc. Hãy kiểm tra quyền thông báo.'); }
    });
    if(mounted) setState((){});
  }
  Future<void> numeric(String title,num initial,void Function(double) apply,{double min=1,double max=10000}) async {
    final c=TextEditingController(text:'$initial');
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),FilledButton(onPressed:() async { final n=double.tryParse(c.text.replaceAll(',','.')); if(n==null||n<min||n>max) { message('Nhập giá trị từ $min đến $max.'); return; } apply(n); Navigator.pop(ctx); await save(); },child:const Text('Lưu'))])); c.dispose();
  }
  Future<String?> time(String value) async { final p=value.split(':').map(int.parse).toList(); final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:p[0],minute:p[1])); return t==null?null:'${two(t.hour)}:${two(t.minute)}'; }
  Widget toggle(String name,bool value,void Function(bool) change)=>SwitchListTile(title:Text(name),value:value,onChanged:(v) async { change(v); await save(); });
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Cài đặt')),body:ListView(padding:const EdgeInsets.all(12),children:[
    ExpansionTile(initiallyExpanded:widget.initialSection==0,title:const Text('AI và giọng nói'),leading:const Icon(Icons.mic_outlined),children:[
      const Padding(padding:EdgeInsets.all(12),child:Text('Khóa OpenAI API riêng; gói ChatGPT Free không cung cấp API miễn phí. Khóa chỉ được gửi đến OpenAI khi bạn bấm Gửi AI. Không chia sẻ khóa với người khác.')),
      toggle('Dùng AI để tạo bản nháp',s.ai,(v)=>s.ai=v),
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:key,obscureText:!reveal,enableSuggestions:false,autocorrect:false,decoration:InputDecoration(labelText:hasKey?'Đã có khóa · nhập để thay':'Khóa OpenAI API',suffixIcon:IconButton(tooltip:reveal?'Ẩn khóa':'Hiện nội dung vừa nhập',onPressed:()=>setState(()=>reveal=!reveal),icon:Icon(reveal?Icons.visibility_off:Icons.visibility))))),
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:model,decoration:const InputDecoration(labelText:'Model API (có thể sửa)'),onChanged:(v){ s.model=v.trim(); save(); })),
      Wrap(spacing:8,children:[FilledButton(onPressed:() async { if(!key.text.trim().startsWith('sk-')) { message('Kiểm tra khóa API bắt đầu bằng sk-.'); return; } await secure.write(key:'openai_key',value:key.text.trim()); key.clear(); setState(()=>hasKey=true); message('Đã lưu khóa trong vùng bảo mật.'); },child:const Text('Lưu khóa')),TextButton(onPressed:() async { await secure.delete(key:'openai_key'); key.clear(); s.ai=false; setState(()=>hasKey=false); await save(); },child:const Text('Xóa khóa'))]),
      OutlinedButton(onPressed:testing||!hasKey?null:() async { final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Kiểm tra kết nối API?'),content:const Text('Gửi câu mẫu “Đọc sách ngày mai lúc 9 giờ” đến OpenAI. Có thể phát sinh phí API.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Gửi câu mẫu'))])); if(ok!=true) return; setState(()=>testing=true); try { await AiService.draft('Đọc sách ngày mai lúc 9 giờ',s.model); message('Kết nối thành công.'); } catch(e) { message(e.toString()); } finally { if(mounted) setState(()=>testing=false); } },child:Text(testing?'Đang kiểm tra…':'Kiểm tra kết nối')),
    ]),
    ExpansionTile(title:const Text('Giao diện'),leading:const Icon(Icons.palette_outlined),children:[
      const Text('Màu chủ đạo'),Wrap(spacing:10,children:[0xff623b67,0xff244a78,0xff305b42,0xff854126,0xff3f4147].map((n)=>IconButton(tooltip:'Chọn màu ${n.toRadixString(16)}',onPressed:() async { s.color=n; await save(); },icon:Icon(s.color==n?Icons.check_circle:Icons.circle,color:Color(n),size:44))).toList()),
      ListTile(title:const Text('Màu tùy chỉnh (HEX)'),trailing:const Icon(Icons.edit),onTap:customColor),
      const Text('Màu nền'),Wrap(spacing:10,children:[0xfffff9f0,0xffffffff,0xffeee5f2,0xffeef3ed,0xffedf1f7].map((n)=>OutlinedButton(onPressed:() async { s.background=n; await save(); },child:Icon(Icons.circle,color:Color(n),size:30))).toList()),
      OutlinedButton.icon(onPressed:() async { try { final f=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1600,imageQuality:85); if(f==null) return; final dir=await getApplicationDocumentsDirectory(); final target=await File(f.path).copy('${dir.path}/background_${DateTime.now().millisecondsSinceEpoch}.jpg'); final old=s.image; s.image=target.path; await save(); if(old.isNotEmpty&&File(old).existsSync()) await File(old).delete(); } catch(_) { message('Không chọn được ảnh. Hãy thử ảnh khác.'); } },icon:const Icon(Icons.image_outlined),label:const Text('Chọn ảnh nền')),
      TextButton(onPressed:() async { final old=s.image; s.image=''; await save(); if(old.isNotEmpty&&File(old).existsSync()) await File(old).delete(); },child:const Text('Bỏ ảnh nền')),
      const Text('Độ hiện của ảnh nền'),Slider(value:s.opacity,min:0,max:.3,divisions:10,label:'${(s.opacity*100).round()}%',onChanged:(v){ setState(()=>s.opacity=v); },onChangeEnd:(_)=>save()),
      ListTile(title:const Text('Cỡ chữ'),subtitle:Text('${s.textSize}'),onTap:()=>numeric('Cỡ chữ',s.textSize,(v)=>s.textSize=v.round(),min:18,max:26)),
      const Text('Xem trước'),Card(child:ListTile(leading:Icon(Icons.medication_outlined,color:Color(s.color)),title:const Text('Uống thuốc'),subtitle:const Text('07:00 · Mỗi ngày'))),
      TextButton(onPressed:() async { s.color=0xff623b67; s.background=0xfffff9f0; s.textSize=20; s.opacity=.12; s.image=''; await save(); },child:const Text('Khôi phục giao diện mặc định')),
    ]),
    ExpansionTile(initiallyExpanded:widget.initialSection==2,title:const Text('Uống nước'),leading:const Icon(Icons.water_drop_outlined),children:[
      ListTile(title:const Text('Cân nặng'),subtitle:Text('${s.weight} kg'),onTap:()=>numeric('Cân nặng (kg)',s.weight,(v)=>s.weight=v,min:20,max:300)),
      ListTile(title:const Text('Chiều cao'),subtitle:Text('${s.height} cm'),onTap:()=>numeric('Chiều cao (cm)',s.height,(v)=>s.height=v,min:80,max:250)),
      toggle('Có mức dịch riêng theo bác sĩ',s.customFluid,(v)=>s.customFluid=v),
      const Padding(padding:EdgeInsets.all(12),child:Text('Cân nặng và chiều cao không đủ để tính chính xác lượng nước cần uống. Nếu có mức riêng theo bác sĩ, nhập đúng mức đó. Mức tham khảo cần được bạn xác nhận; không dùng công thức tổng dịch làm chỉ tiêu nước lọc.')),
      if(!s.customFluid) OutlinedButton(onPressed:()=>numeric('Xác nhận mục tiêu tham khảo (ml/ngày)',1600,(v)=>s.waterGoal=v.round(),min:200,max:5000),child:const Text('Dùng mức tham khảo 1.600 ml')),
      ListTile(title:const Text('Mục tiêu mỗi ngày'),subtitle:Text('${s.waterGoal} ml'),onTap:()=>numeric('Mục tiêu (ml/ngày)',s.waterGoal,(v)=>s.waterGoal=v.round(),min:200,max:5000)),
      ListTile(title:const Text('Dung tích một cốc'),subtitle:Text('${s.cup} ml'),onTap:()=>numeric('Dung tích cốc (ml)',s.cup,(v)=>s.cup=v.round(),min:50,max:1000)),
      ListTile(title:const Text('Bắt đầu nhắc từ giờ'),subtitle:Text('${s.waterStart}:00'),onTap:()=>numeric('Giờ bắt đầu',s.waterStart,(v)=>s.waterStart=v.round(),min:0,max:(s.waterEnd-1).toDouble())),
      ListTile(title:const Text('Kết thúc nhắc lúc'),subtitle:Text('${s.waterEnd}:00'),onTap:()=>numeric('Giờ kết thúc',s.waterEnd,(v)=>s.waterEnd=v.round(),min:(s.waterStart+1).toDouble(),max:23)),
      ListTile(title:const Text('Khoảng cách giữa lời nhắc'),subtitle:Text('${s.waterEvery} phút'),onTap:()=>numeric('Khoảng cách (phút)',s.waterEvery,(v)=>s.waterEvery=v.round(),min:60,max:360)),
    ]),
    ExpansionTile(title:const Text('Thông báo'),leading:const Icon(Icons.notifications_outlined),children:[
      toggle('Việc cần làm',s.tasks,(v)=>s.tasks=v),toggle('Báo thức',s.alarms,(v)=>s.alarms=v),toggle('Uống nước',s.water,(v)=>s.water=v),toggle('Âm thanh',s.sound,(v)=>s.sound=v),toggle('Rung',s.vibration,(v)=>s.vibration=v),
      toggle('Hỏi lại công việc chưa xác nhận',s.review,(v)=>s.review=v),
      ...s.reviewTimes.asMap().entries.map((e)=>ListTile(title:Text('Hỏi lại lúc ${e.value}'),onTap:() async { final t=await time(e.value); if(t!=null) { s.reviewTimes[e.key]=t; await save(); } },trailing:IconButton(tooltip:'Bỏ mốc hỏi lại',onPressed:() async { s.reviewTimes.removeAt(e.key); await save(); },icon:const Icon(Icons.delete_outline)))),
      TextButton(onPressed:() async { if(s.reviewTimes.length>=4) { message('Tối đa 4 mốc hỏi lại mỗi ngày.'); return; } final t=await time('12:00'); if(t!=null&&!s.reviewTimes.contains(t)) { s.reviewTimes.add(t); s.reviewTimes.sort(); await save(); } },child:const Text('Thêm mốc hỏi lại')),
      ListTile(title:const Text('Ngừng hỏi lại từ'),subtitle:Text(s.reviewStop),onTap:() async { final t=await time(s.reviewStop); if(t!=null) { s.reviewStop=t; await save(); } }),
      toggle('Tổng kết cuối ngày',s.summary,(v)=>s.summary=v),ListTile(title:const Text('Giờ tổng kết'),subtitle:Text(s.summaryTime),onTap:() async { final t=await time(s.summaryTime); if(t!=null) { s.summaryTime=t; await save(); } }),
      OutlinedButton(onPressed:widget.reminders.requestPermissions,child:const Text('Cấp quyền thông báo / đúng giờ')),
      OutlinedButton(onPressed:() async { await widget.reminders.plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestFullScreenIntentPermission(); },child:const Text('Cho phép báo thức toàn màn hình')),
      OutlinedButton(onPressed:() async { await widget.reminders.plugin.show(999999,'Nhắc việc','Thông báo thử. Nếu không thấy banner, kiểm tra cài đặt thông báo của điện thoại.',widget.reminders.details('task',actions:false)); },child:const Text('Thử thông báo')),
      const Padding(padding:EdgeInsets.all(12),child:Text('Nhắc việc và tổng kết được lên lịch trước tối đa 21 ngày, làm mới nền mỗi 12 giờ khi Android cho phép và khi mở app. Báo thức và uống nước lặp hằng tuần/hằng ngày. Nên mở app định kỳ để kiểm tra trạng thái nhắc. Chế độ tiết kiệm pin hoặc tắt cưỡng bức có thể ngăn thông báo. App dùng giờ Việt Nam.')),
    ]),
    const Padding(padding:EdgeInsets.all(16),child:Text('Nhắc việc · 1.0\nDữ liệu lưu trên máy. Xóa app sẽ xóa dữ liệu. Cài APK mới cùng chữ ký để giữ dữ liệu.')),
  ]));
  Future<void> customColor() async {
    final c=TextEditingController(text:s.color.toRadixString(16).substring(2));
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Màu chủ đạo'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'Mã HEX, ví dụ 623B67')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),FilledButton(onPressed:() async { final v=c.text.replaceAll('#','').trim(); if(!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) { message('Nhập đúng 6 ký tự HEX.'); return; } s.color=int.parse('ff$v',radix:16); Navigator.pop(ctx); await save(); },child:const Text('Áp dụng'))])); c.dispose();
  }
}
