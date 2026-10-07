import 'dart:async';

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
import 'home_screen.dart' show HomeTab, homeTabProvider;
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'plan_screen.dart';
import '../data/plan.dart';
import '../data/health_sync.dart' show healthSyncOn, stepsToday;
import 'period_view.dart';
import 'theme.dart';

/// Today's planned meals, and the way into the plan and shopping list.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final today = [for (final p in plannedMealsFor(data.tools, DateTime.now(), days: 1)) p.title];
    return Card(
      child: ListTile(
        leading: Icon(Icons.event_note_outlined, color: context.colors.primary),
        title: Text(l.mealPlan, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(today.isEmpty ? l.planCardEmpty : today.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => PlanScreen(data: data)))
            .then((_) => data.changed()),
      ),
    );
  }
}

/// Today's water against the goal; "+" adds a glass, undo takes the last one back.
class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final ml = waterOn(data.user, now), goal = waterGoal(data.user);
    const blue = Color(0xFF2A78D6); // the kcal slot of the palette: readable on light and dark
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          const Icon(Icons.water_drop_outlined, color: blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.waterLine(ml.round(), goal.round()), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (ml / goal).clamp(0, 1),
                  minHeight: 5,
                  color: blue,
                  backgroundColor: blue.withValues(alpha: .15),
                  semanticsLabel: l.waterLine(ml.round(), goal.round()),
                ),
              ),
            ]),
          ),
          if (ml > 0)
            IconButton(
              tooltip: l.waterUndo,
              icon: const Icon(Icons.undo),
              onPressed: () {
                undoWater(data.user, now);
                data.changed();
              },
            ),
          IconButton.filledTonal(
            tooltip: l.waterAddGlass,
            icon: const Icon(Icons.add),
            onPressed: () {
              logWater(data.user, glassMl, DateTime.now());
              data.changed();
            },
          ),
        ]),
      ),
    );
  }
}

/// Opt-in (Me tab): a running fast against its target, or how to start one.
class _FastCard extends StatefulWidget {
  const _FastCard({required this.data});
  final ProfileData data;

  @override
  State<_FastCard> createState() => _FastCardState();
}

class _FastCardState extends State<_FastCard> {
  Timer? _tick;
  late int _hours = int.tryParse(pref(widget.data.user, 'fast_hours') ?? '') ?? 16;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _start(DateTime at) {
    setPref(widget.data.user, 'fast_hours', '$_hours');
    startFast(widget.data.user, at, _hours);
    widget.data.changed();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = widget.data.user;
    final fast = currentFast(user);
    final now = DateTime.now();
    final color = nutrientColors['sodium_mg']!;
    if (fast != null) {
      final gone = now.difference(fast.start);
      final done = gone.inMinutes >= fast.targetHours * 60;
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.timer_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.fastingLine(gone.inHours, gone.inMinutes % 60, fast.targetHours),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () {
                  endFast(user, DateTime.now());
                  widget.data.changed();
                },
                child: Text(l.fastEnd),
              ),
            ]),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (gone.inMinutes / (fast.targetHours * 60)).clamp(0, 1),
                minHeight: 5,
                color: color,
                backgroundColor: color.withValues(alpha: .15),
                semanticsLabel: l.fastingLine(gone.inHours, gone.inMinutes % 60, fast.targetHours),
              ),
            ),
            if (done) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.fastDone)),
          ]),
        ),
      );
    }
    final last = lastMealAt(user);
    final sinceMeal = last != null && now.difference(last).inHours < 24 ? last : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.timer_outlined, color: color),
            const SizedBox(width: 12),
            Text(l.fasting, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final h in [12, 14, 16, 18])
              ChoiceChip(label: Text('$h h'), selected: _hours == h, onSelected: (_) => setState(() => _hours = h)),
          ]),
          Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
            if (sinceMeal != null)
              TextButton(onPressed: () => _start(sinceMeal), child: Text(l.fastSinceMeal(DateFormat.Hm().format(sinceMeal)))),
            TextButton(onPressed: () => _start(DateTime.now()), child: Text(l.fastStart)),
          ]),
        ]),
      ),
    );
  }
}

String _mealName(AppLocalizations l, String type) => switch (type) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'dinner' => l.mealDinner,
      _ => l.mealSnack,
    };

/// A nudge with the two ways forward: log it, or ask the assistant for an idea.
class _NextStep extends ConsumerWidget {
  const _NextStep({required this.title, required this.body, required this.meal});
  final String title, body, meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tab = ref.read(homeTabProvider.notifier);
    return Card(
      color: context.colors.cardGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
          Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
            TextButton.icon(
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(l.getIdea),
              onPressed: () {
                tab.go(HomeTab.chat);
                // Sent once the assistant is loaded; before that the tab shows its progress.
                ref.read(agentProvider).value?.send(l.suggestIdea(inSentence(context, _mealName(l, meal))));
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: Text(l.logIt),
              onPressed: () => tab.go(HomeTab.log),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Macros shown as rings next to calories (the others are bars).
const _ringed = ['protein_g', 'carbs_g', 'fat_g'];

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
        final nowType = data.tools.mealTypeNow();
        return ListView(padding: const EdgeInsets.all(16), children: [
          // Day one: how to log. Later: the main meal of this hour, if it isn't logged yet.
          if (data.user.select('SELECT 1 FROM meal_log LIMIT 1').isEmpty)
            _NextStep(title: l.welcomeTitle, body: l.welcomeBody, meal: nowType)
          else if (nowType != 'snack' && !meals.any((m) => m.type == nowType))
            _NextStep(title: l.nextMealTitle(inSentence(context, _mealName(l, nowType))), body: l.nextMealBody, meal: nowType),
          if (targets['kcal'] == null)
            _SetGoalsCard(eaten: eaten)
          else
            _CaloriesCard(eaten: eaten['kcal']!, goal: targets['kcal']!, macros: {
              // Rings for the macros the user aims at; ceilings (a condition's limit) stay bars with warnings.
              for (final key in _ringed)
                if (targets[key] != null && !t.limited.containsKey(key)) key: (eaten[key]!, targets[key]!),
            }),
          if (targets.keys.any((k) => k != 'kcal' && !(_ringed.contains(k) && !t.limited.containsKey(k))))
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(children: [
                  for (final key in ['protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg'])
                    if (targets[key] != null && !(_ringed.contains(key) && !t.limited.containsKey(key)))
                      NutrientBar(nutrient: key, eaten: eaten[key]!, goal: targets[key]!, limited: t.limited.containsKey(key)),
                ]),
              ),
            ),
          _WaterCard(data: data),
          if (healthSyncOn(data.user))
            FutureBuilder(
              future: stepsToday(data.user),
              builder: (context, snap) => snap.data == null
                  ? const SizedBox.shrink()
                  : Card(
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.directions_walk, color: context.colors.primary),
                        title: Text(l.stepsToday(NumberFormat.decimalPattern().format(snap.data))),
                      ),
                    ),
            ),
          _PlanCard(data: data),
          if (pref(data.user, 'fasting') == '1') _FastCard(data: data),
          const SizedBox(height: 8),
          Text(l.todaysMeals, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (meals.isEmpty) Text(l.noMealsYet, style: TextStyle(color: context.colors.textSecondary)),
          for (final type in ['breakfast', 'lunch', 'dinner', 'snack', null])
            if (meals.where((m) => m.type == type).toList() case final group when group.isNotEmpty)
              _MealGroup(type: type, meals: group, onOpen: open, onEdit: (m) async {
                final changed = await showModalBottomSheet<bool>(
                    context: context, isScrollControlled: true, builder: (_) => _EditMealSheet(meal: m, data: data));
                if (changed == true) data.changed();
              }, onDelete: (m) async {
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
        color: context.colors.cardGreen,
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

/// Hero: a calorie ring (eaten of the goal) and small rings for the macros that have goals.
class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.eaten, required this.goal, required this.macros});
  final double eaten, goal;
  final Map<String, (double eaten, double goal)> macros;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final left = goal - eaten;
    final over = left < 0;
    final error = Theme.of(context).colorScheme.error;
    final kcalColor = nutrientColors['kcal']!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Wrap, not Row: at large text sizes the macro rings move under the calorie ring.
          Wrap(spacing: 20, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox.square(
              dimension: 132,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (eaten / goal).clamp(0, 1),
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    color: over ? error : kcalColor,
                    backgroundColor: kcalColor.withValues(alpha: .15),
                    // TalkBack: words in the label; the value must stay numeric (Flutter reads the %).
                    semanticsLabel: '${l.kcal}: ${eaten.round()} ${l.eatenOfGoal(goal.round())}',
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(
                    child: Text('${eaten.round()}',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  ),
                  FittedBox(
                    child: Text(l.eatenOfGoal(goal.round()),
                        style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                  ),
                ]),
              ]),
            ),
            if (macros.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                for (final MapEntry(key: k, value: (e, g)) in macros.entries) _MacroRing(nutrient: k, eaten: e, goal: g),
              ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (over) Icon(Icons.warning_amber_rounded, size: 18, color: error),
            if (over) const SizedBox(width: 4),
            Flexible(
              child: Text(over ? l.kcalOver((-left).round()) : l.kcalLeft(left.round()),
                  style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({required this.nutrient, required this.eaten, required this.goal});
  final String nutrient;
  final double eaten, goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = nutrientColors[nutrient]!;
    final name = nutrientLabels(l)[nutrient]!.$1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(
            value: (eaten / goal).clamp(0, 1),
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.withValues(alpha: .15),
            semanticsLabel: '$name: ${formatNutrient(nutrient, eaten, l)} / ${formatNutrient(nutrient, goal, l)}',
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$name ', style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            TextSpan(text: '${eaten.round()} / ${formatNutrient(nutrient, goal, l)}',
                style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          ])),
        ),
      ]),
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
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
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
  const _MealGroup(
      {required this.type, required this.meals, required this.onDelete, required this.onOpen, required this.onEdit});
  final String? type;
  final List<MealEntry> meals;
  final ValueChanged<MealEntry> onDelete, onEdit;
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
            leading: m.recipeId == null ? null : Icon(Icons.menu_book_outlined, color: context.colors.primary),
            // A recipe opens (to see and rate it); anything else edits. Long press always edits.
            onTap: m.recipeId == null ? () => onEdit(m) : () => onOpen(m.recipeId!),
            onLongPress: () => onEdit(m),
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

/// Fix a logged meal: amount (nutrition scales with it) and which meal it was.
class _EditMealSheet extends StatefulWidget {
  const _EditMealSheet({required this.meal, required this.data});
  final MealEntry meal;
  final ProfileData data;

  @override
  State<_EditMealSheet> createState() => _EditMealSheetState();
}

class _EditMealSheetState extends State<_EditMealSheet> {
  late final _grams = TextEditingController(text: widget.meal.grams?.round().toString() ?? '');
  late String _type = widget.meal.type ?? 'snack';

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final m = widget.meal;
    final grams = double.tryParse(_grams.text.replaceAll(',', '.'));
    final kcal = m.grams == null || grams == null || m.grams == 0 ? m.kcal : m.kcal * grams / m.grams!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.editMeal, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(m.label),
        const SizedBox(height: 12),
        // Quick adds have no grams: only the meal can change.
        if (m.grams != null)
          TextField(
            controller: _grams,
            decoration: InputDecoration(labelText: l.grams, suffixText: 'g'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'breakfast', label: Text(l.mealBreakfast)),
            ButtonSegment(value: 'lunch', label: Text(l.mealLunch)),
            ButtonSegment(value: 'dinner', label: Text(l.mealDinner)),
            ButtonSegment(value: 'snack', label: Text(l.mealSnack)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.single),
        ),
        const SizedBox(height: 12),
        Text('${m.estimated ? '≈' : ''}${kcal.round()} ${l.kcal}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: Text(l.confirmSave),
            onPressed: m.grams != null && (grams == null || grams <= 0 || grams > 5000)
                ? null
                : () {
                    updateMeal(widget.data.user, m.id, grams: grams, type: _type);
                    Navigator.pop(context, true);
                  },
          ),
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
            leading: Icon(Icons.menu_book_outlined, color: context.colors.primary),
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
        color: context.colors.cardGreen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.insights, color: context.colors.primary, size: 32),
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
