import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../billing/billing.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'chat_screen.dart' show RecipeScreen;
import 'goals_screen.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'period_view.dart';
import 'theme.dart';

/// Nutrients where the goal is a ceiling, not something to reach.
const limitNutrients = {'sugar_g', 'sodium_mg'};

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  var _days = 1; // 1 = today, 7 = week, 30 = month

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final period = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 1, label: Text(l.periodDay)),
          ButtonSegment(value: 7, label: Text(l.periodWeek)),
          ButtonSegment(value: 30, label: Text(l.periodMonth)),
        ],
        selected: {_days},
        onSelectionChanged: (s) => setState(() => _days = s.single),
      ),
    );
    final billing = ref.watch(billingProvider).value;
    return Column(children: [
      period,
      Expanded(
        child: _days == 1
            ? _DayView(data: data)
            : billing == null
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder(
                    valueListenable: billing.tier,
                    builder: (context, tier, _) =>
                        tier.includes(Tier.basic) ? PeriodView(data: data, days: _days) : const _LockedPeriod(),
                  ),
      ),
    ]);
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final l = AppLocalizations.of(context)!;
        final now = DateTime.now();
        final t = currentTargets(data.user, nutri: data.nutri, now: now);
        final targets = t.values;
        final eaten = totalsOn(data.user, now);
        final meals = mealsOn(data.user, now);
        final recipes = data.tools.recentRecipes();
        // Redrawn on return: stars or an "I ate this" there change this screen.
        void open(int id) => Navigator.of(context)
            .push(MaterialPageRoute<void>(
                builder: (_) => RecipeScreen(tools: data.tools, recipeId: id, onLogged: data.changed)))
            .then((_) => data.changed());
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (targets['kcal'] == null)
            _SetGoalsCard(eaten: eaten)
          else
            _CaloriesCard(eaten: eaten['kcal']!, goal: targets['kcal']!),
          if (targets.length > 1)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(children: [
                  for (final key in ['protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg'])
                    if (targets[key] != null)
                      NutrientBar(nutrient: key, eaten: eaten[key]!, goal: targets[key]!, limited: t.limited.containsKey(key)),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Text(l.todaysMeals, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (meals.isEmpty) Text(l.noMealsYet, style: const TextStyle(color: AppColors.textSecondary)),
          for (final type in ['breakfast', 'lunch', 'dinner', 'snack', null])
            if (meals.where((m) => m.type == type).toList() case final group when group.isNotEmpty)
              _MealGroup(type: type, meals: group, onOpen: open, onDelete: (m) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(l.deleteMealTitle),
                    content: Text('${m.label} · ${m.kcal.round()} ${l.kcal}'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
                    ],
                  ),
                );
                if (ok == true) {
                  deleteMeal(data.user, m.id);
                  data.changed();
                }
              }),
          if (recipes.isNotEmpty) _RecipesYouAte(recipes: recipes, onOpen: open),
        ]);
      },
    );
  }
}

class _SetGoalsCard extends StatelessWidget {
  const _SetGoalsCard({required this.eaten});
  final Map<String, double> eaten;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(children: [
      Card(
        color: AppColors.cardGreen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.setGoalsTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.setGoalsBody),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GoalsScreen())),
              child: Text(l.setGoalsButton),
            ),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.eatenToday, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            NutrientTiles(values: eaten),
          ]),
        ),
      ),
    ]);
  }
}

/// Hero figure: calories eaten against the goal.
class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.eaten, required this.goal});
  final double eaten, goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final left = goal - eaten;
    final over = left < 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Wrap, not Row: at large text sizes "of 2759 kcal" moves under the number.
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
            Text('${eaten.round()}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l.eatenOfGoal(goal.round()), style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (eaten / goal).clamp(0, 1),
              minHeight: 8,
              color: over ? Theme.of(context).colorScheme.error : nutrientColors['kcal'],
              backgroundColor: nutrientColors['kcal']!.withValues(alpha: .15),
              // TalkBack: words in the label; the value must stay numeric (Flutter reads the %).
              semanticsLabel: '${l.kcal}: ${eaten.round()} ${l.eatenOfGoal(goal.round())}',
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (over) Icon(Icons.warning_amber_rounded, size: 18, color: Theme.of(context).colorScheme.error),
            if (over) const SizedBox(width: 4),
            Flexible(
              child: Text(over ? l.kcalOver((-left).round()) : l.kcalLeft(left.round()),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class NutrientBar extends StatelessWidget {
  const NutrientBar({super.key, required this.nutrient, required this.eaten, required this.goal, this.limited = false});
  final String nutrient;
  final double eaten, goal;

  /// A condition caps this nutrient, so its goal is a ceiling too.
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final limit = limited || limitNutrients.contains(nutrient);
    final over = limit && eaten > goal;
    final color = nutrientColors[nutrient]!;
    final name = nutrientLabels(l)[nutrient]!.$1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Flexible(
            child: Text(
              '${formatNutrient(nutrient, eaten, l)} / ${limit ? '${l.limitSuffix} ' : ''}${formatNutrient(nutrient, goal, l)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.end,
            ),
          ),
        ]),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (eaten / goal).clamp(0, 1),
            minHeight: 5,
            color: over ? Theme.of(context).colorScheme.error : color,
            backgroundColor: color.withValues(alpha: .15),
            semanticsLabel: '$name: ${formatNutrient(nutrient, eaten, l)} / ${formatNutrient(nutrient, goal, l)}',
          ),
        ),
        // Own line: next to the values it overflows narrow phones.
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 4),
              Flexible(
                child: Text(l.overBy(formatNutrient(nutrient, eaten - goal, l)),
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _MealGroup extends StatelessWidget {
  const _MealGroup({required this.type, required this.meals, required this.onDelete, required this.onOpen});
  final String? type;
  final List<MealEntry> meals;
  final ValueChanged<MealEntry> onDelete;
  final ValueChanged<int> onOpen; // a recipe id

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = switch (type) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'dinner' => l.mealDinner,
      _ => l.mealSnack,
    };
    final kcal = meals.fold(0.0, (s, m) => s + m.kcal);
    return Card(
      child: Column(children: [
        ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: Text('${kcal.round()} ${l.kcal}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        for (final m in meals)
          ListTile(
            dense: true,
            leading: m.recipeId == null ? null : const Icon(Icons.menu_book_outlined, color: AppColors.primary),
            onTap: m.recipeId == null ? null : () => onOpen(m.recipeId!),
            title: Text(m.label),
            subtitle: Text([
              DateFormat.Hm().format(m.at),
              if (m.grams != null) '${m.grams!.round()} g',
            ].join(' · ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${m.estimated ? '≈' : ''}${m.kcal.round()} ${l.kcal}'),
              IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => onDelete(m)),
            ]),
          ),
      ]),
    );
  }
}

/// The newest recipes logged as eaten, with their stars; a tap opens one to rate it.
class _RecipesYouAte extends StatelessWidget {
  const _RecipesYouAte({required this.recipes, required this.onOpen});
  final List<({int id, String title, DateTime at, int? stars})> recipes;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          title: Text(l.recipesYouAte, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(l.recipesYouAteHint),
        ),
        for (final r in recipes)
          ListTile(
            dense: true,
            leading: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(DateFormat('EEE d MMM').format(r.at)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r.stars == null ? '☆' : '★' * r.stars!, style: TextStyle(color: Colors.amber.shade700)),
              const Icon(Icons.chevron_right),
            ]),
            onTap: () => onOpen(r.id),
          ),
      ]),
    );
  }
}

/// Free tier: what Week/Month would show, and a way to the plans.
class _LockedPeriod extends StatelessWidget {
  const _LockedPeriod();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: AppColors.cardGreen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.insights, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(l.lockedTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.lockedBody),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
              child: Text(l.seePlans),
            ),
          ]),
        ),
      ),
    ]);
  }
}
