// Reused from NutriAI (nutrition_ai_assistent/lib/theme/app_theme.dart).
import 'package:material_ui/material_ui.dart';

/// The light palette's values (and the seed). Widgets use `context.colors`, which follows the theme.
class AppColors {
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color accent = Color(0xFF81C784);
  static const Color background = Color(0xFFF1F8E9);
  static const Color surface = Colors.white;
  static const Color cardGreen = Color(0xFFE8F5E9);
  static const Color textPrimary = Color(0xFF1B5E20);
  static const Color textSecondary = Color(0xFF558B2F);
  static const Color error = Color(0xFFD32F2F);
}

/// The app's colours for the current theme: `context.colors.textSecondary`.
/// Light is the original NutriAI palette; dark keeps the green identity on dark surfaces;
/// "wallpaper colours" (Android 12+) derive both from the system scheme.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.primary, required this.primaryLight, required this.primaryDark,
      required this.accent, required this.cardGreen, required this.textPrimary, required this.textSecondary,
      required this.background, required this.surface, required this.error});
  final Color primary, primaryLight, primaryDark, accent, cardGreen, textPrimary, textSecondary, background,
      surface, error;

  static const light = AppPalette(primary: AppColors.primary, primaryLight: AppColors.primaryLight,
      primaryDark: AppColors.primaryDark, accent: AppColors.accent, cardGreen: AppColors.cardGreen,
      textPrimary: AppColors.textPrimary, textSecondary: AppColors.textSecondary, background: AppColors.background,
      surface: AppColors.surface, error: AppColors.error);

  static const dark = AppPalette(primary: Color(0xFF81C784), primaryLight: Color(0xFF66BB6A),
      primaryDark: Color(0xFF1B5E20), accent: Color(0xFF4CAF50), cardGreen: Color(0xFF1F3322),
      textPrimary: Color(0xFFE6F2E3), textSecondary: Color(0xFFA9C7A2), background: Color(0xFF0F140F),
      surface: Color(0xFF192019), error: Color(0xFFEF9A9A));

  /// From a system (wallpaper) scheme.
  factory AppPalette.of(ColorScheme s) => AppPalette(primary: s.primary, primaryLight: s.primaryFixedDim,
      primaryDark: s.onPrimaryFixedVariant, accent: s.secondary, cardGreen: s.primaryContainer,
      textPrimary: s.onSurface, textSecondary: s.onSurfaceVariant, background: s.surfaceContainerLowest,
      surface: s.surfaceContainerLow, error: s.error);

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(primary: m(primary, other.primary), primaryLight: m(primaryLight, other.primaryLight),
        primaryDark: m(primaryDark, other.primaryDark), accent: m(accent, other.accent),
        cardGreen: m(cardGreen, other.cardGreen), textPrimary: m(textPrimary, other.textPrimary),
        textSecondary: m(textSecondary, other.textSecondary), background: m(background, other.background),
        surface: m(surface, other.surface), error: m(error, other.error));
  }
}

extension AppPaletteX on BuildContext {
  // A theme without it (tests, dialogs built outside the app): the default for its brightness.
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
}

class AppTheme {
  static ThemeData get lightTheme => build(Brightness.light);

  /// [system]: the wallpaper scheme when the user chose it, else the app's green.
  static ThemeData build(Brightness brightness, {ColorScheme? system}) {
    final dark = brightness == Brightness.dark;
    final p = system != null ? AppPalette.of(system) : (dark ? AppPalette.dark : AppPalette.light);
    final onPrimary = dark && system == null ? Colors.black : Colors.white;
    return ThemeData(
      useMaterial3: true,
      colorScheme: system ??
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: p.primary,
            onPrimary: onPrimary,
            secondary: p.accent,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.error,
            brightness: brightness,
          ),
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? p.surface : p.primary,
        foregroundColor: dark ? p.textPrimary : Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.accent)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.primary, width: 2)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.accent.withValues(alpha: 0.5))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: p.primary, foregroundColor: onPrimary),
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
