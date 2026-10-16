import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../agent/agent_tools.dart' show RecipeListCard, RecipeSummary;
import '../app_state.dart';
import '../billing/billing.dart';
import '../data/goals.dart';
import '../data/plan.dart';
import '../l10n/app_localizations.dart';
import 'camera_screen.dart';
import 'kit.dart';
import 'paywall_screen.dart' show LockedCard, TierBuilder;
import 'recipe_screen.dart';
import 'theme.dart';
import 'voice.dart';

enum PlanTab { plan, recipes, shopping }

/// The Plan tab: the week's plan (Basic), the recipe box, and the shopping list (Basic).
class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.data,
    this.initialTab = PlanTab.plan,
  });
  final ProfileData data;
  final PlanTab initialTab;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
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
          PlanTab.recipes => (l.recipesTitle, null),
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
                  ScreenHeader(
                    title: title,
                    trailing: aside == null
                        ? null
                        : Text(
                            aside,
                            style: TextStyle(fontSize: 15, color: c.muted),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
    padding: const EdgeInsets.all(20),
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

    if (plan.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Panel(child: Text(l.planEmpty, style: const TextStyle(fontSize: 16))),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: Text(l.planWeek),
            onPressed: () => update(() => planWeek(tools, today)),
          ),
        ],
      );
    }
    final dayMeals = [
      for (final p in plan)
        if (DateUtils.isSameDay(p.day, _day)) p,
    ];
    final planned = dayMeals.fold(0.0, (s, p) => s + p.kcal);
    final goal = currentTargets(
      widget.data.user,
      nutri: widget.data.nutri,
      now: _day,
    ).values['kcal'];
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        SizedBox(
          height: 72 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayChip(
                      day: today.add(Duration(days: i)),
                      selected: DateUtils.isSameDay(
                        _day,
                        today.add(Duration(days: i)),
                      ),
                      locale: locale,
                      onTap: () =>
                          setState(() => _day = today.add(Duration(days: i))),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final p in dayMeals) ...[
          Panel(
            onTap: () => open(p.recipeId),
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              children: [
                _MealBadge(type: p.mealType),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mealCaps(l, p.mealType),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .6,
                          color: c.muted,
                        ),
                      ),
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _recipeLine(context, tools.recipeSummary(p.recipeId)),
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.planSwap,
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () =>
                      update(() => swapPlanned(tools, p.day, p.mealType)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                l.plannedFor(DateFormat.EEEE(locale).format(_day)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              goal == null
                  ? '${planned.round()} ${l.kcal}'
                  : l.planOfKcal(planned.round(), goal.round()),
              style: TextStyle(
                fontSize: 15,
                color: c.ink2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (goal != null) ...[
          const SizedBox(height: 8),
          Bar(
            value: planned / goal,
            color: nutrientColors['kcal'],
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
            style: TextStyle(fontSize: 14, color: c.muted),
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
    );
  }

  static String _mealCaps(AppLocalizations l, String t) => switch (t) {
    'breakfast' => l.mealBreakfast,
    'lunch' => l.mealLunch,
    _ => l.mealDinner,
  }.toUpperCase();
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
        color: selected ? c.dark : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? c.dark : c.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.E(locale).format(day),
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? c.background : c.muted,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.background : c.ink,
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

/// AM / NOON / PM in the meal's tint.
class _MealBadge extends StatelessWidget {
  const _MealBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final (bg, fg, label) = switch (type) {
      'breakfast' => (c.warm, c.onWarm, l.badgeMorning),
      'lunch' => (c.mint, c.onMint, l.badgeNoon),
      _ => (c.waterBg, c.water, l.badgeEvening),
    };
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
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
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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
                color: c.dark,
                border: false,
                onTap: _whatCanICook,
                child: Row(
                  children: [
                    Icon(Icons.soup_kitchen_outlined, color: c.gold, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.whatCanICook,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: c.background,
                            ),
                          ),
                          Text(
                            l.whatCanICookBody,
                            style: TextStyle(
                              fontSize: 14,
                              color: c.background.withValues(alpha: .78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.background),
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
                Panel(
                  child: Text(
                    _cook != null ? l.cookNone : l.boxEmpty,
                    style: TextStyle(color: c.muted),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent:
                  220 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => _RecipeTile(
              recipe: list[i],
              saved: saved.contains(list[i].id),
              stars: tools.rating(list[i].id),
              onSave: (on) =>
                  setState(() => setRecipeSaved(tools, list[i].id, on)),
              onOpen: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecipeScreen(
                        tools: tools,
                        recipeId: list[i].id,
                        onLogged: widget.data.changed,
                      ),
                    ),
                  )
                  .then((_) => setState(() {})),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Text(
              l.boxFootnote,
              style: TextStyle(fontSize: 14, color: c.muted),
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
    return Panel(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              RecipeArt(title: recipe.title, height: 100),
              Positioned(
                top: 6,
                right: 6,
                child: RoundIconButton(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  tooltip: saved ? l.removeSaved : l.cardSaveRecipe,
                  foreground: c.primary,
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    [
                      _recipeLine(context, recipe),
                      if (stars != null) '★ $stars',
                    ].join(' · '),
                    maxLines: 2,
                    style: TextStyle(fontSize: 13, color: c.muted),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
            child: Text(l.shoppingEmpty),
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
