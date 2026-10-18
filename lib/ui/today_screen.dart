import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../agent/agent_tools.dart' show FoodChoice;
import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/health_sync.dart'
    show askNewHealthAccess, disconnectHealth, healthSyncOn, stepsToday, syncActiveKcal, syncHealthWeights;
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                        : ListView(padding: const EdgeInsets.all(16), children: [
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
        final c = context.colors;
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
        final logged = {for (final m in meals) m.type ?? 'snack'}.length;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
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
            const SizedBox(height: 10),
            _TileRow(per: 3, children: [
              for (final key in otherBars)
                _NutrientTile(nutrient: key, eaten: eaten[key]!, goal: targets[key]!, limited: t.limited.containsKey(key)),
            ]),
          ],
          SectionTitle(l.mealsTitle,
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
              trailing: Text(l.mealsLogged(logged), textAlign: TextAlign.end, style: AppText.caption.copyWith(color: c.muted))),
          for (final type in ['breakfast', 'lunch', 'dinner', 'snack']) ...[
            _MealCard(
              type: type,
              meals: [for (final m in meals) if ((m.type ?? 'snack') == type) m],
              planned: planned[type],
              left: left,
              goal: targets['kcal'],
              data: data,
              onOpen: open,
              onEdit: edit,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          // The small daily numbers: water, steps, fasting side by side, weight across.
          _TileRow(children: [
            _WaterTile(data: data),
            if (healthSyncOn(data.user)) _StepsTile(data: data),
            if (fasting) _FastTile(data: data),
          ]),
          const SizedBox(height: 10),
          WeightTile(data: data),
          const SizedBox(height: 10),
          TierBuilder(
              builder: (_, tier) => tier.includes(Tier.basic) ? _MicrosCard(data: data) : const _MicrosLocked()),
          if (recipes.isNotEmpty)
            _RecipesYouAte(
              recipes: recipes,
              onOpen: open,
              onHistory: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => HistoryScreen(data: data)))
                  .then((_) => data.changed()),
            ),
        ]);
      },
    );
  }
}

/// Small cards side by side, [per] to a row (water and steps; fiber, sugar, sodium); one alone fills the row.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.children, this.per = 2});
  final List<Widget> children;
  final int per;

  @override
  Widget build(BuildContext context) {
    // Large text: the tiles stack instead of squeezing.
    final scale = MediaQuery.textScalerOf(context).scale(10);
    final per = scale > 15 ? 1 : scale > 12 ? math.min(2, this.per) : this.per;
    if (children.length == 1 || per == 1) {
      return Column(children: [
        for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), w],
      ]);
    }
    return Column(children: [
      for (var i = 0; i < children.length; i += per) ...[
        if (i > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = i; j < i + per; j++) ...[
              if (j > i) SizedBox(width: per > 2 ? 8 : 10),
              Expanded(child: j < children.length ? children[j] : const SizedBox.shrink()),
            ],
          ]),
        ),
      ],
    ]);
  }
}

/// Calories left in a ring split by macro (protein, carbs, fat as shares of what was eaten), the macro bars,
/// and Goal · Eaten · Burnt · Left.
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
    final water = context.nutrientColor('water');
    final ring = SizedBox.square(
      dimension: 140,
      child: Stack(alignment: Alignment.center, children: [
        Semantics(
          // TalkBack: words in the label, the share as the value.
          label: '${l.kcal}: ${ate.round()} ${l.eatenOfGoal(goal.round())}',
          value: '${(ate / goal * 100).clamp(0, 999).round()}%',
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _MacroRing(
                share: (ate / goal).clamp(0, 1),
                parts: over
                    ? [(1, c.danger)]
                    : [
                        for (final (k, perG) in [('protein_g', 4.0), ('carbs_g', 4.0), ('fat_g', 9.0)])
                          (eaten[k]! * perG, context.nutrientColor(k)),
                      ],
                fallback: context.nutrientColor('kcal'),
                track: c.track,
              ),
            ),
          ),
        ),
        // Inside, in its own colour: what the health app says was burnt, against a daily activity target.
        if (burned != null)
          SizedBox.square(
            dimension: 104,
            child: CircularProgressIndicator(
              value: (burned / activeKcalTarget).clamp(0, 1),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: water,
              backgroundColor: c.track,
              semanticsLabel: l.activeKcalBurned('${burned.round()}'),
            ),
          ),
        Padding(
          padding: EdgeInsets.all(burned == null ? 22 : 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              child: Text('$approx${_n(context, left.abs())}',
                  style: AppText.display.copyWith(color: over ? c.danger : c.ink, fontFeatures: AppText.tabular)),
            ),
            FittedBox(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (over) ...[Icon(Icons.warning_amber_rounded, size: 14, color: c.danger), const SizedBox(width: 3)],
                Text(over ? l.kcalOverShort : l.kcalLeftShort, style: AppText.caption.copyWith(color: c.muted)),
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
    Widget sum(String value, String label, Color color) => Expanded(
          child: Column(children: [
            FittedBox(
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color,
                  fontFeatures: AppText.tabular)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.muted)),
          ]),
        );
    return Semantics(
      container: true,
      label: l.calories,
      child: Panel(
        radius: Radii.hero,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
        child: Column(children: [
          // At large text sizes (or narrow) the bars move under the ring.
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
          Divider(color: c.divider, height: 1),
          const SizedBox(height: 12),
          Row(children: [
            sum(_n(context, goal), l.goal, c.ink),
            sum('−$approx${_n(context, ate)}', l.eatenWord, c.ink),
            if (burned != null) sum('+${_n(context, burned)}', l.burntWord, water),
            sum('$approx${over ? '−' : ''}${_n(context, left.abs())}', l.leftWord, over ? c.danger : c.primary),
          ]),
        ]),
      ),
    );
  }
}

/// The calories ring: [share] of the circle filled, split into [parts] by weight (each a macro's kcal),
/// with a small gap between them; [fallback] when nothing has macros (a quick add of only kcal).
class _MacroRing extends CustomPainter {
  _MacroRing({required this.share, required this.parts, required this.fallback, required this.track});
  final double share;
  final List<(double, Color)> parts;
  final Color fallback, track;

  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, pen..color = track);
    if (share <= 0) return;
    final total = parts.fold(0.0, (s, p) => s + p.$1);
    final shown = total > 0 ? [for (final p in parts) if (p.$1 > 0) p] : [(1.0, fallback)];
    final sum = total > 0 ? total : 1.0;
    final sweep = 2 * math.pi * share;
    // Round caps reach past the arc's ends: leave room for them (and a hairline gap) between parts.
    final gap = shown.length > 1 ? (_stroke + 4) / (rect.width / 2) : 0.0;
    var at = -math.pi / 2;
    for (final (w, color) in shown) {
      final part = sweep * w / sum;
      canvas.drawArc(rect, at + gap / 2, math.max(part - gap, 0.001), false, pen..color = color);
      at += part;
    }
  }

  @override
  bool shouldRepaint(_MacroRing old) =>
      old.share != share || old.track != track || old.fallback != fallback || old.parts.toString() != parts.toString();
}

class _HeroBar extends StatelessWidget {
  const _HeroBar({required this.nutrient, required this.eaten, required this.goal, required this.limited});
  final String nutrient;
  final double eaten, goal;
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final name = nutrientLabels(l)[nutrient]!.$1;
    final color = context.nutrientColor(nutrient);
    final over = limited && eaten > goal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
          if (over) ...[Icon(Icons.warning_amber_rounded, size: 14, color: c.danger), const SizedBox(width: 4)],
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${eaten.round()}', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
              TextSpan(text: ' / ${limited ? '${l.limitSuffix} ' : ''}${formatNutrient(nutrient, goal, l)}'),
            ]),
            style: TextStyle(fontSize: 13, color: c.muted, fontFeatures: AppText.tabular),
          ),
        ]),
        const SizedBox(height: 5),
        Bar(
          value: eaten / goal,
          height: 6,
          color: over ? c.danger : color,
          label: '$name: ${formatNutrient(nutrient, eaten, l)} / ${formatNutrient(nutrient, goal, l)}',
        ),
      ]),
    );
  }
}

/// Fiber, sugar, sodium on Today: a small card each, the name in its colour ("Sugar · max" for a ceiling).
class _NutrientTile extends StatelessWidget {
  const _NutrientTile({required this.nutrient, required this.eaten, required this.goal, this.limited = false});
  final String nutrient;
  final double eaten, goal;
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final limit = limited || limitNutrients.contains(nutrient);
    final over = limit && eaten > goal;
    final color = context.nutrientColor(nutrient);
    final name = nutrientLabels(l)[nutrient]!.$1;
    final (n, unit) = formatNutrientParts(nutrient, goal, l);
    return Panel(
      radius: Radii.tile,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(limit ? '$name · ${l.limitSuffix}' : name,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${eaten.round()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
              TextSpan(text: ' / $n $unit'),
            ]),
            style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: AppText.tabular),
          ),
        ),
        const SizedBox(height: 6),
        Bar(
          value: eaten / goal,
          height: 4,
          color: over ? c.danger : color,
          label: '$name: ${formatNutrient(nutrient, eaten, l)} / ${formatNutrient(nutrient, goal, l)}',
        ),
        // Never colour alone: the warning says it in words too.
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: c.danger),
              const SizedBox(width: 3),
              Flexible(
                  child: Text(l.overBy(formatNutrient(nutrient, eaten - goal, l)),
                      style: AppText.caption.copyWith(color: c.danger))),
            ]),
          ),
      ]),
    );
  }
}

/// A nutrient against its goal (or ceiling) on the period cards: dot, name, values, bar.
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
    final color = context.nutrientColor(nutrient);
    final name = nutrientLabels(l)[nutrient]!.$1;
    final danger = context.colors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
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

/// One meal in one row: its icon, what was eaten (or what's suggested), kcal and a + that opens Log on it.
/// A logged meal opens to its items (tap one to fix it); an empty one gets "+ Add" in the meal's colour,
/// or today's planned recipe for it.
class _MealCard extends ConsumerStatefulWidget {
  const _MealCard({required this.type, required this.meals, required this.planned, required this.left,
      required this.goal, required this.data, required this.onOpen, required this.onEdit});
  final String type;
  final List<MealEntry> meals;
  final Planned? planned;
  final double? left, goal;
  final ProfileData data;
  final ValueChanged<int> onOpen;
  final ValueChanged<MealEntry> onEdit;

  @override
  ConsumerState<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends ConsumerState<_MealCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final w = widget;
    final meals = w.meals;
    final name = mealName(l, w.type);
    final color = context.mealColor(w.type);
    void add() => ref.read(homeTabProvider.notifier).logMeal(w.type);
    final plan = meals.isEmpty ? w.planned : null;
    final kcal = meals.fold(0.0, (s, m) => s + m.kcal);
    // Snacks get what the planned meals leave (10 %).
    final suggested = w.goal == null ? null : w.goal! * (mealShare(w.type) ?? .10);
    final subtitle = meals.isNotEmpty
        ? meals.map((m) => m.label).join(', ')
        : plan != null
            ? '${plan.title} · ${l.fromYourPlan}'
            : suggested == null
                ? null
                : l.suggestedAmount('${_n(context, suggested)} ${l.kcal}');
    final trailing = meals.isNotEmpty
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${meals.any((m) => m.estimated) ? '≈' : ''}${_n(context, kcal)}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
                  TextSpan(text: ' ${l.kcal}', style: AppText.caption.copyWith(color: c.muted)),
                ]),
                style: const TextStyle(fontFeatures: AppText.tabular),
              ),
            ),
            const SizedBox(width: 8),
            RoundIconButton(
              icon: Icons.add,
              tooltip: l.addToMeal(name),
              size: 40,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
              background: c.surfaceHigh,
              onPressed: add,
            ),
          ])
        : Tooltip(
            message: l.addToMeal(name),
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(Radii.chip),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: add,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: Text(l.addShort, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.onPrimary)),
                    ),
                  ),
                ),
              ),
            ),
          );
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          // Logged: open or close the items; planned: the recipe; empty: Log on this meal.
          onTap: meals.isNotEmpty
              ? () => setState(() => _open = !_open)
              : plan != null
                  ? () => w.onOpen(plan.recipeId)
                  : add,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(children: [
              MealIcon(type: w.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text(name, style: AppText.item.copyWith(fontSize: 16, color: c.ink))),
                  if (subtitle != null)
                    Text(subtitle,
                        maxLines: _open ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted)),
                  // Large text: kcal and the button go under the name instead of squeezing it.
                  if (stacked) ...[const SizedBox(height: 8), trailing],
                ]),
              ),
              if (!stacked) ...[const SizedBox(width: 8), trailing],
            ]),
          ),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Durations.medium1,
          alignment: Alignment.topCenter,
          child: !_open || meals.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final m in meals) ...[
                    Divider(indent: 12, endIndent: 12, color: c.divider),
                    InkWell(
                      // A recipe opens (to see and rate it); anything else edits. Long press always edits.
                      onTap: m.recipeId == null ? () => w.onEdit(m) : () => w.onOpen(m.recipeId!),
                      onLongPress: () => w.onEdit(m),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(68, 6, 16, 6),
                          child: Row(children: [
                            if (m.recipeId != null) ...[
                              Icon(Icons.menu_book_outlined, size: 18, color: color),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.label, style: AppText.body.copyWith(color: c.ink)),
                                Text(
                                    [DateFormat.Hm().format(m.at), if (m.grams != null) '${m.estimated ? '≈ ' : ''}${m.grams!.round()} g']
                                        .join(' · '),
                                    style: AppText.caption.copyWith(color: c.muted)),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Text('${m.estimated ? '≈' : ''}${_n(context, m.kcal)}',
                                style: TextStyle(fontSize: 14, color: c.muted, fontFeatures: AppText.tabular)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ]),
        ),
        if (plan != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: tint(context, color),
              borderRadius: BorderRadius.circular(Radii.tile),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.tile),
                onTap: () => w.onOpen(plan.recipeId),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Expanded(
                      child: Text(_planLine(context, l, plan), style: AppText.caption.copyWith(fontSize: 13, color: c.ink2)),
                    ),
                    const SizedBox(width: 8),
                    Text(l.cook, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  String _planLine(BuildContext context, AppLocalizations l, Planned p) {
    final minutes = widget.data.nutri.select('SELECT minutes FROM recipes WHERE id = ?', [p.recipeId]).firstOrNull?['minutes'] as int?;
    final left = widget.left;
    return [
      '${_n(context, p.kcal)} ${l.kcal}',
      if (minutes != null && minutes > 0) l.minutesShort(minutes),
      if (left != null && left >= p.kcal) l.fitsLeft(_n(context, left)),
    ].join(' · ');
  }
}

/// The coloured header of Today's small cards: icon and name, and an optional action at the end.
Widget _tileHead(BuildContext context, IconData icon, String label, Color color, [Widget? action]) => Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(label, style: AppText.body.copyWith(color: context.colors.ink))),
      ?action,
    ]);

/// A big number with its unit after it, smaller ("1.25 / 2.75 L", "54").
Widget _bigNumber(BuildContext context, String value, [String? unit]) {
  final c = context.colors;
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text.rich(TextSpan(children: [
      TextSpan(text: value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4)),
      if (unit != null) TextSpan(text: ' $unit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
    ]), style: const TextStyle(fontFeatures: AppText.tabular)),
  );
}

/// Today's water: litres against the goal as glasses; + adds a glass (with Undo on the snackbar).
class _WaterTile extends StatelessWidget {
  const _WaterTile({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final blue = context.nutrientColor('water');
    final ml = waterOn(data.user, DateTime.now()), goal = waterGoal(data.user);
    final glasses = (goal / glassMl).round().clamp(1, 16), had = (ml / glassMl).floor();
    String litres(double v) => (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 2).replaceFirst(RegExp(r'0$'), '');
    return Panel(
      radius: Radii.card,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      color: c.waterBg,
      border: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _tileHead(
          context,
          Icons.water_drop_outlined,
          l.water,
          blue,
          Tooltip(
            message: l.waterAddGlass,
            child: Material(
              color: blue,
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
                    child: Semantics(label: l.waterAddGlass, button: true, child: Icon(Icons.add, color: c.onPrimary))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          container: true, // its own node, not merged into the tile's other text
          label: l.waterLine(ml.round(), goal.round()),
          excludeSemantics: true,
          child: _bigNumber(context, litres(ml), '/ ${litres(goal)} ${l.litreUnit}'),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: ExcludeSemantics(
            child: Row(children: [
              for (var i = 0; i < glasses; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: i < had ? blue : blue.withValues(alpha: .22), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ],
            ]),
          ),
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
    final amber = context.nutrientColor('carbs_g');
    return Panel(
      radius: Radii.card,
      padding: const EdgeInsets.all(14),
      color: tint(context, amber, alpha: .18),
      border: false,
      onTap: () => showModalBottomSheet<void>(context: context, builder: (_) => _FastSheet(data: widget.data)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _tileHead(context, Icons.timer_outlined, l.fasting, amber,
            Text(l.fastGoalHours(hours), style: TextStyle(fontSize: 12, color: amber, fontWeight: FontWeight.w700))),
        const SizedBox(height: 14),
        Text(gone == null ? l.fastNotRunning : l.hoursMinutes(gone.inHours, gone.inMinutes % 60),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: AppText.tabular)),
        const SizedBox(height: 8),
        Bar(
          color: amber,
          track: amber.withValues(alpha: .22),
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
    askNewHealthAccess(widget.data.user).whenComplete(() => mounted ? _refresh() : null);
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
    final violet = context.nutrientColor('fat_g');
    return Panel(
      radius: Radii.card,
      padding: const EdgeInsets.all(14),
      color: tint(context, violet, alpha: .2),
      border: false,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _HealthSheet(data: widget.data, synced: _synced, onSync: () => _refresh(weights: true)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Same height as the water card's header (its + button).
        SizedBox(height: 48, child: _tileHead(context, Icons.monitor_heart_outlined, l.steps, violet)),
        const SizedBox(height: 6),
        _bigNumber(context, _steps == null ? '–' : NumberFormat.decimalPattern().format(_steps)),
        const SizedBox(height: 4),
        Text(
            '${l.activeKcalBurned(NumberFormat.decimalPattern().format(burned.round()))} · '
            '${Platform.isIOS ? l.appleHealth : l.healthConnect}',
            style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
      ]),
    );
  }
}

/// Basic: today's vitamins and minerals against EU reference intakes, lowest first, two to a row.
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
    final lime = context.nutrientColor('sugar_g');
    Widget item(String k) {
      final (name, unit) = labels[k]!;
      final amounts = '${formatMicro(m.totals[k]!, unit)} / ${formatMicro(microReference[k]!, unit)}';
      // Amounts, not "%": "4.2 mg / 14 mg" says how much more to eat.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontSize: 13, color: c.ink)),
        Text(amounts, style: AppText.caption.copyWith(color: c.muted, fontFeatures: AppText.tabular)),
        const SizedBox(height: 4),
        Bar(value: share[k]!, height: 5, color: share[k]! >= 1 ? c.primary : lime, label: '$name $amounts'),
      ]);
    }

    final per = MediaQuery.textScalerOf(context).scale(10) > 15 ? 1 : 2;
    return Panel(
      radius: Radii.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconTile(icon: Icons.eco_outlined, color: lime, size: 32),
          const SizedBox(width: 10),
          Expanded(child: Semantics(header: true, child: Text(l.microsTitle, style: AppText.section.copyWith(color: c.ink)))),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < keys.length; i += per) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var j = i; j < i + per; j++) ...[
              if (j > i) const SizedBox(width: 16),
              Expanded(child: j < keys.length ? item(keys[j]) : const SizedBox.shrink()),
            ],
          ]),
        ],
        const SizedBox(height: 12),
        Text(l.microsCoverage(m.known, m.meals), style: AppText.caption.copyWith(color: c.muted)),
      ]),
    );
  }
}

/// Free: what the vitamins and minerals card shows, and the way to Basic.
class _MicrosLocked extends StatelessWidget {
  const _MicrosLocked();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return Panel(
      radius: Radii.card,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
      child: Row(children: [
        IconTile(icon: Icons.eco_outlined, color: context.nutrientColor('sugar_g'), size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.microsTitle, style: AppText.section.copyWith(color: c.ink)),
            const SizedBox(height: 2),
            Text(l.microsLocked, style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Icon(Icons.lock_outline, size: 20, color: c.muted),
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

/// The newest recipes logged as eaten, with their stars or a "Rate" button; a tap opens one to rate it.
class _RecipesYouAte extends StatelessWidget {
  const _RecipesYouAte({required this.recipes, required this.onOpen, required this.onHistory});
  final List<({int id, String title, DateTime at, int? stars})> recipes;
  final ValueChanged<int> onOpen;
  final VoidCallback onHistory;

  static const _hues = ['protein_g', 'kcal', 'fat_g', 'carbs_g', 'sodium_mg', 'fiber_g'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final gold = context.nutrientColor('carbs_g');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(l.rateWhatYouAte,
          padding: const EdgeInsets.fromLTRB(2, 16, 0, 4),
          trailing: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onHistory, child: Text(l.historyTitle)),
          )),
      PanelList(children: [
        for (final r in recipes)
          InkWell(
            onTap: () => onOpen(r.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(children: [
                  () {
                    final hue = context.nutrientColor(_hues[r.title.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0xffff) % _hues.length]);
                    final initials = [for (final w in r.title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2)) w.characters.first]
                        .join()
                        .toUpperCase();
                    return ExcludeSemantics(
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: tint(context, hue, alpha: .2), borderRadius: BorderRadius.circular(Radii.tile)),
                        child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: hue)),
                      ),
                    );
                  }(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.item.copyWith(color: c.ink)),
                      Text(DateFormat('EEE d MMM').format(r.at), style: AppText.caption.copyWith(color: c.muted)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  if (r.stars case final stars?)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('★' * stars, style: TextStyle(fontSize: 15, color: gold)),
                      if (stars < 5) Text('★' * (5 - stars), style: TextStyle(fontSize: 15, color: c.outline)),
                    ])
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: c.warm, borderRadius: BorderRadius.circular(Radii.chip)),
                      child: Text(l.rateButton, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.onWarm)),
                    ),
                ]),
              ),
            ),
          ),
      ]),
    ]);
  }
}
