import 'package:flutter/material.dart';

import '../agent/agent_tools.dart';
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

/// Nutrient tiles: a colour bar marks which nutrient, the number and label
/// stay in text colours (readable whatever the hue).
class NutrientTiles extends StatelessWidget {
  const NutrientTiles({super.key, required this.values, this.estimated = false});
  final Nutrients values;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    final labels = nutrientLabels(AppLocalizations.of(context)!);
    final approx = estimated ? '≈' : '';
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in labels.entries)
        if (values[e.key] != null)
          Container(
            // Min, not fixed: at 200% text size a fixed width clips the numbers.
            constraints: const BoxConstraints(minWidth: 92),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            // Not a one-sided Border: Flutter asserts on non-uniform borders with a radius.
            decoration: BoxDecoration(
              color: nutrientColors[e.key]!.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: MergeSemantics(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('$approx${values[e.key]!.round()}${e.value.$2.isEmpty ? '' : ' ${e.value.$2}'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: nutrientColors[e.key], shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(child: Text(e.value.$1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ])),
          ),
    ]);
  }
}
