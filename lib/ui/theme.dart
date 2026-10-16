import 'package:material_ui/material_ui.dart';

/// The design's light palette (docs/MyFoodMind redesign.html): warm paper, deep green, near-black ink.
class AppColors {
  static const Color primary = Color(0xFF1F6B3A);
  static const Color background = Color(0xFFF6F5EF);
}

/// The app's colours for the current theme: `context.colors.muted`.
/// Light is the redesign's palette; dark is derived from it (and from its dark Cook mode);
/// "wallpaper colours" (Android 12+) derive both from the system scheme.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.background,
    required this.surface,
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
  });

  /// Brand green (links, primary buttons), its pressed shade and what sits on it.
  final Color primary, primaryDark, onPrimary;

  /// Screen background and cards.
  final Color background, surface;

  /// Text: headings, secondary body, captions.
  final Color ink, ink2, muted;

  /// Card border, row divider, segmented-control track, outlined-button border.
  final Color border, divider, track, outline;

  /// The calories hero card.
  final Color hero;

  /// Soft green chip (good news, "custom"), warm amber chip (plan, streak, Pro), water blue.
  final Color mint, onMint, warm, onWarm, water, waterBg, waterTint;

  /// Errors and the danger zone.
  final Color danger, dangerBg;

  /// Pro badge, cook timer.
  final Color gold;

  /// Near-black: the + button, user chat bubbles, dark promo cards.
  final Color dark;

  // Names the screens used before the redesign.
  Color get textPrimary => ink;
  Color get textSecondary => muted;
  Color get cardGreen => mint;
  Color get accent => primary;
  Color get primaryLight => primary;
  Color get error => danger;

  static const light = AppPalette(
    primary: Color(0xFF1F6B3A),
    primaryDark: Color(0xFF164F2B),
    onPrimary: Colors.white,
    background: Color(0xFFF6F5EF),
    surface: Colors.white,
    ink: Color(0xFF16201A),
    ink2: Color(0xFF3D4A41),
    muted: Color(0xFF5A675E),
    border: Color(0xFFE3E4DC),
    divider: Color(0xFFEFEFE9),
    track: Color(0xFFECEDE5),
    outline: Color(0xFFD5D8CD),
    hero: Color(0xFF1F6B3A),
    mint: Color(0xFFE1EEE2),
    onMint: Color(0xFF1F4D2E),
    warm: Color(0xFFFFF4E5),
    onWarm: Color(0xFF6B4A12),
    water: Color(0xFF2A78D6),
    waterBg: Color(0xFFE3EEFB),
    waterTint: Color(0xFFDCE6F2),
    danger: Color(0xFFA3321C),
    dangerBg: Color(0xFFFDF3F1),
    gold: Color(0xFFF7C74F),
    dark: Color(0xFF16201A),
  );

  static const night = AppPalette(
    primary: Color(0xFF8CD4A6),
    primaryDark: Color(0xFFA8EBCF),
    onPrimary: Color(0xFF0F2A1E),
    background: Color(0xFF121A15),
    surface: Color(0xFF1B231E),
    ink: Color(0xFFE8EDE6),
    ink2: Color(0xFFC9D3CB),
    muted: Color(0xFFA9B8AD),
    border: Color(0xFF2E3A32),
    divider: Color(0xFF25302A),
    track: Color(0xFF1E3326),
    outline: Color(0xFF3A473E),
    hero: Color(0xFF1E5A33),
    mint: Color(0xFF1E3326),
    onMint: Color(0xFFCFE3D2),
    warm: Color(0xFF3A2A05),
    onWarm: Color(0xFFF3D9B1),
    water: Color(0xFF9BC1EE),
    waterBg: Color(0xFF1D3F6B),
    waterTint: Color(0xFF2E4A3B),
    danger: Color(0xFFF0C4BA),
    dangerBg: Color(0xFF5C2A1F),
    gold: Color(0xFFF7C74F),
    dark: Color(0xFFE8EDE6),
  );

  /// From a system (wallpaper) scheme: the same roles, the wallpaper's colours.
  factory AppPalette.of(ColorScheme s) {
    final base = s.brightness == Brightness.dark ? night : light;
    return base.copyWith(
      primary: s.primary,
      primaryDark: s.onPrimaryContainer,
      onPrimary: s.onPrimary,
      background: s.surface,
      surface: s.surfaceContainerLowest,
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
    );
  }
}

extension AppPaletteX on BuildContext {
  // A theme without it (tests, dialogs built outside the app): the default for its brightness.
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppPalette.night : AppPalette.light);
}

/// Corner radii of the design: cards 20, small cards 18, inputs and tiles 14-16, pills full.
abstract final class Radii {
  static const card = 20.0;
  static const tile = 18.0;
  static const input = 16.0;
  static const pill = 999.0;
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
    const font = 'Onest';
    final base = ThemeData(useMaterial3: true, brightness: brightness, fontFamily: font);
    TextStyle? tight(TextStyle? s, double size, FontWeight w) =>
        s?.copyWith(fontSize: size, fontWeight: w, letterSpacing: -0.02 * size, color: p.ink, height: 1.15);
    final text = base.textTheme.copyWith(
      displaySmall: tight(base.textTheme.displaySmall, 34, FontWeight.w700),
      headlineLarge: tight(base.textTheme.headlineLarge, 34, FontWeight.w700),
      headlineMedium: tight(base.textTheme.headlineMedium, 28, FontWeight.w700),
      headlineSmall: tight(base.textTheme.headlineSmall, 24, FontWeight.w700),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: p.ink),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15, color: p.ink),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, color: p.ink2),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, color: p.muted),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    );
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill));
    const tall = Size(64, 52);
    final inputBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: p.border));
    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
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
            textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: p.primary, foregroundColor: p.onPrimary, elevation: 0, minimumSize: tall, shape: pill,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            backgroundColor: p.surface, foregroundColor: p.ink, side: BorderSide(color: p.outline),
            minimumSize: tall, shape: pill, padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary, minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w600)),
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
        labelStyle: TextStyle(fontFamily: font, fontSize: 15, color: p.ink),
        secondaryLabelStyle: TextStyle(fontFamily: font, fontSize: 15, color: p.background),
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
          textStyle: const TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600),
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
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 16, color: p.ink),
        subtitleTextStyle: TextStyle(fontFamily: font, fontSize: 13, color: p.muted),
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
        contentTextStyle: TextStyle(fontFamily: font, color: p.background, fontSize: 14),
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

/// One fixed colour per nutrient, everywhere in the app (categorical slots
/// 1–7 of the dataviz reference palette, in order; validated for colour-blind
/// separation on white). Text stays in text colours; the colour marks identity.
/// Yellow, aqua and pink are under 3:1 on white, so every value keeps a visible label.
const nutrientColors = <String, Color>{
  'kcal': Color(0xFF2A78D6),
  'protein_g': Color(0xFFEB6834),
  'fat_g': Color(0xFF1BAF7A),
  'carbs_g': Color(0xFFEDA100),
  'fiber_g': Color(0xFFE87BA4),
  'sugar_g': Color(0xFF008300),
  'sodium_mg': Color(0xFF4A3AA7),
};

/// The macro bars on the green hero card: lighter tints of the nutrient colours, readable on green.
const heroMacroColors = <String, Color>{
  'protein_g': Color(0xFFF6A27F),
  'carbs_g': Color(0xFFF7C74F),
  'fat_g': Color(0xFF7FDDB6),
};
