import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent_tools.dart';
import '../data/conditions.dart';
import '../data/patterns.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;

/// Display name and unit per nutrient key.
Map<String, (String, String)> nutrientLabels(AppLocalizations l) => {
      'kcal': (l.kcal, ''), 'protein_g': (l.protein, 'g'), 'fat_g': (l.fat, 'g'), 'carbs_g': (l.carbs, 'g'),
      'fiber_g': (l.fiber, 'g'), 'sugar_g': (l.sugar, 'g'), 'sodium_mg': (l.sodium, 'mg'),
    };

/// The panel as the screens group it (db/catalog/nutrients.tsv's groups and order, energy among the macros; a test
/// keeps them equal). [moreGroups] stay behind "More".
const nutrientGroups = {
  'macro': ['kcal', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g', 'sugar_g', 'starch_g', 'alcohol_g', 'water_g'],
  'fat': ['saturated_fat_g', 'mono_fat_g', 'poly_fat_g', 'trans_fat_g', 'omega3_g', 'omega6_g', 'cholesterol_mg'],
  'sugar': ['sucrose_g', 'glucose_g', 'fructose_g', 'lactose_g', 'added_sugar_g'],
  'mineral': ['sodium_mg', 'potassium_mg', 'calcium_mg', 'magnesium_mg', 'phosphorus_mg', 'iron_mg', 'zinc_mg',
      'copper_mg', 'manganese_mg', 'selenium_ug', 'iodine_ug'],
  'vitamin': ['vitamin_a_ug', 'beta_carotene_ug', 'vitamin_d_ug', 'vitamin_e_mg', 'vitamin_k_ug', 'vitamin_c_mg',
      'vitamin_b1_mg', 'vitamin_b2_mg', 'vitamin_b3_mg', 'vitamin_b5_mg', 'vitamin_b6_mg', 'vitamin_b7_ug', 'folate_ug',
      'vitamin_b12_ug', 'choline_mg'],
  'amino': ['histidine_g', 'isoleucine_g', 'leucine_g', 'lysine_g', 'methionine_g', 'phenylalanine_g', 'threonine_g',
      'tryptophan_g', 'valine_g'],
};
const moreGroups = {'sugar', 'amino'};

/// Any panel key's display name.
String nutrientName(AppLocalizations l, String key) => nutrientLabels(l)[key]?.$1 ?? l.nutrientName(key);

/// "8.2 mg", "350 mg": one decimal below 10.
String formatMicro(double v, String unit) => '${v < 10 ? v.toStringAsFixed(1) : v.round()} $unit';

/// "56 g", "1200 mg", "540 kcal".
String formatNutrient(String key, double value, AppLocalizations l) {
  final (n, unit) = formatNutrientParts(key, value, l);
  return '$n $unit';
}

/// "540" and "kcal" apart, for a table that sets the number bigger than the unit. Vitamins and minerals keep a
/// decimal below 10 ("2.4 µg").
(String, String) formatNutrientParts(String key, double value, AppLocalizations l) {
  final unit = nutrientUnit(key);
  final n = nutrients.contains(key) || value >= 10 ? '${value.round()}' : value.toStringAsFixed(1);
  return (n, unit == 'kcal' ? l.kcal : unit);
}

/// Compact nutrient pills ("● 540 kcal", "● 12 g Protein"): a colour dot marks
/// which nutrient, the number and label stay in text colours (readable whatever the hue).
class NutrientTiles extends StatelessWidget {
  const NutrientTiles({super.key, required this.values, this.estimated = false});
  final Nutrients values;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    final labels = nutrientLabels(AppLocalizations.of(context)!);
    final approx = estimated ? '≈' : '';
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in labels.entries)
        if (values[e.key] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.nutrientColor(e.key).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            // One text, not a Row: at 200% text size it wraps instead of overflowing.
            child: Text.rich(TextSpan(children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(color: context.nutrientColor(e.key), shape: BoxShape.circle),
                ),
              ),
              TextSpan(
                  text: '$approx${values[e.key]!.round()}${e.value.$2.isEmpty ? '' : ' ${e.value.$2}'} ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              TextSpan(text: e.value.$1, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            ])),
          ),
    ]);
  }
}

/// A pattern (data/patterns.dart) as the app says it.
String patternText(AppLocalizations l, Pattern p) {
  final a = p.args;
  String n(Object? v) => NumberFormat.decimalPattern(l.localeName).format(v as num);
  String signed(num v) => '${v > 0 ? '+' : ''}${n(v)}';
  return switch (p.kind) {
    'logging' => l.patternLogging(n(a['n']), n(a['days'])),
    'skipped' => l.patternSkipped(mealName(l, a['meal'] as String), n(a['n']), n(a['days'])),
    'late' => l.patternLate('${a['hour']}:00', n(a['n']), n(a['days'])),
    'weekend' => l.patternWeekend(n(a['weekend']), n(a['weekday']), '${signed(a['change'] as num)} %'),
    'gap' => l.patternGap(nutrientName(l, a['nutrient'] as String), n(a['n']), n(a['days'])),
    'weight' => l.patternWeight(signed(a['change'] as num), n(a['kcal'])),
    _ => l.patternSymptom(a['symptom'] as String, a['food'] as String, n(a['n']), n(a['times']), n(a['hours'])),
  };
}

/// A word inside a sentence: "breakfast" — but German nouns keep their capital ("Frühstück").
String inSentence(BuildContext context, String word) =>
    Localizations.localeOf(context).languageCode == 'de' ? word : word.toLowerCase();

/// Privacy policy and terms (GitHub Pages, source in site/).
const legalBase = 'https://partorg.github.io/My_Nutrition_AI';

/// Privacy policy · Terms of use links, for the Me tab and the paywall.
/// 'privacy.html' or 'terms.html' on the project's site, in the browser.
void openLegal(String page) => launchUrl(Uri.parse('$legalBase/$page'), mode: LaunchMode.externalApplication);

Widget legalLinks(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return Wrap(alignment: WrapAlignment.center, children: [
    TextButton(onPressed: () => openLegal('privacy.html'), child: Text(l.privacyPolicy)),
    TextButton(onPressed: () => openLegal('terms.html'), child: Text(l.termsOfUse)),
  ]);
}

/// Display name of a nutri.db condition ('diabetes_t2' → "Type 2 diabetes").
String conditionLabel(String name, AppLocalizations l) => switch (name) {
      'diabetes_t2' => l.condDiabetesT2,
      'hypertension' => l.condHypertension,
      'gout' => l.condGout,
      'als' => l.condAls,
      'ms' => l.condMs,
      _ => conditionFallbackName(name),
    };
