import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/address.dart';
import '../core/format.dart';
import '../core/lunar.dart';
import '../models/category.dart';
import '../models/task.dart';
import 'local_parser.dart';

/// Where the Claude API key lives. Backed by Android Keystore in the app,
/// replaceable in tests.
abstract class KeyVault {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureKeyVault implements KeyVault {
  static const _storage = FlutterSecureStorage();
  static const _name = 'anthropic_api_key';
  @override
  Future<String?> read() => _storage.read(key: _name);
  @override
  Future<void> write(String? value) => value == null || value.isEmpty
      ? _storage.delete(key: _name)
      : _storage.write(key: _name, value: value);
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

class AiResult {
  final List<Task> tasks;
  final String message;
  final bool usedAi;
  const AiResult(this.tasks, this.message, {required this.usedAi});
}

/// Turns a free-form Vietnamese request into task drafts using Claude.
/// Drafts are never saved automatically: the user reviews them first.
class AiService {
  static const model = 'claude-opus-5-5';
  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  final KeyVault vault;
  final http.Client client;
  AiService({KeyVault? vault, http.Client? client})
    : vault = vault ?? SecureKeyVault(),
      client = client ?? http.Client();

  Future<bool> hasKey() async => ((await vault.read()) ?? '').trim().isNotEmpty;

  /// Uses Claude when [useAi] and a key is set, otherwise the offline parser.
  Future<AiResult> createTasks(
    String text, {
    required DateTime now,
    required List<Category> categories,
    required bool useAi,
    int defaultRemind = 0,
    Address address = const Address(),
  }) async {
    if (!useAi || !await hasKey()) {
      final drafts = LocalParser.parse(
        text,
        now,
        categories,
        defaultRemind: defaultRemind,
      );
      return AiResult(
        drafts,
        'Đã hiểu theo cách đơn giản (không dùng AI). ${address.You} xem lại giúp ${address.self} nhé.',
        usedAi: false,
      );
    }
    final body = buildRequest(text, now, categories, address: address);
    final key = (await vault.read())!.trim();
    http.Response res;
    try {
      res = await client
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2026-10-21',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw const AiException(
        'Không kết nối được AI. Kiểm tra mạng rồi thử lại, hoặc tắt AI để nhập nhanh.',
      );
    }
    if (res.statusCode != 200) {
      throw AiException(switch (res.statusCode) {
        401 ||
        403 => 'Mã khóa AI không đúng. Vào Cài đặt → Trợ lý AI để kiểm tra.',
        429 => 'AI đang bận hoặc hết hạn mức. Thử lại sau ít phút.',
        >= 500 => 'Máy chủ AI đang gặp sự cố. Thử lại sau nhé.',
        _ => 'AI chưa xử lý được (mã ${res.statusCode}).',
      });
    }
    return parseResponse(
      utf8.decode(res.bodyBytes),
      now,
      categories,
      defaultRemind: defaultRemind,
    );
  }

  static Map<String, dynamic> buildRequest(
    String text,
    DateTime now,
    List<Category> categories, {
    Address address = const Address(),
  }) {
    final lunar = LunarDate.fromSolar(now);
    final cats = categories.map((c) => '- ${c.id}: ${c.name}').join('\n');
    final system =
        '''
Bạn là trợ lý giúp một người Việt Nam ghi lại việc cần làm. Từ lời nói hoặc tin nhắn của người dùng, hãy tách ra từng việc cụ thể.

Xưng hô: gọi người dùng là "${address.you}", tự xưng là "${address.self}"${address.polite ? ', lễ phép (có thể dùng "ạ")' : ''}.

Hôm nay: ${longDate(now)} (dương lịch ${dayKey(now)}), giờ hiện tại ${two(now.hour)}:${two(now.minute)}, âm lịch ${lunar.day}/${lunar.month}${lunar.leap ? ' nhuận' : ''} năm ${canChiYear(lunar.year)}. Múi giờ Việt Nam (UTC+7).

Nhóm việc (chọn category_id phù hợp nhất):
$cats

Quy tắc:
- title: ngắn gọn, tự nhiên, viết hoa chữ đầu, không chứa ngày giờ (ví dụ "Uống thuốc huyết áp").
- Nếu người dùng nói theo âm lịch (rằm, mùng 1, "âm", giỗ, Tết...): calendar = "lunar", điền lunar_day và lunar_month (lunar_month = 0 nếu chỉ nói "rằm"/"mùng một" mà không nói tháng → hiểu là lần gần nhất sắp tới), để date = "".
- Ngược lại: calendar = "solar", date = YYYY-MM-DD (dương lịch), lunar_day = 0, lunar_month = 0. "Mai" = ngày mai, "mốt"/"ngày kia" = 2 ngày nữa.
- time: "HH:MM" 24 giờ; "" nếu cả ngày. "7 giờ tối" = "19:00", "sáng" ≈ "07:00", "trưa" ≈ "11:30", "chiều" ≈ "15:00", "tối" ≈ "19:00".
- repeat: none, daily, weekly, monthly, yearly (dương lịch), lunarMonthly (mỗi tháng âm, ví dụ mỗi rằm), lunarYearly (mỗi năm âm, ví dụ ngày giỗ).
- remind_before: số phút nhắc trước, chỉ được chọn -1 (không nhắc), 0, 15, 60, 1440. Mặc định 0 nếu có giờ, -1 nếu cả ngày; đám giỗ, cuộc hẹn quan trọng nên nhắc trước 1440.
- important: true nếu người dùng nói quan trọng/nhớ kỹ/đừng quên, hoặc là uống thuốc, khám bệnh, giỗ.
- note: thông tin thêm hữu ích (địa điểm, đồ cần mang...), "" nếu không có.
- message: một câu ngắn, ấm áp gửi người dùng theo đúng cách xưng hô ở trên, tóm tắt đã tạo gì hoặc hỏi lại nếu thiếu thông tin quan trọng.
- Nếu không có việc nào, trả về tasks rỗng và giải thích trong message.''';

    const taskSchema = {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'title',
        'category_id',
        'calendar',
        'date',
        'lunar_day',
        'lunar_month',
        'time',
        'repeat',
        'remind_before',
        'important',
        'note',
      ],
      'properties': {
        'title': {'type': 'string'},
        'category_id': {'type': 'string'},
        'calendar': {
          'type': 'string',
          'enum': ['solar', 'lunar'],
        },
        'date': {'type': 'string'},
        'lunar_day': {'type': 'integer'},
        'lunar_month': {'type': 'integer'},
        'time': {'type': 'string'},
        'repeat': {
          'type': 'string',
          'enum': [
            'none',
            'daily',
            'weekly',
            'monthly',
            'yearly',
            'lunarMonthly',
            'lunarYearly',
          ],
        },
        'remind_before': {
          'type': 'integer',
          'enum': [-1, 0, 15, 60, 1440],
        },
        'important': {'type': 'boolean'},
        'note': {'type': 'string'},
      },
    };

    return {
      'model': model,
      'max_tokens': 8000,
      'fallbacks': 'default',
      'output_config': {
        'effort': 'low',
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['tasks', 'message'],
            'properties': {
              'tasks': {'type': 'array', 'items': taskSchema},
              'message': {'type': 'string'},
            },
          },
        },
      },
      'system': system,
      'messages': [
        {'role': 'user', 'content': text},
      ],
    };
  }

  /// Validates Claude's JSON and converts it to task drafts.
  static AiResult parseResponse(
    String raw,
    DateTime now,
    List<Category> categories, {
    int defaultRemind = 0,
  }) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(
        'AI trả về dữ liệu lạ. Hãy thử lại hoặc nhập tay nhé.',
      );
    }
    final stop = data['stop_reason'];
    if (stop == 'refusal') {
      throw const AiException(
        'AI không xử lý yêu cầu này. Hãy thử nói cách khác hoặc nhập tay nhé.',
      );
    }
    if (stop == 'max_tokens') {
      throw const AiException(
        'Yêu cầu dài quá. Hãy chia nhỏ ra rồi thử lại nhé.',
      );
    }
    final text = [
      for (final b in (data['content'] as List? ?? const []))
        if (b is Map && b['type'] == 'text') b['text'] as String,
    ].join();
    final Map<String, dynamic> out;
    try {
      out = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(
        'AI trả về dữ liệu lạ. Hãy thử lại hoặc nhập tay nhé.',
      );
    }
    final ids = categories.map((c) => c.id).toSet();
    final today = dateOnly(now);
    final tasks = <Task>[];
    for (final item in (out['tasks'] as List? ?? const [])) {
      if (item is! Map) continue;
      final j = Map<String, dynamic>.from(item);
      final title = (j['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      final isLunar = j['calendar'] == 'lunar';
      DateTime? date;
      if (isLunar) {
        final ld = (j['lunar_day'] as num?)?.toInt() ?? 0;
        final lm = (j['lunar_month'] as num?)?.toInt() ?? 0;
        if (ld >= 1 && ld <= 30) {
          date = LocalParser.nextLunar(
            today,
            ld,
            lm >= 1 && lm <= 12 ? lm : null,
          );
        }
      } else {
        date = DateTime.tryParse(j['date'] as String? ?? '');
      }
      if (date == null || date.year < 2000 || date.year > 2199) date = today;
      int? minutes;
      final tm = RegExp(
        r'^(\d{1,2}):(\d{2})$',
      ).firstMatch((j['time'] as String? ?? '').trim());
      if (tm != null) {
        final h = int.parse(tm[1]!), m = int.parse(tm[2]!);
        if (h < 24 && m < 60) minutes = h * 60 + m;
      }
      var remind = (j['remind_before'] as num?)?.toInt() ?? defaultRemind;
      if (!reminderOptions.containsKey(remind)) remind = defaultRemind;
      final cat = j['category_id'] as String? ?? '';
      tasks.add(
        Task(
          id: newId(),
          title: title,
          date: date,
          time: minutes,
          repeat: Repeat.parse(j['repeat'] as String?),
          remindBefore: remind,
          important: j['important'] as bool? ?? false,
          note: (j['note'] as String? ?? '').trim(),
          lunarPicked: isLunar,
          categoryId: ids.contains(cat)
              ? cat
              : LocalParser.guessCategory(title, categories),
        ),
      );
    }
    final message = (out['message'] as String? ?? '').trim();
    return AiResult(
      tasks,
      message.isEmpty ? 'Hãy xem lại các việc bên dưới nhé.' : message,
      usedAi: true,
    );
  }
}
