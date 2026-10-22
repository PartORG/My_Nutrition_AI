import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../agent/agent_tools.dart' show RecipeListCard, RecipeSummary;
import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart' show totalsOn;
import '../data/goals.dart';
import '../data/plan.dart';
import '../l10n/app_localizations.dart';
import 'avatar.dart';
import 'camera_screen.dart';
import 'kit.dart';
import 'paywall_screen.dart' show LockedCard, TierBuilder;
import 'nutrients.dart' show inSentence;
import 'recipe_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;
import 'voice.dart';

enum PlanTab { plan, recipes, shopping }

/// The Plan tab: the week's plan (Basic), the recipe box, and the shopping list (Basic).
class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.data,
    this.initialTab = PlanTab.plan,
    this.back = false,
  });
  final ProfileData data;
  final PlanTab initialTab;

  /// Opened from the drawer or Me (not the tab): a back arrow instead of the ☰.
  final bool back;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final data = widget.data;
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final list = shoppingList(data.tools);
        final open = list.where((i) => !i.checked).length;
        final today = DateUtils.dateOnly(DateTime.now());
        final locale = Localizations.localeOf(context).toString();
        final week =
            '${DateFormat.MMMd(locale).format(today)} – ${DateFormat.MMMd(locale).format(today.add(const Duration(days: 6)))}';
        final (title, aside) = switch (_tab) {
          PlanTab.plan => (l.thisWeek, week),
          PlanTab.recipes => (l.recipesTitle, data.tools.myAllergens().isEmpty ? null : l.allergenFreeForYou),
          PlanTab.shopping => (
            l.shoppingList,
            list.isEmpty ? null : l.itemsLeft(open, list.length),
          ),
        };
        return Column(
          children: [
            // Chrome at most 1.5× text: at 200 % the header and tabs would leave the content no room.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Column(
                children: [
                  ScreenHeader(title: title, overline: aside, back: widget.back),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: PillTabs<PlanTab>(
                      values: PlanTab.values,
                      selected: _tab,
                      label: (t) => switch (t) {
                        PlanTab.plan => l.planTab,
                        PlanTab.recipes => l.recipesTitle,
                        PlanTab.shopping =>
                          list.isEmpty
                              ? l.shoppingList
                              : l.shoppingTabCount(list.length),
                      },
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                PlanTab.recipes => _RecipeBox(data: data),
                PlanTab.plan => TierBuilder(
                  builder: (context, tier) => tier.includes(Tier.basic)
                      ? _WeekPlan(
                          data: data,
                          onShopping: () =>
                              setState(() => _tab = PlanTab.shopping),
                        )
                      : _locked(l),
                ),
                PlanTab.shopping => TierBuilder(
                  builder: (context, tier) => tier.includes(Tier.basic)
                      ? _Shopping(data: data, items: list)
                      : _locked(l),
                ),
              },
            ),
          ],
        );
      },
    );
  }

  Widget _locked(AppLocalizations l) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      LockedCard(
        icon: Icons.event_note_outlined,
        title: l.planLockedTitle,
        body: l.planLockedBody,
      ),
    ],
  );
}

// ---- plan -----------------------------------------------------------------------------

class _WeekPlan extends StatefulWidget {
  const _WeekPlan({required this.data, required this.onShopping});
  final ProfileData data;
  final VoidCallback onShopping;

  @override
  State<_WeekPlan> createState() => _WeekPlanState();
}

class _WeekPlanState extends State<_WeekPlan> {
  var _day = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final tools = widget.data.tools;
    final today = DateUtils.dateOnly(DateTime.now());
    final plan = plannedMealsFor(tools, today);
    final locale = Localizations.localeOf(context).toString();
    void update(void Function() f) {
      f();
      widget.data.changed();
    }

    final goal = currentTargets(
      widget.data.user,
      nutri: widget.data.nutri,
      now: _day,
    ).values['kcal'];
    final days = SizedBox(
      height: 64 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DayChip(
                  day: today.add(Duration(days: i)),
                  selected: DateUtils.isSameDay(_day, today.add(Duration(days: i))),
                  locale: locale,
                  onTap: () => setState(() => _day = today.add(Duration(days: i))),
                ),
              ),
            ),
        ],
      ),
    );
    if (plan.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(13, 4, 13, 24),
        children: [
          days,
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _PlanHero(goal: goal, onPlan: () => update(() => planWeek(tools, today))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SectionTitle(
              DateFormat.EEEE(locale).format(_day),
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
              trailing: Text(l.fillsAfterPlanning, textAlign: TextAlign.end, style: AppText.caption.copyWith(color: c.muted)),
            ),
          ),
          for (final t in plannedMeals) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _MealPlaceholder(type: t, kcal: goal == null ? null : goal * mealShare(t)!),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }
    final dayMeals = [
      for (final p in plan)
        if (DateUtils.isSameDay(p.day, _day)) p,
    ];
    final planned = dayMeals.fold(0.0, (s, p) => s + p.kcal);
    final allergens = tools.myAllergens();
    void open(int id) => Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => RecipeScreen(
              tools: tools,
              recipeId: id,
              onLogged: widget.data.changed,
            ),
          ),
        )
        .then(
          (_) => widget.data.changed(),
        ); // stars may have changed what is planned next
    return ListView(
      padding: const EdgeInsets.fromLTRB(13, 4, 13, 24),
      children: [
        days,
        const SizedBox(height: 14),
        for (final p in dayMeals) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Panel(
              onTap: () => open(p.recipeId),
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Row(
                children: [
                  MealIcon(type: p.mealType, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mealName(l, p.mealType),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.mealColor(p.mealType),
                          ),
                        ),
                        Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.item.copyWith(color: c.ink),
                        ),
                        Text(
                          _recipeLine(context, tools.recipeSummary(p.recipeId)),
                          style: AppText.caption.copyWith(fontSize: 13, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.planSwap,
                    icon: Icon(Icons.swap_horiz, color: c.muted),
                    onPressed: () =>
                        update(() => swapPlanned(tools, p.day, p.mealType)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.plannedFor(DateFormat.EEEE(locale).format(_day)),
                      style: AppText.section.copyWith(color: c.ink),
                    ),
                  ),
                  Text(
                    goal == null
                        ? '${planned.round()} ${l.kcal}'
                        : l.planOfKcal(planned.round(), goal.round()),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink2,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                ],
              ),
              if (goal != null) ...[
                const SizedBox(height: 8),
                Bar(
                  value: planned / goal,
                  color: context.nutrientColor('kcal'),
                  label: l.planOfKcal(planned.round(), goal.round()),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (goal - planned > 100)
                      l.roomForSnack((goal - planned).round()),
                    if (allergens.isNotEmpty)
                      l.allergensLeftOut(allergens.join(', ')),
                  ].join(' '),
                  style: AppText.caption.copyWith(fontSize: 13, color: c.muted),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => update(() => planWeek(tools, today)),
                      child: Text(l.planAgain, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        update(() => shoppingFromPlan(tools, today));
                        widget.onShopping();
                      },
                      child: Text(l.makeShoppingList, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _mealName(AppLocalizations l, String t) => switch (t) {
    'breakfast' => l.mealBreakfast,
    'lunch' => l.mealLunch,
    _ => l.mealDinner,
  };
}

/// Before the first plan: what planning does, on the green hero, and the one button.
class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.goal, required this.onPlan});
  final double? goal;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    Widget point(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            IconTile(icon: icon, color: color, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppText.body.copyWith(color: c.ink))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(color: c.heroSurface, borderRadius: BorderRadius.circular(Radii.hero)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(
          child: Row(children: [
            for (final t in ['breakfast', 'lunch', 'dinner', 'snack'])
              Container(
                width: 38,
                height: 38,
                margin: const EdgeInsetsDirectional.only(end: 6),
                decoration: BoxDecoration(color: context.mealColor(t), borderRadius: BorderRadius.circular(Radii.tile)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(l.planHeroTitle, style: AppText.title.copyWith(fontSize: 22, color: c.ink))),
        const SizedBox(height: 6),
        Text(l.planHeroBody, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.ink2)),
        const SizedBox(height: 4),
        if (goal != null)
          point(Icons.check, context.nutrientColor('kcal'),
              l.planSized('${NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(goal!.round())} ${l.kcal}')),
        point(Icons.shield_outlined, context.nutrientColor('protein_g'), l.planNoAllergens),
        point(Icons.star, context.nutrientColor('carbs_g'), l.planStarsFirst),
        const SizedBox(height: 18),
        FilledButton.icon(icon: const Icon(Icons.auto_awesome, size: 20), label: Text(l.planWeek), onPressed: onPlan),
      ]),
    );
  }
}

/// A meal of the day before planning: its colour, a grey line where the recipe goes, its share of the goal.
class _MealPlaceholder extends StatelessWidget {
  const _MealPlaceholder({required this.type, required this.kcal});
  final String type;
  final double? kcal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final color = context.mealColor(type);
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: tint(context, color, alpha: .16), borderRadius: BorderRadius.circular(Radii.tile)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_WeekPlanState._mealName(l, type), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 8),
            FractionallySizedBox(
              widthFactor: .7,
              child: Container(height: 8, decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(4))),
            ),
          ]),
        ),
        if (kcal != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text('~${kcal!.round()} ${l.kcal}',
                textAlign: TextAlign.end, style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
          ),
        ],
      ]),
    );
  }
}

String _recipeLine(BuildContext context, RecipeSummary r) {
  final l = AppLocalizations.of(context)!;
  return [
    '${r.kcal.round()} ${l.kcal}',
    if (r.minutes != null && r.minutes! > 0) l.minutesShort(r.minutes!),
  ].join(' · ');
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.locale,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: DateFormat.MMMMEEEEd(locale).format(day),
      excludeSemantics: true,
      child: Material(
        color: selected ? c.primary : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile)),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.E(locale).format(day),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? c.onPrimary : c.muted,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selected ? c.onPrimary : c.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- recipe box -------------------------------------------------------------------------

class _RecipeBox extends StatefulWidget {
  const _RecipeBox({required this.data});
  final ProfileData data;

  @override
  State<_RecipeBox> createState() => _RecipeBoxState();
}

class _RecipeBoxState extends State<_RecipeBox> {
  final _search = TextEditingController();
  late final _voice = Dictation(_search, () {
    if (mounted) setState(() {});
  });
  var _shelf = RecipeShelf.saved;

  /// "Ideas for your dinner": the next planned meal, sized to what's left today; picked once per visit.
  late final _ideas = () {
    final tools = widget.data.tools, now = DateTime.now();
    final meal = tools.mealTypeNow(), share = mealShare(meal);
    if (share == null) return null; // snacks aren't planned
    final goal = currentTargets(widget.data.user, nutri: widget.data.nutri, now: now).values['kcal'];
    final left = goal == null ? null : goal - totalsOn(widget.data.user, now)['kcal']!;
    final target = (goal ?? 2000) * share;
    return (meal: meal, left: left, recipes: mealIdeas(tools, meal, left != null && left > 0 && left < target ? left : target));
  }();
  List<RecipeSummary>?
  _cook; // "What can I cook?" ideas, shown instead of the shelf
  String _cookFor = '';

  @override
  void dispose() {
    _voice.dispose();
    _search.dispose();
    super.dispose();
  }

  void _cookWith(String ingredients) {
    final r = widget.data.tools.run('search_recipes', {
      'query': '',
      'ingredients': ingredients,
    });
    setState(() {
      _cookFor = ingredients;
      _cook = r.card is RecipeListCard
          ? (r.card! as RecipeListCard).recipes
          : const [];
    });
  }

  Future<void> _whatCanICook() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FridgeSheet(
        onCamera: () {
          Navigator.pop(context);
          openCamera(
            context,
            'photo',
            onCook: (names) => _cookWith(names.join(', ')),
          );
        },
      ),
    );
    if (text != null && text.trim().isNotEmpty) _cookWith(text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final tools = widget.data.tools;
    final saved = savedRecipeIds(tools);
    final searching = _search.text.trim().length >= 2;
    final list =
        _cook ??
        recipeBox(
          tools,
          query: _search.text,
          shelf: searching && _shelf == RecipeShelf.saved ? null : _shelf,
        );
    final columns = MediaQuery.textScalerOf(context).scale(10) > 15 ? 1 : 2;
    void open(int id) => Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => RecipeScreen(tools: tools, recipeId: id, onLogged: widget.data.changed),
          ),
        )
        .then((_) => setState(() {}));
    final grid = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      mainAxisExtent: 236 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
    );
    Widget tile(RecipeSummary r) => _RecipeTile(
          recipe: r,
          saved: saved.contains(r.id),
          stars: tools.rating(r.id),
          onSave: (on) => setState(() => setRecipeSaved(tools, r.id, on)),
          onOpen: () => open(r.id),
        );
    final ideas = _ideas;
    final amber = context.nutrientColor('carbs_g');
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.list(
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l.searchRecipes,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(4),
                    child: MicButton(
                      dictation: _voice,
                      onPressed: () => _voice.toggle(context),
                    ),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() => _cook = null),
              ),
              const SizedBox(height: 12),
              Panel(
                color: tint(context, amber, alpha: .16),
                border: false,
                onTap: _whatCanICook,
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: amber, borderRadius: BorderRadius.circular(Radii.tile)),
                        child: Icon(Icons.photo_camera_outlined, color: c.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.whatCanICook, style: AppText.section.copyWith(color: amber)),
                          Text(l.whatCanICookBody, style: AppText.caption.copyWith(fontSize: 13, color: c.ink2)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: amber),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_cook != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.ideasFor(_cookFor),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _cook = null),
                      child: Text(l.cancel),
                    ),
                  ],
                )
              else
                ChoicePills<RecipeShelf>(
                  values: RecipeShelf.values,
                  selected: _shelf,
                  scroll: true,
                  label: (s) => switch (s) {
                    RecipeShelf.saved => l.shelfSaved(saved.length),
                    RecipeShelf.cooked => l.shelfCooked,
                    RecipeShelf.loved => l.shelfLoved,
                    RecipeShelf.quick => l.shelfQuick,
                  },
                  onChanged: (s) => setState(() => _shelf = s),
                ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Panel(child: EvaNote(_cook != null ? l.cookNone : l.boxEmpty, asset: evaEatingAsset)),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverGrid.builder(
            gridDelegate: grid,
            itemCount: list.length,
            itemBuilder: (context, i) => tile(list[i]),
          ),
        ),
        if (ideas != null && ideas.recipes.isNotEmpty && _cook == null && !searching) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: SectionTitle(
                l.ideasForMeal(inSentence(context, mealName(l, ideas.meal))),
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                trailing: ideas.left == null || ideas.left! <= 0
                    ? null
                    : Text(l.amountLeftApprox('${ideas.left!.round()} ${l.kcal}'),
                        textAlign: TextAlign.end, style: AppText.caption.copyWith(color: c.muted)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverGrid.builder(
              gridDelegate: grid,
              itemCount: ideas.recipes.length,
              itemBuilder: (context, i) => tile(ideas.recipes[i]),
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Text(
              l.boxFootnote,
              style: AppText.caption.copyWith(fontSize: 13, color: c.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.recipe,
    required this.saved,
    required this.stars,
    required this.onSave,
    required this.onOpen,
  });
  final RecipeSummary recipe;
  final bool saved;
  final int? stars;
  final ValueChanged<bool> onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    Widget chip(String text, Color fg, Color bg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg, fontFeatures: AppText.tabular)),
        );
    final green = context.nutrientColor('kcal'), coral = context.nutrientColor('protein_g');
    final amber = context.nutrientColor('carbs_g');
    // Protein gives at least a quarter of the calories.
    final highProtein = recipe.kcal > 0 && recipe.protein * 4 / recipe.kcal >= .25;
    return Panel(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              RecipeArt(title: recipe.title, height: 108),
              Positioned(
                top: 4,
                right: 4,
                child: RoundIconButton(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  tooltip: saved ? l.removeSaved : l.cardSaveRecipe,
                  background: c.background.withValues(alpha: .85),
                  foreground: saved ? c.primary : c.ink,
                  onPressed: () => onSave(!saved),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.item.copyWith(color: c.ink),
                    ),
                  ),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      chip('${recipe.kcal.round()} ${l.kcal}', green, tint(context, green)),
                      if (recipe.minutes != null && recipe.minutes! > 0)
                        chip(l.minutesShort(recipe.minutes!), c.ink2, c.surfaceHigh),
                      if (highProtein) chip(l.highProtein, coral, tint(context, coral)),
                      if (stars != null) chip('★ $stars', amber, tint(context, amber)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "What's in your fridge?": type or say it, or open the camera.
class _FridgeSheet extends StatefulWidget {
  const _FridgeSheet({required this.onCamera});
  final VoidCallback onCamera;

  @override
  State<_FridgeSheet> createState() => _FridgeSheetState();
}

class _FridgeSheetState extends State<_FridgeSheet> {
  final _text = TextEditingController();
  late final _voice = Dictation(_text, () {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _voice.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.whatCanICook, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  decoration: InputDecoration(hintText: l.fridgeHint),
                  onSubmitted: (t) => Navigator.pop(context, t),
                ),
              ),
              const SizedBox(width: 8),
              MicButton(
                dictation: _voice,
                onPressed: () => _voice.toggle(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l.cameraOpen),
                  onPressed: widget.onCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _text.text),
                  child: Text(l.findRecipes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- shopping ---------------------------------------------------------------------------

class _Shopping extends StatefulWidget {
  const _Shopping({required this.data, required this.items});
  final ProfileData data;
  final List<ShoppingItem> items;

  @override
  State<_Shopping> createState() => _ShoppingState();
}

class _ShoppingState extends State<_Shopping> {
  final _item = TextEditingController();
  late final _voice = Dictation(_item, () {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _voice.dispose();
    _item.dispose();
    super.dispose();
  }

  void _add(String t) {
    if (t.trim().isEmpty) return;
    addShoppingItem(widget.data.tools, t);
    _item.clear();
    widget.data.changed();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final tools = widget.data.tools;
    final items = widget.items;
    final ticked = items.where((i) => i.checked).length;
    final byAisle = <Aisle, List<ShoppingItem>>{};
    for (final i in items) {
      (byAisle[i.aisle] ??= []).add(i);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _item,
                decoration: InputDecoration(hintText: l.shoppingAdd),
                textInputAction: TextInputAction.done,
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: 10),
            MicButton(
              dictation: _voice,
              onPressed: () => _voice.toggle(context),
            ),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: EvaNote(l.shoppingEmpty, asset: evaEatingAsset),
          ),
        for (final aisle in Aisle.values)
          if (byAisle[aisle] case final group?) ...[
            SectionLabel(aisleName(l, aisle)),
            PanelList(
              children: [
                for (final i in group)
                  CheckboxListTile(
                    value: i.checked,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.fromLTRB(8, 2, 16, 2),
                    title: Text(
                      i.name,
                      style: TextStyle(
                        fontSize: 16,
                        decoration: i.checked
                            ? TextDecoration.lineThrough
                            : null,
                        color: i.checked ? c.muted : c.ink,
                      ),
                    ),
                    subtitle: i.forRecipe == null
                        ? null
                        : Text(l.forRecipe(i.forRecipe!)),
                    secondary: i.grams == null
                        ? null
                        : Text(
                            '${i.grams!.round()} g',
                            style: TextStyle(fontSize: 15, color: c.muted),
                          ),
                    onChanged: (on) {
                      checkShoppingItem(tools, i.id, on ?? false);
                      widget.data.changed();
                    },
                  ),
              ],
            ),
          ],
        if (ticked > 0) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () {
                clearCheckedShopping(tools);
                widget.data.changed();
              },
              child: Text(l.clearTickedN(ticked)),
            ),
          ),
        ],
      ],
    );
  }
}

String aisleName(AppLocalizations l, Aisle a) => switch (a) {
  Aisle.produce => l.aisleProduce,
  Aisle.meatFish => l.aisleMeatFish,
  Aisle.dairyEggs => l.aisleDairyEggs,
  Aisle.bakery => l.aisleBakery,
  Aisle.pantry => l.aislePantry,
  Aisle.spices => l.aisleSpices,
  Aisle.frozen => l.aisleFrozen,
  Aisle.drinks => l.aisleDrinks,
  Aisle.other => l.aisleOther,
};
