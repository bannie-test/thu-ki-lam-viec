import 'package:vnlunar/vnlunar.dart';

String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
String two(int n) => n.toString().padLeft(2, '0');
String clock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';
bool sameDay(DateTime a, DateTime b) => dayKey(a) == dayKey(b);
List<int> lunar(DateTime d) => convertSolar2Lunar(d.day, d.month, d.year, 7);

const categories = ['Khác', 'Uống thuốc', 'Tập thể dục', 'Làm giỗ', 'Mua sắm', 'Đi ăn cỗ', 'Chấm bài', 'Điểm danh trên ứng dụng'];
const repeats = ['Không lặp', 'Mỗi ngày', 'Mỗi tuần', 'Hằng năm (dương)', 'Hằng năm (âm)'];

class Task {
  String id, title, note, category, repeat;
  DateTime due;
  int early;
  Map<String, String> records;
  Task({required this.id, required this.title, required this.due,
    this.note = '', this.category = 'Khác', this.repeat = 'Không lặp',
    this.early = 0, Map<String, String>? records}) : records = records ?? {};
  bool occurs(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    final start = DateTime(due.year, due.month, due.day);
    if (date.isBefore(start)) return false;
    switch (repeat) {
      case 'Mỗi ngày': return true;
      case 'Mỗi tuần': return due.weekday == d.weekday;
      case 'Hằng năm (dương)': return due.day == d.day && due.month == d.month;
      case 'Hằng năm (âm)':
        final a = lunar(due), b = lunar(d);
        // A leap-month anniversary stays in leap months; never silently shifts.
        return a[0] == b[0] && a[1] == b[1] && a[3] == b[3];
      default: return sameDay(due, d);
    }
  }
  DateTime at(DateTime d) => DateTime(d.year, d.month, d.day, due.hour, due.minute);
  String status(DateTime d) => records[dayKey(d)] ?? 'pending';
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'due': due.toIso8601String(), 'note': note, 'category': category, 'repeat': repeat, 'early': early, 'records': records};
  factory Task.fromJson(Map<String, dynamic> j) => Task(id: j['id'], title: j['title'], due: DateTime.parse(j['due']), note: j['note'] ?? '', category: j['category'] ?? 'Khác', repeat: j['repeat'] ?? 'Không lặp', early: j['early'] ?? 0, records: Map<String, String>.from(j['records'] ?? {}));
}

class Alarm {
  String id, label;
  int hour, minute;
  bool enabled;
  List<int> weekdays;
  Alarm({required this.id, required this.label, required this.hour, required this.minute, this.enabled = true, List<int>? weekdays}) : weekdays = weekdays ?? [1,2,3,4,5,6,7];
  Map<String, dynamic> toJson() => {'id':id,'label':label,'hour':hour,'minute':minute,'enabled':enabled,'weekdays':weekdays};
  factory Alarm.fromJson(Map<String,dynamic> j) => Alarm(id:j['id'], label:j['label'], hour:j['hour'], minute:j['minute'], enabled:j['enabled'], weekdays:List<int>.from(j['weekdays']));
}

class Settings {
  int color = 0xff623b67, background = 0xfffff9f0, textSize = 20;
  String image = '', model = 'gpt-4.1-mini';
  double opacity = .12, weight = 60, height = 160;
  int waterGoal = 1600, cup = 200, waterStart = 7, waterEnd = 19, waterEvery = 120;
  bool customFluid = false, ai = false, tasks = true, alarms = true, water = true;
  bool sound = true, vibration = true, review = true, summary = true;
  List<String> reviewTimes = ['11:30','17:00'];
  String reviewStop = '20:00', summaryTime = '20:30';
  Map<String,dynamic> toJson() => {'color':color,'background':background,'textSize':textSize,'image':image,'model':model,'opacity':opacity,'weight':weight,'height':height,'waterGoal':waterGoal,'cup':cup,'waterStart':waterStart,'waterEnd':waterEnd,'waterEvery':waterEvery,'customFluid':customFluid,'ai':ai,'tasks':tasks,'alarms':alarms,'water':water,'sound':sound,'vibration':vibration,'review':review,'summary':summary,'reviewTimes':reviewTimes,'reviewStop':reviewStop,'summaryTime':summaryTime};
  factory Settings.fromJson(Map<String,dynamic> j) {
    final s = Settings();
    s.color=j['color']??s.color; s.background=j['background']??s.background;
    s.textSize=j['textSize']??20; s.image=j['image']??''; s.model=j['model']??s.model;
    s.opacity=(j['opacity']??.12).toDouble(); s.weight=(j['weight']??60).toDouble(); s.height=(j['height']??160).toDouble();
    s.waterGoal=j['waterGoal']??1600; s.cup=j['cup']??200; s.waterStart=j['waterStart']??7; s.waterEnd=j['waterEnd']??19; s.waterEvery=j['waterEvery']??120;
    s.customFluid=j['customFluid']??false; s.ai=j['ai']??false; s.tasks=j['tasks']??true; s.alarms=j['alarms']??true; s.water=j['water']??true;
    s.sound=j['sound']??true; s.vibration=j['vibration']??true; s.review=j['review']??true; s.summary=j['summary']??true;
    s.reviewTimes=List<String>.from(j['reviewTimes']??s.reviewTimes); s.reviewStop=j['reviewStop']??s.reviewStop; s.summaryTime=j['summaryTime']??s.summaryTime;
    return s;
  }
  Settings();
}

/// Conservative local parser. The user always reviews the returned draft.
Task parseDraft(String text, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  if (text.toLowerCase().contains('ngày mai')) day = day.add(const Duration(days:1));
  final m = RegExp(r'(\d{1,2})\s*(?:giờ|:|h)\s*(\d{1,2})?', caseSensitive:false).firstMatch(text);
  var hour = m == null ? 9 : int.tryParse(m[1]!) ?? 9;
  var minute = m?[2] == null ? 0 : int.tryParse(m![2]!) ?? 0;
  if (RegExp(r'chiều|tối',caseSensitive:false).hasMatch(text) && hour < 12) hour += 12;
  if (hour > 23 || minute > 59) { hour=9; minute=0; }
  var category = 'Khác';
  for(final c in categories.skip(1)) { if(text.toLowerCase().contains(c.toLowerCase())) category=c; }
  return Task(id:DateTime.now().microsecondsSinceEpoch.toString(), title:text.trim(), due:DateTime(day.year,day.month,day.day,hour,minute), category:category, repeat:text.toLowerCase().contains('mỗi ngày')?'Mỗi ngày':'Không lặp');
}
