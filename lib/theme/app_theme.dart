import 'package:flutter/material.dart';
import '../models/settings.dart';

class ThemePreset {
  final String id, name, description;
  final int seed;
  final int lightBackground;
  const ThemePreset(
    this.id,
    this.name,
    this.description,
    this.seed,
    this.lightBackground,
  );
}

/// Palettes named after familiar Vietnamese things.
const themePresets = <ThemePreset>[
  ThemePreset('sen', 'Hoa sen', 'Hồng sen dịu dàng', 0xFFC2185B, 0xFFFFF7F9),
  ThemePreset('tra', 'Trà xanh', 'Xanh lá mát mắt', 0xFF2E7D32, 0xFFF6FBF4),
  ThemePreset(
    'bien',
    'Biển xanh',
    'Xanh dương trong trẻo',
    0xFF1565C0,
    0xFFF5F9FF,
  ),
  ThemePreset('nang', 'Nắng mai', 'Cam vàng ấm áp', 0xFFE65100, 0xFFFFF9F2),
  ThemePreset(
    'ca-phe',
    'Cà phê sữa',
    'Nâu trầm ấm cúng',
    0xFF6D4C41,
    0xFFFBF7F4,
  ),
  ThemePreset('hoa-ca', 'Hoa cà', 'Tím nhẹ nhàng', 0xFF6A1B9A, 0xFFFAF6FD),
];

/// Free colour choices for the "Tự chọn màu" option.
const customSeeds = <int>[
  0xFFC2185B,
  0xFFD32F2F,
  0xFFE65100,
  0xFFF9A825,
  0xFF2E7D32,
  0xFF00796B,
  0xFF0277BD,
  0xFF1565C0,
  0xFF283593,
  0xFF6A1B9A,
  0xFF6D4C41,
  0xFF455A64,
];

ThemePreset? presetById(String id) {
  for (final p in themePresets) {
    if (p.id == id) return p;
  }
  return null;
}

int seedOf(AppSettings s) => presetById(s.preset)?.seed ?? s.seedColor;

ThemeMode themeModeOf(AppSettings s) => switch (s.mode) {
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => ThemeMode.light,
};

/// Spacing/size tokens derived from settings, available via `Theme.of(context).extension<Look>()`.
@immutable
class Look extends ThemeExtension<Look> {
  final double radius;
  final double gap;
  final double touch;
  const Look({required this.radius, required this.gap, required this.touch});

  static Look of(BuildContext context) =>
      Theme.of(context).extension<Look>() ??
      const Look(radius: 20, gap: 16, touch: 56);

  @override
  Look copyWith({double? radius, double? gap, double? touch}) => Look(
    radius: radius ?? this.radius,
    gap: gap ?? this.gap,
    touch: touch ?? this.touch,
  );

  @override
  Look lerp(Look? other, double t) {
    if (other == null) return this;
    double l(double a, double b) => a + (b - a) * t;
    return Look(
      radius: l(radius, other.radius),
      gap: l(gap, other.gap),
      touch: l(touch, other.touch),
    );
  }
}

ThemeData buildTheme(AppSettings s, Brightness brightness) {
  final seed = Color(seedOf(s));
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    contrastLevel: s.highContrast ? 1.0 : 0.0,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  final preset = presetById(s.preset);
  if (!dark && preset != null && !s.highContrast) {
    scheme = scheme.copyWith(surface: Color(preset.lightBackground));
  }
  if (s.highContrast) {
    scheme = scheme.copyWith(
      surface: dark ? Colors.black : Colors.white,
      onSurface: dark ? Colors.white : Colors.black,
      onSurfaceVariant: dark
          ? const Color(0xFFE0E0E0)
          : const Color(0xFF202020),
    );
  }

  final look = Look(
    radius: s.roundCorners ? 22 : 8,
    gap: s.comfortable ? 16 : 10,
    touch: s.comfortable ? 60 : 50,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(look.radius),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(s.roundCorners ? 40 : 8),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final weightBody = s.boldText ? FontWeight.w600 : FontWeight.w400;
  final textTheme = base.textTheme
      .apply(
        fontFamily: 'BeVietnamPro',
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      )
      .copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontFamily: 'BeVietnamPro',
          fontWeight: weightBody,
          height: 1.35,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontFamily: 'BeVietnamPro',
          fontWeight: weightBody,
          height: 1.35,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w700,
        ),
      );

  final minButton = Size(look.touch, look.touch);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    extensions: [look],
    visualDensity: s.comfortable
        ? VisualDensity.comfortable
        : VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? scheme.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: shape.copyWith(
        side: BorderSide(
          color: s.highContrast ? scheme.onSurface : scheme.outlineVariant,
          width: s.highContrast ? 2 : 1,
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minButton,
        shape: buttonShape,
        textStyle: textTheme.titleMedium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minButton,
        shape: buttonShape,
        textStyle: textTheme.titleMedium,
        side: BorderSide(color: scheme.outline, width: s.highContrast ? 2 : 1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(48, look.touch - 8),
        textStyle: textTheme.titleMedium,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: buttonShape,
      extendedTextStyle: textTheme.titleMedium,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: s.comfortable ? 80 : 68,
      backgroundColor: dark ? scheme.surfaceContainer : Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: buttonShape,
      labelStyle: textTheme.bodyLarge,
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: s.comfortable ? 8 : 4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHighest : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(look.radius * .7),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: s.comfortable ? 12 : 6,
      iconColor: scheme.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
      contentTextStyle: textTheme.bodyLarge?.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
    dialogTheme: DialogThemeData(shape: shape),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(look.radius + 6),
        ),
      ),
    ),
  );
}
