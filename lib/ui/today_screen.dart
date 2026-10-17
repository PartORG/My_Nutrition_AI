import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../agent/agent_tools.dart' show FoodChoice;
import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/health_sync.dart' show disconnectHealth, healthSyncOn, stepsToday, syncActiveKcal, syncHealthWeights;
import '../data/plan.dart';
import '../l10n/app_localizations.dart';
import 'recipe_screen.dart' show RecipeScreen;
import 'goals_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart' show HomeTab, homeTabProvider;
import 'kit.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'period_view.dart';
import 'theme.dart';
import 'weight_screen.dart';
import 'year_view.dart';

String mealName(AppLocalizations l, String type) => switch (type) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'dinner' => l.mealDinner,
      _ => l.mealSnack,
    };

/// Nutrients where the goal is a ceiling, not something to reach.
const limitNutrients = {'sugar_g', 'sodium_mg'};

/// Macros shown as bars on the hero card (the others get their own card).
const _heroMacros = ['protein_g', 'carbs_g', 'fat_g'];

String _n(BuildContext context, num v) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(v.round());

/// Today · Week · Month · Year: the dashboard tab.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  var _days = 1; // 1 = today, 7 = week, 30 = month, 365 = year (Pro)

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final (overline, title) = switch (_days) {
      1 => (DateFormat.MMMMEEEEd(locale).format(now), l.hello(widget.name)),
      7 => (_range(locale, now.subtract(const Duration(days: 6)), now), l.yourWeek),
      30 => (_range(locale, now.subtract(const Duration(days: 29)), now), l.yourMonth),
      _ => ('${now.year}', l.yourYear),
    };
    final streak = loggingStreak(data.user, now);
    final header = ScreenHeader(
      overline: overline,
      title: title,
      size: _days == 1 ? 28 : 34,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_days == 365) const Tag('PRO', tone: TagTone.gold, big: true),
        if (_days == 1 && streak > 0)
          Semantics(
            label: l.streakDays(streak),
            excludeSemantics: true,
            child: Tag('$streak', tone: TagTone.warm, icon: Icons.local_fire_department, big: true),
          ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.lock_outline,
          tooltip: l.lock,
          onPressed: () => ref.read(unlockedProvider.notifier).lock(),
        ),
      ]),
    );
    final tabs = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: PillTabs<int>(
        values: const [1, 7, 30, 365],
        selected: _days,
        label: (d) => switch (d) { 1 => l.periodDay, 7 => l.periodWeek, 30 => l.periodMonth, _ => l.periodYear },
        onChanged: (d) => setState(() => _days = d),
      ),
    );
    return Column(children: [
      // Chrome at most 1.5× text: at 200 % the header and tabs would leave the content no room.
      MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: Column(children: [header, tabs])),
      Expanded(
        child: _days == 1
            ? _DayView(data: data)
            : TierBuilder(
                builder: (context, tier) => _days < 365
                    ? PeriodView(data: data, days: _days, basic: tier.includes(Tier.basic))
                    : tier.includes(Tier.pro)
                        ? YearView(data: data)
                        : ListView(padding: const EdgeInsets.all(20), children: [
                            LockedCard(icon: Icons.calendar_month, title: l.yearLockedTitle, body: l.yearLockedBody),
                          ]),
              ),
      ),
    ]);
  }

  /// "10–16 October"; across months "28 Sep – 4 Oct".
  static String _range(String locale, DateTime a, DateTime b) => a.month == b.month
      ? '${a.day}–${b.day} ${DateFormat.MMMM(locale).format(b)}'
      : '${DateFormat.d(locale).format(a)} ${DateFormat.MMM(locale).format(a)} – ${DateFormat.d(locale).format(b)} ${DateFormat.MMM(locale).format(b)}';
}

class _DayView extends ConsumerWidget {
  const _DayView({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final planned = {for (final p in plannedMealsFor(data.tools, now, days: 1)) p.mealType: p};
        // Redrawn on return: stars or an "I ate this" there change this screen.
        void open(int id) => Navigator.of(context)
            .push(MaterialPageRoute<void>(
                builder: (_) => RecipeScreen(tools: data.tools, recipeId: id, onLogged: data.changed)))
            .then((_) => data.changed());
        Future<void> edit(MealEntry m) async {
          final changed = await showModalBottomSheet<bool>(
              context: context, isScrollControlled: true, builder: (_) => _EditMealSheet(meal: m, data: data));
          if (changed == true) data.changed();
        }

        final left = targets['kcal'] == null ? null : targets['kcal']! - eaten['kcal']!;
        final firstDay = data.user.select('SELECT 1 FROM meal_log LIMIT 1').isEmpty;
        final otherBars = [
          for (final key in ['protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg'])
            if (targets[key] != null && !_heroMacros.contains(key)) key,
        ];
        final fasting = pref(data.user, 'fasting') == '1';
        final aiReady = switch (ref.watch(agentProvider)) {
          AsyncError(error: LlmNotDownloaded()) => false,
          _ => true,
        };
        return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          if (firstDay) ...[
            // Only the ways that work now: Chat once the AI is downloaded, photos with Pro.
            TierBuilder(
              builder: (context, tier) => _NextStep(
                title: l.welcomeTitle,
                body: [
                  l.welcomeLog,
                  if (aiReady) l.welcomeChat,
                  if (tier.includes(Tier.pro)) l.welcomePhoto,
                  l.welcomeEnd,
                ].join(' '),
                meal: data.tools.mealTypeNow(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!aiReady && ref.watch(llmDownloadProvider) == null && pref(data.user, _aiCardHidden) != '1') ...[
            _AiCard(onLater: () {
              setPref(data.user, _aiCardHidden, '1');
              data.changed();
            }),
            const SizedBox(height: 12),
          ],
          if (targets['kcal'] == null)
            _SetGoalsCard(eaten: eaten)
          else
            _HeroCard(
              eaten: eaten,
              targets: targets,
              limited: t.limited.keys.toSet(),
              estimated: meals.any((m) => m.estimated),
              burned: healthSyncOn(data.user) ? activeKcalOn(data.user, now) : null,
            ),
          if (otherBars.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(children: [
                for (final key in otherBars)
                  NutrientBar(nutrient: key, eaten: eaten[key]!, goal: targets[key]!, limited: t.limited.containsKey(key)),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          for (final type in ['breakfast', 'lunch', 'dinner', 'snack']) ...[
            _MealCard(
              type: type,
              meals: [for (final m in meals) if ((m.type ?? 'snack') == type) m],
              planned: planned[type],
              left: left,
              data: data,
              onOpen: open,
              onEdit: edit,
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => HistoryScreen(data: data)))
                  .then((_) => data.changed()),
              child: Text('${l.historyTitle} ›'),
            ),
          ),
          const SizedBox(height: 6),
          // The small daily numbers in one block: water, fasting, steps, weight.
          _TileRow(children: [
            _WaterTile(data: data),
            if (fasting) _FastTile(data: data),
            if (healthSyncOn(data.user)) _StepsTile(data: data),
            WeightTile(data: data),
          ]),
          if (meals.isNotEmpty)
            TierBuilder(
                builder: (_, tier) => tier.includes(Tier.basic)
                    ? Padding(padding: const EdgeInsets.only(top: 12), child: _MicrosRow(data: data))
                    : const SizedBox.shrink()),
          if (recipes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RecipesYouAte(recipes: recipes, onOpen: open),
          ],
        ]);
      },
    );
  }
}

/// Two small cards side by side (water, fasting, steps); one alone fills the row.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // 200 % text: the tiles stack instead of squeezing.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 15;
    if (children.length == 1 || stacked) {
      return Column(children: [
        for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), w],
      ]);
    }
    return Column(children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
          ]),
        ),
      ],
    ]);
  }
}

/// On the green hero: over the goal (not the gold of Pro), and the burnt ring (blue, apart from white in lightness too).
const _overColor = Color(0xFFFFA28A);
const _burntColor = Color(0xFF8FD3FF);

/// The green hero: a ring of calories left, the macro bars, and Goal − Eaten = Left.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.eaten, required this.targets, required this.limited, this.estimated = false, this.burned});
  final Map<String, double> eaten;
  final Map<String, double?> targets;
  final Set<String> limited;

  /// Some of today's meals are estimates (chat, photo, dishes): the totals get "≈".
  final bool estimated;

  /// Active calories from the health app, the inner ring; null = not connected. Never in the goal.
  final double? burned;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final goal = targets['kcal']!, ate = eaten['kcal']!;
    final left = goal - ate;
    final over = left < 0;
    final approx = estimated ? '≈ ' : '';
    final burned = this.burned;
    const white = Colors.white;
    final soft = white.withValues(alpha: .18);
    final ring = SizedBox.square(
      dimension: 128,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: (ate / goal).clamp(0, 1),
            strokeWidth: 12,
            strokeCap: StrokeCap.round,
            color: over ? _overColor : white,
            backgroundColor: soft,
            // TalkBack: words in the label; the value must stay numeric (Flutter reads the %).
            semanticsLabel: '${l.kcal}: ${ate.round()} ${l.eatenOfGoal(goal.round())}',
          ),
        ),
        // Inside, in its own colour: what the health app says was burnt, against a daily activity target.
        if (burned != null)
          SizedBox.square(
            dimension: 98,
            child: CircularProgressIndicator(
              value: (burned / activeKcalTarget).clamp(0, 1),
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: _burntColor,
              backgroundColor: soft,
              semanticsLabel: l.activeKcalBurned('${burned.round()}'),
            ),
          ),
        Padding(
          padding: EdgeInsets.all(burned == null ? 16 : 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            child: Text('$approx${_n(context, left.abs())}',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: white,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          FittedBox(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (over) ...[const Icon(Icons.warning_amber_rounded, size: 14, color: _overColor), const SizedBox(width: 3)],
              Text(over ? l.kcalOverShort : l.kcalLeftShort, style: TextStyle(fontSize: 12, color: white.withValues(alpha: .85))),
            ]),
          ),
        ]),
        ),
      ]),
    );
    final bars = [
      for (final k in _heroMacros)
        if (targets[k] != null) _HeroBar(nutrient: k, eaten: eaten[k]!, goal: targets[k]!, limited: limited.contains(k)),
    ];
    Widget sum(String value, String label) => Expanded(
          child: Column(children: [
            FittedBox(
              child: Text(value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: white,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: white.withValues(alpha: .85))),
          ]),
        );
    return Semantics(
      container: true,
      label: l.calories,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: heroGradient(c), borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          // Wrap, not Row: at large text sizes the bars move under the ring.
          LayoutBuilder(
            builder: (context, box) => box.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(10) > 15
                ? Column(children: [ring, if (bars.isNotEmpty) ...[const SizedBox(height: 16), ...bars]])
                : Row(children: [
                    ring,
                    const SizedBox(width: 20),
                    Expanded(child: Column(children: bars)),
                  ]),
          ),
          const SizedBox(height: 16),
          Divider(color: soft, height: 1),
          const SizedBox(height: 12),
          Row(children: [
            sum(_n(context, goal), l.goal),
            sum('− $approx${_n(context, ate)}', l.eatenWord),
            sum('= $approx${over ? '−' : ''}${_n(context, left.abs())}', l.leftWord),
            if (burned != null) ...[
              Container(width: 1, height: 32, color: soft),
              Expanded(
                child: Column(children: [
                  FittedBox(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: _burntColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(_n(context, burned),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: white,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
                  ),
                  Text(l.burntWord, style: TextStyle(fontSize: 12, color: white.withValues(alpha: .85))),
                ]),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _HeroBar extends StatelessWidget {
  const _HeroBar({required this.nutrient, required this.eaten, required this.goal, required this.limited});
  final String nutrient;
  final double eaten, goal;
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = nutrientLabels(l)[nutrient]!.$1;
    final over = limited && eaten > goal;
    const white = Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: white))),
          if (over) ...[Icon(Icons.warning_amber_rounded, size: 14, color: context.colors.gold), const SizedBox(width: 4)],
          Text('${eaten.round()} / ${limited ? '${l.limitSuffix} ' : ''}${formatNutrient(nutrient, goal, l)}',
              style: const TextStyle(fontSize: 13, color: white, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 4),
        Bar(
          value: eaten / goal,
          height: 6,
          color: heroMacroColors[nutrient],
          track: white.withValues(alpha: .18),
          label: '$name: ${formatNutrient(nutrient, eaten, l)} / ${formatNutrient(nutrient, goal, l)}',
        ),
      ]),
    );
  }
}

/// A nutrient against its goal (or ceiling) on the plain cards: dot, name, values, bar.
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
    final danger = context.colors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Flexible(
            child: Text(
              '${formatNutrient(nutrient, eaten, l)} / ${limit ? '${l.limitSuffix} ' : ''}${formatNutrient(nutrient, goal, l)}',
              style: TextStyle(fontSize: 13, color: context.colors.muted),
              textAlign: TextAlign.end,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Bar(
          value: eaten / goal,
          height: 6,
          color: over ? danger : color,
          track: color.withValues(alpha: .15),
          label: '$name: ${formatNutrient(nutrient, eaten, l)} / ${formatNutrient(nutrient, goal, l)}',
        ),
        // Own line: next to the values it overflows narrow phones.
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: danger),
              const SizedBox(width: 4),
              Flexible(child: Text(l.overBy(formatNutrient(nutrient, eaten - goal, l)), style: TextStyle(color: danger, fontSize: 12))),
            ]),
          ),
      ]),
    );
  }
}

/// One meal: its items with kcal, a + that opens Log on this meal, and today's planned recipe for it.
/// An empty snack (or any empty meal without a plan) is a dashed "+ Add".
class _MealCard extends ConsumerWidget {
  const _MealCard({required this.type, required this.meals, required this.planned, required this.left,
      required this.data, required this.onOpen, required this.onEdit});
  final String type;
  final List<MealEntry> meals;
  final Planned? planned;
  final double? left;
  final ProfileData data;
  final ValueChanged<int> onOpen;
  final ValueChanged<MealEntry> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final name = mealName(l, type);
    void add() => ref.read(homeTabProvider.notifier).logMeal(type);
    final plan = meals.isEmpty ? planned : null;
    final (color, icon) = mealStyles[type]!;
    final badge = ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
    if (meals.isEmpty && plan == null) {
      return DashedAdd(
        onTap: add,
        child: Row(children: [
          badge,
          Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          Flexible(child: Text(l.addShort, style: TextStyle(fontSize: 15, color: c.primary, fontWeight: FontWeight.w600))),
        ]),
      );
    }
    final kcal = meals.fold(0.0, (s, m) => s + m.kcal);
    return Panel(
      padding: EdgeInsets.zero,
      color: tint(context, color),
      border: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(children: [
            badge,
            Expanded(child: Semantics(header: true, child: Text(name, style: Theme.of(context).textTheme.titleMedium))),
            Flexible(
              child: Text(plan != null ? l.fromYourPlan : '${_n(context, kcal)} ${l.kcal}',
                  textAlign: TextAlign.end, style: TextStyle(fontSize: 14, color: plan != null ? c.muted : c.ink2)),
            ),
            IconButton(
              tooltip: l.addToMeal(name),
              icon: Icon(Icons.add_circle_outline, color: c.primary),
              onPressed: add,
            ),
          ]),
        ),
        for (final (i, m) in meals.indexed) ...[
          if (i > 0) Divider(color: c.divider),
          InkWell(
            // A recipe opens (to see and rate it); anything else edits. Long press always edits.
            onTap: m.recipeId == null ? () => onEdit(m) : () => onOpen(m.recipeId!),
            onLongPress: () => onEdit(m),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(children: [
                  if (m.recipeId != null) ...[
                    Icon(Icons.menu_book_outlined, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.label, style: const TextStyle(fontSize: 15)),
                      Text(
                          [DateFormat.Hm().format(m.at), if (m.grams != null) '${m.estimated ? '≈ ' : ''}${m.grams!.round()} g']
                              .join(' · '),
                          style: TextStyle(fontSize: 12, color: c.muted)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('${m.estimated ? '≈' : ''}${_n(context, m.kcal)}',
                      style: TextStyle(fontSize: 14, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
          ),
        ],
        if (plan != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Material(
              color: c.warm,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onOpen(plan.recipeId),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(plan.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink)),
                        Text(_planLine(context, l, plan), style: TextStyle(fontSize: 12, color: c.onWarm)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(l.cook, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.onWarm)),
                  ]),
                ),
              ),
            ),
          ),
        if (meals.isNotEmpty) const SizedBox(height: 6),
      ]),
    );
  }

  String _planLine(BuildContext context, AppLocalizations l, Planned p) {
    final minutes = data.nutri.select('SELECT minutes FROM recipes WHERE id = ?', [p.recipeId]).firstOrNull?['minutes'] as int?;
    return [
      '${_n(context, p.kcal)} ${l.kcal}',
      if (minutes != null && minutes > 0) l.minutesShort(minutes),
      if (left != null && left! >= p.kcal) l.fitsLeft(_n(context, left!)),
    ].join(' · ');
  }
}

/// Today's water: litres against the goal as glasses; + adds a glass (with Undo on the snackbar).
class _WaterTile extends StatelessWidget {
  const _WaterTile({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final ml = waterOn(data.user, DateTime.now()), goal = waterGoal(data.user);
    final glasses = (goal / glassMl).round().clamp(1, 16), had = (ml / glassMl).floor();
    String litres(double v) => (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 2).replaceFirst(RegExp(r'0$'), '');
    return Panel(
      radius: Radii.tile,
      padding: const EdgeInsets.all(12),
      color: c.waterBg,
      border: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(l.water, style: TextStyle(fontSize: 13, color: c.muted))),
          Tooltip(
            message: l.waterAddGlass,
            child: Material(
              color: c.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  logWater(data.user, glassMl, DateTime.now());
                  data.changed();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(l.glassAdded),
                      persist: false, // an action makes it stay forever by default
                      action: SnackBarAction(
                          label: l.undo,
                          onPressed: () {
                            undoWater(data.user, DateTime.now());
                            data.changed();
                          }),
                    ));
                },
                child: SizedBox.square(
                    dimension: 48,
                    child: Semantics(label: l.waterAddGlass, button: true, child: Icon(Icons.add, color: c.water))),
              ),
            ),
          ),
        ]),
        Semantics(
          container: true, // its own node, not merged into the tile's other text
          label: l.waterLine(ml.round(), goal.round()),
          excludeSemantics: true,
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: litres(ml),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            TextSpan(text: ' / ${litres(goal)} ${l.litreUnit}', style: TextStyle(fontSize: 13, color: c.muted)),
          ])),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(children: [
            for (var i = 0; i < glasses; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: i < had ? c.water : c.water.withValues(alpha: .2), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Opt-in (Settings): a running fast against its target; tap to end it, or to start one.
class _FastTile extends StatefulWidget {
  const _FastTile({required this.data});
  final ProfileData data;

  @override
  State<_FastTile> createState() => _FastTileState();
}

class _FastTileState extends State<_FastTile> {
  Timer? _tick;

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final user = widget.data.user;
    final fast = currentFast(user);
    final hours = fast?.targetHours ?? int.tryParse(pref(user, 'fast_hours') ?? '') ?? 16;
    final gone = fast == null ? null : DateTime.now().difference(fast.start);
    return Panel(
      radius: Radii.tile,
      padding: const EdgeInsets.all(12),
      color: c.warm,
      border: false,
      onTap: () => showModalBottomSheet<void>(context: context, builder: (_) => _FastSheet(data: widget.data)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(l.fasting, style: TextStyle(fontSize: 13, color: c.muted))),
          Text(l.fastGoalHours(hours), style: TextStyle(fontSize: 12, color: c.primary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        Text(gone == null ? l.fastNotRunning : l.hoursMinutes(gone.inHours, gone.inMinutes % 60),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 8),
        Bar(
          value: gone == null ? 0 : gone.inMinutes / (hours * 60),
          label: gone == null ? l.fasting : l.fastingLine(gone.inHours, gone.inMinutes % 60, hours),
        ),
      ]),
    );
  }
}

/// Start a fast (target hours, now or since the last meal) or end the running one.
class _FastSheet extends StatefulWidget {
  const _FastSheet({required this.data});
  final ProfileData data;

  @override
  State<_FastSheet> createState() => _FastSheetState();
}

class _FastSheetState extends State<_FastSheet> {
  late int _hours = int.tryParse(pref(widget.data.user, 'fast_hours') ?? '') ?? 16;

  void _start(DateTime at) {
    setPref(widget.data.user, 'fast_hours', '$_hours');
    startFast(widget.data.user, at, _hours);
    widget.data.changed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = widget.data.user;
    final fast = currentFast(user);
    final now = DateTime.now();
    final last = lastMealAt(user);
    final sinceMeal = last != null && now.difference(last).inHours < 24 ? last : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.fasting, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (fast != null) ...[
            Text(l.fastingLine(now.difference(fast.start).inHours, now.difference(fast.start).inMinutes % 60, fast.targetHours)),
            if (now.difference(fast.start).inMinutes >= fast.targetHours * 60)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.fastDone)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                endFast(user, DateTime.now());
                widget.data.changed();
                Navigator.pop(context);
              },
              child: Text(l.fastEnd),
            ),
          ] else ...[
            ChoicePills<int>(
              values: const [12, 14, 16, 18],
              selected: _hours,
              label: (h) => l.fastGoalHours(h),
              onChanged: (h) => setState(() => _hours = h),
            ),
            const SizedBox(height: 16),
            if (sinceMeal != null) ...[
              OutlinedButton(onPressed: () => _start(sinceMeal), child: Text(l.fastSinceMeal(DateFormat.Hm().format(sinceMeal)))),
              const SizedBox(height: 10),
            ],
            FilledButton(onPressed: () => _start(DateTime.now()), child: Text(l.fastStart)),
          ],
        ]),
      ),
    );
  }
}

/// Steps and active calories from the health app. Health Connect can't tell an app about new
/// data, so they are re-read every minute while shown and when the app comes back (weights too).
class _StepsTile extends StatefulWidget {
  const _StepsTile({required this.data});
  final ProfileData data;

  @override
  State<_StepsTile> createState() => _StepsTileState();
}

class _StepsTileState extends State<_StepsTile> {
  int? _steps;
  DateTime? _synced;
  late final Timer _timer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: () => _refresh(weights: true));
    _refresh();
  }

  @override
  void dispose() {
    _timer.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool weights = false}) async {
    final user = widget.data.user;
    final steps = await stepsToday(user);
    if (!mounted) return; // locked meanwhile: the database is closed
    final kcal = await syncActiveKcal(user);
    final weighed = weights && mounted && await syncHealthWeights(user) > 0;
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _synced = DateTime.now();
    });
    if (kcal || weighed) widget.data.changed(); // a new burnt ring or trend weight
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final burned = activeKcalOn(widget.data.user, DateTime.now());
    return Panel(
      radius: Radii.tile,
      padding: const EdgeInsets.all(12),
      color: c.mint,
      border: false,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _HealthSheet(data: widget.data, synced: _synced, onSync: () => _refresh(weights: true)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(l.steps, style: TextStyle(fontSize: 13, color: c.muted))),
          Icon(Icons.directions_walk, size: 20, color: c.primary),
        ]),
        const SizedBox(height: 14),
        Text(_steps == null ? '–' : NumberFormat.decimalPattern().format(_steps),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink)),
        if (burned > 0)
          Text(l.activeKcalBurned(NumberFormat.decimalPattern().format(burned.round())),
              style: TextStyle(fontSize: 13, color: c.muted)),
      ]),
    );
  }
}

/// Basic: today's micronutrients against EU reference intakes, lowest first (in a sheet from [_MicrosRow]).
class _MicrosCard extends StatelessWidget {
  const _MicrosCard({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final m = microTotalsOn(data.user, DateTime.now());
    final labels = microLabels(l);
    final share = {for (final k in labels.keys) k: m.totals[k]! / microReference[k]!};
    final keys = labels.keys.toList()..sort((a, b) => share[a]!.compareTo(share[b]!));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(l.microsTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            // Amounts, not "%": "4.2 mg / 14 mg" says how much more to eat.
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(labels[k]!.$1, style: const TextStyle(fontSize: 14))),
                Text('${formatMicro(m.totals[k]!, labels[k]!.$2)} / ${formatMicro(microReference[k]!, labels[k]!.$2)}',
                    style: TextStyle(fontSize: 13, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 4),
              Bar(
                value: share[k]!,
                height: 6,
                label: '${labels[k]!.$1} ${formatMicro(m.totals[k]!, labels[k]!.$2)} / ${formatMicro(microReference[k]!, labels[k]!.$2)}',
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Text(l.microsCoverage(m.known, m.meals), style: TextStyle(fontSize: 12, color: c.muted)),
      ]),
    );
  }
}

/// What the health app connection does, when it last synced, and the way out.
class _HealthSheet extends StatelessWidget {
  const _HealthSheet({required this.data, required this.synced, required this.onSync});
  final ProfileData data;
  final DateTime? synced;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final nav = Navigator.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(Platform.isIOS ? l.appleHealth : l.healthConnect, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.healthSheetReads),
          if (synced != null) ...[
            const SizedBox(height: 6),
            Text(l.lastSynced(DateFormat.Hm().format(synced!)), style: TextStyle(color: c.muted)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.sync),
            label: Text(l.syncNow),
            onPressed: () async {
              await onSync();
              nav.pop();
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await disconnectHealth(data.user);
              data.changed();
              nav.pop();
            },
            child: Text(l.disconnect),
          ),
        ]),
      ),
    );
  }
}

/// Basic: one row for the vitamins and minerals (the lowest one named); the full list opens in a sheet.
class _MicrosRow extends StatelessWidget {
  const _MicrosRow({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final m = microTotalsOn(data.user, DateTime.now());
    final labels = microLabels(l);
    final low = labels.keys.reduce((a, b) => m.totals[a]! / microReference[a]! <= m.totals[b]! / microReference[b]! ? a : b);
    return Panel(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SafeArea(child: SingleChildScrollView(child: _MicrosCard(data: data))),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.microsTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(l.microsLowest(labels[low]!.$1,
                    '${formatMicro(m.totals[low]!, labels[low]!.$2)} / ${formatMicro(microReference[low]!, labels[low]!.$2)}'),
                style: TextStyle(fontSize: 14, color: c.muted)),
          ]),
        ),
        Icon(Icons.chevron_right, color: c.muted),
      ]),
    );
  }
}

/// Before the AI is downloaded: what it adds, and the way to get it (Chat shows the sizes and progress).
const _aiCardHidden = 'ai_card_hidden';

class _AiCard extends ConsumerWidget {
  const _AiCard({required this.onLater});
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return Panel(
      color: c.mint,
      border: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_outlined, color: c.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(l.aiCardTitle, style: Theme.of(context).textTheme.titleMedium)),
        ]),
        const SizedBox(height: 6),
        Text(l.aiCardBody),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: () => ref.read(homeTabProvider.notifier).go(HomeTab.chat), child: Text(l.aiDownloadButton)),
          TextButton(onPressed: onLater, child: Text(l.later)),
        ]),
      ]),
    );
  }
}

/// A nudge with the two ways forward: log it, or ask the assistant for an idea.
class _NextStep extends ConsumerWidget {
  const _NextStep({required this.title, required this.body, required this.meal});
  final String title, body, meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tab = ref.read(homeTabProvider.notifier);
    return Panel(
      color: context.colors.mint,
      border: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(body),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(
            label: l.getIdea,
            icon: Icons.lightbulb_outline,
            compact: true,
            onTap: () {
              tab.go(HomeTab.chat);
              // Sent once the assistant is loaded; before that the tab shows its progress.
              final text = l.suggestIdea(inSentence(context, mealName(l, meal)));
              ref.read(agentProvider.future).then((a) => a.send(text), onError: (_) {}); // not downloaded: Chat says so
            },
          ),
          Pill(label: l.logIt, icon: Icons.add, compact: true, onTap: () => tab.go(HomeTab.log)),
        ]),
      ]),
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
      Panel(
        color: context.colors.hero,
        border: false,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.setGoalsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(l.setGoalsBody, style: TextStyle(color: Colors.white.withValues(alpha: .85))),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: context.colors.hero),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GoalsScreen())),
            child: Text(l.setGoalsButton),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.eatenToday, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          NutrientTiles(values: eaten),
        ]),
      ),
    ]);
  }
}

/// Fix a logged meal: which food it was, the amount (nutrition scales with it) and which meal.
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
        Row(children: [
          Expanded(child: Text(m.label)),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: Text(l.changeFood),
            onPressed: () async {
              final food = await showModalBottomSheet<FoodChoice>(
                  context: context, isScrollControlled: true, builder: (_) => _ChangeFoodSheet(meal: m, data: widget.data));
              if (food == null || !context.mounted) return;
              replaceMeal(widget.data.user, m.id, food);
              updateMeal(widget.data.user, m.id, type: _type);
              Navigator.pop(context, true);
            },
          ),
        ]),
        const SizedBox(height: 12),
        // Quick adds have no grams: only the food and the meal can change.
        if (m.grams != null)
          TextField(
            controller: _grams,
            decoration: InputDecoration(labelText: l.grams, suffixText: 'g'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 12),
        ChoicePills<String>(
          values: const ['breakfast', 'lunch', 'dinner', 'snack'],
          selected: _type,
          label: (t) => mealName(l, t),
          onChanged: (t) => setState(() => _type = t),
        ),
        const SizedBox(height: 12),
        Text('${m.estimated ? '≈' : ''}${kcal.round()} ${l.kcal}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: context.colors.danger),
              onPressed: () async {
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
                if (ok != true || !context.mounted) return;
                deleteMeal(widget.data.user, m.id);
                Navigator.pop(context, true);
              },
              child: Text(l.delete),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: m.grams != null && (grams == null || grams <= 0 || grams > 5000)
                  ? null
                  : () {
                      updateMeal(widget.data.user, m.id, grams: grams, type: _type);
                      Navigator.pop(context, true);
                    },
              child: Text(l.confirmSave),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Search for the right food; it starts from the entry's name, so near matches show at once.
class _ChangeFoodSheet extends StatefulWidget {
  const _ChangeFoodSheet({required this.meal, required this.data});
  final MealEntry meal;
  final ProfileData data;

  @override
  State<_ChangeFoodSheet> createState() => _ChangeFoodSheetState();
}

class _ChangeFoodSheetState extends State<_ChangeFoodSheet> {
  late final _search = TextEditingController(text: widget.meal.label);
  late var _results = widget.data.tools.searchFood(widget.meal.label);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.changeFood, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchFood),
          textInputAction: TextInputAction.search,
          onChanged: (t) => setState(() => _results = t.trim().length < 2 ? [] : widget.data.tools.searchFood(t)),
        ),
        const SizedBox(height: 8),
        if (_results.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(l.noResults))
        else
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final f in _results)
                ListTile(
                  title: Text(f.label),
                  subtitle: Text('${f.estimated ? '≈' : ''}${l.per100g(f.per100['kcal']!.round())}'),
                  onTap: () => Navigator.pop(context, f),
                ),
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
    final c = context.colors;
    return PanelList(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.recipesYouAte, style: Theme.of(context).textTheme.titleMedium),
          Text(l.recipesYouAteHint, style: TextStyle(fontSize: 13, color: c.muted)),
        ]),
      ),
      children: [
        for (final r in recipes)
          ListTile(
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(DateFormat('EEE d MMM').format(r.at)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r.stars == null ? '☆' : '★' * r.stars!, style: const TextStyle(color: Color(0xFFB8860B))),
              const Icon(Icons.chevron_right),
            ]),
            onTap: () => onOpen(r.id),
          ),
      ],
    );
  }
}
