import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/store.dart';
import 'services/ai_service.dart';
import 'services/notifications.dart';
import 'services/speech.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';

/// Everything the screens need, handed down the widget tree.
class Services extends InheritedWidget {
  final AppStore store;
  final Reminders reminders;
  final AiService ai;
  final Voice voice;
  const Services({
    super.key,
    required this.store,
    required this.reminders,
    required this.ai,
    required this.voice,
    required super.child,
  });

  static Services of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services oldWidget) => false;
}

class SoViecApp extends StatelessWidget {
  final AppStore store;
  final Reminders reminders;
  final AiService ai;
  final Voice voice;
  const SoViecApp({
    super.key,
    required this.store,
    required this.reminders,
    required this.ai,
    required this.voice,
  });

  @override
  Widget build(BuildContext context) {
    return Services(
      store: store,
      reminders: reminders,
      ai: ai,
      voice: voice,
      // Rebuilds the whole theme whenever a setting changes.
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          return MaterialApp(
            title: 'Việc của Mẹ',
            debugShowCheckedModeBanner: false,
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            themeMode: themeModeOf(s),
            theme: buildTheme(s, Brightness.light),
            darkTheme: buildTheme(s, Brightness.dark),
            themeAnimationDuration: const Duration(milliseconds: 350),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              // Combine the phone's own text size with the in-app setting.
              final scale = (mq.textScaler.scale(1) * s.textScale).clamp(
                1.0,
                2.2,
              );
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(scale),
                  boldText: mq.boldText || s.boldText,
                ),
                child: child!,
              );
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
