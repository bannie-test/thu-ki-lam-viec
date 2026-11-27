import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'data/store.dart';
import 'services/ai_service.dart';
import 'services/notifications.dart';
import 'services/speech.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(await SharedPreferences.getInstance());
  final reminders = PhoneReminders();
  try {
    await reminders.init();
  } catch (e) {
    debugPrint('Không khởi tạo được thông báo: $e');
  }
  store.onSaved = () => reminders.rebuild(store);
  runApp(
    SoViecApp(
      store: store,
      reminders: reminders,
      ai: AiService(),
      voice: PhoneVoice(),
    ),
  );
}
