import 'package:material_ui/material_ui.dart';

/// The design's tokens (docs/New_Design/Colour & type tokens): one colour per nutrient and per meal,
/// used the same way on every screen. Dark is the design's; light keeps the roles with darker hues.
class AppColors {
  static const Color primary = Color(0xFF22704A);
  static const Color background = Color(0xFFF1ECE2);
}

/// The app's colours for the current theme: `context.colors.muted`.
/// "Wallpaper colours" (Android 12+) derive the surfaces from the system scheme.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.heroSurface,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.border,
    required this.divider,
    required this.track,
    required this.outline,
    required this.hero,
    required this.mint,
    required this.onMint,
    required this.warm,
    required this.onWarm,
    required this.water,
    required this.waterBg,
    required this.waterTint,
    required this.danger,
    required this.dangerBg,
    required this.gold,
    required this.dark,
    required this.accents,
  });

  /// Brand green (links, primary buttons), its pressed shade and what sits on it (and on any accent fill).
  final Color primary, primaryDark, onPrimary;

  /// Screen background, cards, a raised control on a card (selected tab, icon button), the green hero cards.
  final Color background, surface, surfaceHigh, heroSurface;

  /// Text: headings, secondary body, captions.
  final Color ink, ink2, muted;

  /// Card border, row divider, progress track, outlined-button border.
  final Color border, divider, track, outline;

  /// Strong green fill under white text (avatars, the set-goals card).
  final Color hero;

  /// Soft green chip (good news, "custom"), warm amber chip (plan, streak, Pro), water blue.
  final Color mint, onMint, warm, onWarm, water, waterBg, waterTint;

  /// Errors and the danger zone.
  final Color danger, dangerBg;

  /// Pro badge, cook timer.
  final Color gold;

  /// Highest contrast to the background: selected chips, user chat bubbles.
  final Color dark;

  /// Nutrient key ('kcal', 'protein_g', …, 'water') → its colour; see [nutrientColor].
  final Map<String, Color> accents;

  // Names the screens used before the redesign.
  Color get textPrimary => ink;
  Color get textSecondary => muted;
  Color get cardGreen => mint;
  Color get accent => primary;
  Color get primaryLight => primary;
  Color get error => danger;

  static const _nightAccents = {
    'kcal': Color(0xFF6EE7A8),
    'protein_g': Color(0xFFFF8A6B),
    'carbs_g': Color(0xFFFFC24D),
    'fat_g': Color(0xFFA99BFF),
    'fiber_g': Color(0xFFF59AC4),
    'sugar_g': Color(0xFFC4E36B),
    'sodium_mg': Color(0xFF8FB2FF),
    'water': Color(0xFF5CC2FF),
  };

  // The same hues, dark enough for text on the light background and cards (each ≥ 4.5:1, test/theme_test.dart).
  static const _lightAccents = {
    'kcal': Color(0xFF22704A),
    'protein_g': Color(0xFFB7411C),
    'carbs_g': Color(0xFF905E00),
    'fat_g': Color(0xFF6650DB),
    'fiber_g': Color(0xFFB73875),
    'sugar_g': Color(0xFF567300),
    'sodium_mg': Color(0xFF3460D0),
    'water': Color(0xFF006FA8),
  };

  // The app icon's colours (forest green, sage, cream, peach): a warm cream base instead of a cool grey one, sage
  // chips, peach chips (warm hues go with food and appetite), the icon's forest green for the strong fills. No pure
  // white (glare); background darkest, cards lightest, stepped by tone like Material 3's surface containers.
  static const light = AppPalette(
    primary: Color(0xFF22704A),
    primaryDark: Color(0xFF175A3A),
    onPrimary: Colors.white,
    background: Color(0xFFF1ECE2),
    surface: Color(0xFFFBF8F2),
    surfaceHigh: Color(0xFFE8E1D4),
    heroSurface: Color(0xFFDCE8D3),
    ink: Color(0xFF1C2A21),
    ink2: Color(0xFF3A4A3F),
    muted: Color(0xFF5C645B),
    border: Color(0xFFE3DBCD),
    divider: Color(0xFFEBE5DA),
    track: Color(0xFFE6DFD2),
    outline: Color(0xFFCDC4B4),
    hero: Color(0xFF30543C),
    mint: Color(0xFFDDEBD8),
    onMint: Color(0xFF24503A),
    warm: Color(0xFFFBE1D3),
    onWarm: Color(0xFF8A3B1E),
    water: Color(0xFF006FA8),
    waterBg: Color(0xFFDFEDF4),
    waterTint: Color(0xFFCCDFE9),
    danger: Color(0xFFB3261E),
    dangerBg: Color(0xFFF7E2DE),
    gold: Color(0xFFFFC24D),
    dark: Color(0xFF1C2A21),
    accents: _lightAccents,
  );

  // Off-white text (L* 90, as Material's onSurface), not near-white: less glare and smear on black; cards a
  // tone above the background so they read without borders.
  static const night = AppPalette(
    primary: Color(0xFF6EE7A8),
    primaryDark: Color(0xFF9FF0C6),
    onPrimary: Color(0xFF0D1311),
    background: Color(0xFF0D1311),
    surface: Color(0xFF19221E),
    surfaceHigh: Color(0xFF26332D),
    heroSurface: Color(0xFF1C3A2A),
    ink: Color(0xFFDFE7E2),
    ink2: Color(0xFFC2CEC8),
    muted: Color(0xFFA3B5AC),
    border: Color(0xFF1E2824),
    divider: Color(0xFF222C27),
    track: Color(0xFF26332D),
    outline: Color(0xFF34433C),
    hero: Color(0xFF2C5A40),
    mint: Color(0xFF22402F),
    onMint: Color(0xFF6EE7A8),
    warm: Color(0xFF3D2A21),
    onWarm: Color(0xFFFFB08A),
    water: Color(0xFF5CC2FF),
    waterBg: Color(0xFF173A5A),
    waterTint: Color(0xFF20373F),
    danger: Color(0xFFFF8F80),
    dangerBg: Color(0xFF3D211D),
    gold: Color(0xFFFFC24D),
    dark: Color(0xFFDFE7E2),
    accents: _nightAccents,
  );

  /// From a system (wallpaper) scheme: the same roles, the wallpaper's colours.
  factory AppPalette.of(ColorScheme s) {
    final base = s.brightness == Brightness.dark ? night : light;
    return base.copyWith(
      primary: s.primary,
      primaryDark: s.onPrimaryContainer,
      onPrimary: s.onPrimary,
      background: s.surface,
      surface: s.surfaceContainerLow,
      surfaceHigh: s.surfaceContainerHighest,
      heroSurface: s.primaryContainer,
      ink: s.onSurface,
      ink2: s.onSurfaceVariant,
      muted: s.onSurfaceVariant,
      border: s.outlineVariant,
      divider: s.surfaceContainerHigh,
      track: s.surfaceContainerHighest,
      outline: s.outline,
      hero: s.primary,
      mint: s.primaryContainer,
      onMint: s.onPrimaryContainer,
      warm: s.tertiaryContainer,
      onWarm: s.onTertiaryContainer,
      dark: s.inverseSurface,
    );
  }

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryDark,
    Color? onPrimary,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? heroSurface,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? border,
    Color? divider,
    Color? track,
    Color? outline,
    Color? hero,
    Color? mint,
    Color? onMint,
    Color? warm,
    Color? onWarm,
    Color? dark,
  }) =>
      AppPalette(
        primary: primary ?? this.primary,
        primaryDark: primaryDark ?? this.primaryDark,
        onPrimary: onPrimary ?? this.onPrimary,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        heroSurface: heroSurface ?? this.heroSurface,
        ink: ink ?? this.ink,
        ink2: ink2 ?? this.ink2,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        divider: divider ?? this.divider,
        track: track ?? this.track,
        outline: outline ?? this.outline,
        hero: hero ?? this.hero,
        mint: mint ?? this.mint,
        onMint: onMint ?? this.onMint,
        warm: warm ?? this.warm,
        onWarm: onWarm ?? this.onWarm,
        water: water,
        waterBg: waterBg,
        waterTint: waterTint,
        danger: danger,
        dangerBg: dangerBg,
        gold: gold,
        dark: dark ?? this.dark,
        accents: accents,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: m(primary, other.primary),
      primaryDark: m(primaryDark, other.primaryDark),
      onPrimary: m(onPrimary, other.onPrimary),
      background: m(background, other.background),
      surface: m(surface, other.surface),
      surfaceHigh: m(surfaceHigh, other.surfaceHigh),
      heroSurface: m(heroSurface, other.heroSurface),
      ink: m(ink, other.ink),
      ink2: m(ink2, other.ink2),
      muted: m(muted, other.muted),
      border: m(border, other.border),
      divider: m(divider, other.divider),
      track: m(track, other.track),
      outline: m(outline, other.outline),
      hero: m(hero, other.hero),
      mint: m(mint, other.mint),
      onMint: m(onMint, other.onMint),
      warm: m(warm, other.warm),
      onWarm: m(onWarm, other.onWarm),
      water: m(water, other.water),
      waterBg: m(waterBg, other.waterBg),
      waterTint: m(waterTint, other.waterTint),
      danger: m(danger, other.danger),
      dangerBg: m(dangerBg, other.dangerBg),
      gold: m(gold, other.gold),
      dark: m(dark, other.dark),
      accents: {for (final e in accents.entries) e.key: m(e.value, other.accents[e.key] ?? e.value)},
    );
  }
}

extension AppPaletteX on BuildContext {
  // A theme without it (tests, dialogs built outside the app): the default for its brightness.
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppPalette.night : AppPalette.light);
}

extension AccentX on BuildContext {
  /// A nutrient's colour ('protein_g', 'kcal', 'water'…) in this theme.
  Color nutrientColor(String key) => colors.accents[key] ?? colors.primary;

  /// A meal's colour, the same on every screen: breakfast amber, lunch green, dinner violet, snack coral.
  Color mealColor(String type) => nutrientColor(_mealAccent[type] ?? 'protein_g');
}

const _mealAccent = {'breakfast': 'carbs_g', 'lunch': 'kcal', 'dinner': 'fat_g', 'snack': 'protein_g'};

/// Each meal's icon, drawn in its colour on a [tint] of it.
const mealIcons = {
  'breakfast': Icons.coffee_outlined,
  'lunch': Icons.rice_bowl_outlined,
  'dinner': Icons.bedtime_outlined,
  'snack': Icons.cookie_outlined,
};

/// [color] washed over [base] (the card surface): the design's 16 % tint, 13 % on light (more colour on the warm
/// cream, the icon still ≥ 3:1 on it: test/theme_test.dart).
Color tint(BuildContext context, Color color, {Color? base, double? alpha}) => Color.alphaBlend(
    color.withValues(alpha: alpha ?? (Theme.of(context).brightness == Brightness.dark ? .16 : .13)),
    base ?? context.colors.surface);

/// Corner radii of the design: cards 20, hero cards 24, tiles and inputs 14, chips 12, pills full.
abstract final class Radii {
  static const card = 20.0;
  static const hero = 24.0;
  static const tile = 14.0;
  static const input = 14.0;
  static const chip = 12.0;
  static const pill = 999.0;
}

/// Type scale of the design (Plus Jakarta Sans): display 30/800 … caption 12/500.
abstract final class AppText {
  static const display = TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15);
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2);
  static const section = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25);
  static const item = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3);
  static const tabular = [FontFeature.tabularFigures()];
}

/// The user's text size a notch smaller: at the design's sizes menu items, chips and buttons wrapped onto a second
/// line on phones. Keeps Android's nonlinear scaling (large text grows headings less).
class SmallerText extends TextScaler {
  const SmallerText(this.user);
  final TextScaler user;
  static const factor = .92;

  @override
  double scale(double fontSize) => user.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => user.textScaleFactor * factor;

  @override
  bool operator ==(Object other) => other is SmallerText && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

class AppTheme {
  static ThemeData get lightTheme => build(Brightness.light);

  /// [system]: the wallpaper scheme when the user chose it, else the design's palette.
  static ThemeData build(Brightness brightness, {ColorScheme? system}) {
    final isDark = brightness == Brightness.dark;
    final p = system != null ? AppPalette.of(system) : (isDark ? AppPalette.night : AppPalette.light);
    final scheme = system ??
        ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.mint,
          onPrimaryContainer: p.onMint,
          secondary: p.primary,
          secondaryContainer: p.mint,
          onSecondaryContainer: p.onMint,
          tertiaryContainer: p.warm,
          onTertiaryContainer: p.onWarm,
          surface: p.background,
          onSurface: p.ink,
          onSurfaceVariant: p.muted,
          surfaceContainerLowest: p.surface,
          surfaceContainerLow: p.surface,
          surfaceContainer: p.surface,
          surfaceContainerHigh: p.track,
          surfaceContainerHighest: p.track,
          outline: p.outline,
          outlineVariant: p.border,
          error: p.danger,
          inverseSurface: p.dark,
        );
    const font = 'PlusJakartaSans';
    const fallback = ['Onest']; // Cyrillic (Ukrainian): Plus Jakarta Sans has none
    // From the scheme, not patched on later: derived colours (the dropdown menus' canvas, cards, hints) follow it.
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: font, fontFamilyFallback: fallback);
    TextStyle? as(TextStyle? s, TextStyle t, [Color? color]) => s?.merge(t).copyWith(color: color ?? p.ink);
    final text = base.textTheme.copyWith(
      displaySmall: as(base.textTheme.displaySmall, AppText.display),
      headlineLarge: as(base.textTheme.headlineLarge, AppText.display),
      headlineMedium: as(base.textTheme.headlineMedium, AppText.display.copyWith(fontSize: 26)),
      headlineSmall: as(base.textTheme.headlineSmall, AppText.title),
      titleLarge: as(base.textTheme.titleLarge, AppText.title),
      titleMedium: as(base.textTheme.titleMedium, AppText.section),
      titleSmall: as(base.textTheme.titleSmall, AppText.item),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15, color: p.ink),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, color: p.ink2),
      bodySmall: as(base.textTheme.bodySmall, AppText.caption, p.muted),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    );
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile));
    const tall = Size(64, 52);
    final inputBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: p.border));
    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      canvasColor: p.surface, // dropdown menus, like the popup menus (surfaceContainer)
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: p.primary, foregroundColor: p.onPrimary, minimumSize: tall, shape: pill,
            textStyle: const TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: p.primary, foregroundColor: p.onPrimary, elevation: 0, minimumSize: tall, shape: pill,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: const TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            backgroundColor: p.surface, foregroundColor: p.ink, side: BorderSide(color: p.outline),
            minimumSize: tall, shape: pill, padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: const TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary, minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.muted, fontSize: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: p.border)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.dark,
        side: BorderSide(color: p.outline),
        shape: pill,
        labelStyle: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 15, color: p.ink),
        secondaryLabelStyle: TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 15, color: p.background),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.track,
          selectedBackgroundColor: p.surface,
          selectedForegroundColor: p.ink,
          foregroundColor: p.muted,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.surface),
        side: BorderSide(color: p.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.track),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.muted),
        trackOutlineColor: WidgetStatePropertyAll(p.outline.withValues(alpha: 0)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.primary,
        titleTextStyle:
            TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
        subtitleTextStyle:
            TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: 13, fontWeight: FontWeight.w500, color: p.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.dark,
        contentTextStyle: TextStyle(fontFamily: font, fontFamilyFallback: fallback, color: p.background, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.track),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: p.dark, foregroundColor: p.background, shape: const CircleBorder()),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.mint,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
