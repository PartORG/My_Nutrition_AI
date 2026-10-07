import 'package:flutter/material.dart';
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

/// "56 g", "1200 mg", "540 kcal".
String formatNutrient(String key, double value, AppLocalizations l) {
  final unit = nutrientLabels(l)[key]!.$2;
  return '${value.round()} ${unit.isEmpty ? l.kcal : unit}';
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
Widget legalLinks(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  void open(String page) => launchUrl(Uri.parse('$legalBase/$page'), mode: LaunchMode.externalApplication);
  return Wrap(alignment: WrapAlignment.center, children: [
    TextButton(onPressed: () => open('privacy.html'), child: Text(l.privacyPolicy)),
    TextButton(onPressed: () => open('terms.html'), child: Text(l.termsOfUse)),
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
