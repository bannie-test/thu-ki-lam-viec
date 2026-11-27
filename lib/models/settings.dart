/// All user-adjustable preferences. The whole UI theme is derived from these
/// values, so changing a setting re-themes the app instantly.
class AppSettings {
  String name;

  // ---- Giao diện ----
  String preset; // id of a ThemePreset, or 'custom'
  int seedColor; // used when preset == 'custom'
  String mode; // 'light' | 'dark' | 'system'
  double textScale; // 1.0 … 1.6
  bool highContrast;
  bool roundCorners;
  bool comfortable; // larger spacing & touch targets
  bool boldText;

  // ---- Lịch ----
  bool showLunarInGrid;
  bool showHolidays;
  bool weekStartsMonday;

  // ---- Nhắc việc ----
  bool notifications;
  int defaultRemind;

  // ---- AI ----
  bool aiEnabled;

  AppSettings({
    this.name = 'Mẹ',
    this.preset = 'sen',
    this.seedColor = 0xFFC2185B,
    this.mode = 'light',
    this.textScale = 1.2,
    this.highContrast = false,
    this.roundCorners = true,
    this.comfortable = true,
    this.boldText = false,
    this.showLunarInGrid = true,
    this.showHolidays = true,
    this.weekStartsMonday = true,
    this.notifications = true,
    this.defaultRemind = 0,
    this.aiEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'preset': preset,
    'seedColor': seedColor,
    'mode': mode,
    'textScale': textScale,
    'highContrast': highContrast,
    'roundCorners': roundCorners,
    'comfortable': comfortable,
    'boldText': boldText,
    'showLunarInGrid': showLunarInGrid,
    'showHolidays': showHolidays,
    'weekStartsMonday': weekStartsMonday,
    'notifications': notifications,
    'defaultRemind': defaultRemind,
    'aiEnabled': aiEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings();
    return AppSettings(
      name: j['name'] as String? ?? d.name,
      preset: j['preset'] as String? ?? d.preset,
      seedColor: j['seedColor'] as int? ?? d.seedColor,
      mode: j['mode'] as String? ?? d.mode,
      textScale: ((j['textScale'] as num?) ?? d.textScale).toDouble().clamp(
        1.0,
        1.6,
      ),
      highContrast: j['highContrast'] as bool? ?? d.highContrast,
      roundCorners: j['roundCorners'] as bool? ?? d.roundCorners,
      comfortable: j['comfortable'] as bool? ?? d.comfortable,
      boldText: j['boldText'] as bool? ?? d.boldText,
      showLunarInGrid: j['showLunarInGrid'] as bool? ?? d.showLunarInGrid,
      showHolidays: j['showHolidays'] as bool? ?? d.showHolidays,
      weekStartsMonday: j['weekStartsMonday'] as bool? ?? d.weekStartsMonday,
      notifications: j['notifications'] as bool? ?? d.notifications,
      defaultRemind: j['defaultRemind'] as int? ?? d.defaultRemind,
      aiEnabled: j['aiEnabled'] as bool? ?? d.aiEnabled,
    );
  }
}
