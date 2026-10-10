import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent_tools.dart';
import '../data/conditions.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Display name and unit per nutrient key.
Map<String, (String, String)> nutrientLabels(AppLocalizations l) => {
      'kcal': (l.kcal, ''), 'protein_g': (l.protein, 'g'), 'fat_g': (l.fat, 'g'), 'carbs_g': (l.carbs, 'g'),
      'fiber_g': (l.fiber, 'g'), 'sugar_g': (l.sugar, 'g'), 'sodium_mg': (l.sodium, 'mg'),
    };

/// Display name and unit per micronutrient key.
Map<String, (String, String)> microLabels(AppLocalizations l) => {
      'calcium_mg': (l.calcium, 'mg'), 'iron_mg': (l.iron, 'mg'), 'magnesium_mg': (l.magnesium, 'mg'),
      'potassium_mg': (l.potassium, 'mg'), 'vitamin_c_mg': (l.vitaminC, 'mg'), 'vitamin_d_ug': (l.vitaminD, 'µg'),
      'vitamin_b12_ug': (l.vitaminB12, 'µg'),
    };

/// EU reference intakes for adults (Regulation 1169/2011, Annex XIII), the "%" on labels.
const microReference = {
  'calcium_mg': 800.0, 'iron_mg': 14.0, 'magnesium_mg': 375.0, 'potassium_mg': 2000.0,
  'vitamin_c_mg': 80.0, 'vitamin_d_ug': 5.0, 'vitamin_b12_ug': 2.5,
};

/// "8.2 mg", "350 mg": one decimal below 10.
String formatMicro(double v, String unit) => '${v < 10 ? v.toStringAsFixed(1) : v.round()} $unit';

/// "56 g", "1200 mg", "540 kcal".
String formatNutrient(String key, double value, AppLocalizations l) {
  final (n, unit) = formatNutrientParts(key, value, l);
  return '$n $unit';
}

/// "540" and "kcal" apart, for a table that sets the number bigger than the unit.
(String, String) formatNutrientParts(String key, double value, AppLocalizations l) {
  final unit = nutrientLabels(l)[key]!.$2;
  return ('${value.round()}', unit.isEmpty ? l.kcal : unit);
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
              color: nutrientColors[e.key]!.withValues(alpha: .10),
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
                  decoration: BoxDecoration(color: nutrientColors[e.key], shape: BoxShape.circle),
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

/// A word inside a sentence: "breakfast" — but German nouns keep their capital ("Frühstück").
String inSentence(BuildContext context, String word) =>
    Localizations.localeOf(context).languageCode == 'de' ? word : word.toLowerCase();

/// Privacy policy and terms (GitHub Pages, source in site/).
const legalBase = 'https://partorg.github.io/myfoodmind';

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
