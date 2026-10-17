import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_tools.dart';
import '../app_state.dart';
import '../data/diary.dart';
import 'meal_editor.dart' show showLoggedSnack;
import '../l10n/app_localizations.dart';
import 'camera_screen.dart';
import 'home_screen.dart' show logMealProvider;
import 'kit.dart';
import 'nutrients.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;
import 'voice.dart';

/// Search the food database and log an amount, no AI involved.
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  final _search = TextEditingController();
  late final _voice = Dictation(_search, () {
    if (mounted) setState(() => _results = _find(_search.text));
  });
  List<FoodChoice> _results = [];
  String? _kind; // null = everything (or recent, before searching)
  late String _meal = ref.read(logMealProvider) ?? ref.read(profileDataProvider)?.tools.mealTypeNow() ?? 'snack';

  @override
  void dispose() {
    _voice.dispose();
    _search.dispose();
    super.dispose();
  }

  List<FoodChoice> _find(String t) =>
      t.trim().length < 2 ? [] : ref.read(profileDataProvider)?.tools.searchFood(t) ?? [];

  Future<void> _pick(FoodChoice food) async {
    final data = ref.read(profileDataProvider);
    if (data == null) return;
    final mark = lastMealId(data.user);
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AmountSheet(food: food, meal: _meal),
    );
    if (logged == true && mounted) showLoggedSnack(context, data, AppLocalizations.of(context)!.loggedSnack(food.label), mark);
  }

  Future<void> _quickAdd(ProfileData data) async {
    final mark = lastMealId(data.user);
    final label = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickAddSheet(data: data, meal: _meal),
    );
    if (label != null && mounted) showLoggedSnack(context, data, AppLocalizations.of(context)!.loggedSnack(label), mark);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
    // "+" on a meal card: follow it, then forget it, so the next visit goes by the clock again.
    ref.listen(logMealProvider, (_, meal) {
      if (meal != null) setState(() => _meal = meal);
    });
    final kinds = {'food': l.kindFood, 'dish': l.kindDish, 'recipe': l.kindRecipe, 'product': l.kindProduct};
    final searching = _search.text.trim().length >= 2;
    final now = DateTime.now();
    final all = searching ? _results : recentFoods(data.user, now);
    final list = _kind == null ? all : [for (final f in all) if (f.kind == _kind || (_kind == 'recipe' && f.kind == 'recipe')) f];
    final yesterday = now.subtract(const Duration(days: 1));
    final yMeals = [for (final m in mealsOn(data.user, yesterday)) if (m.type == _meal) m];
    final photo = _ActionButton(
      icon: Icons.photo_camera_outlined,
      label: l.snapPhoto,
      badge: const Tag('PRO', tone: TagTone.gold),
      onTap: () => openCamera(context, 'photo'),
    );
    final quick = _ActionButton(icon: Icons.add, label: l.quickAdd, onTap: () => _quickAdd(data));
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: ScreenHeader(title: l.logFoodTitle)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.list(children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.searchFood,
              suffixIcon: Padding(
                padding: const EdgeInsets.all(4),
                child: MicButton(dictation: _voice, onPressed: () => _voice.toggle(context)),
              ),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.primary)),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (t) => setState(() => _results = _find(t)),
          ),
          const SizedBox(height: 14),
          // Two other ways in, kept small: the search is the lead. Large text: one under the other.
          if (MediaQuery.textScalerOf(context).scale(10) > 15)
            Column(children: [photo, const SizedBox(height: 10), quick])
          else
            Row(children: [Expanded(child: photo), const SizedBox(width: 10), Expanded(child: quick)]),
          if (!searching && yMeals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Panel(
              color: c.mint,
              border: false,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(children: [
                Icon(Icons.replay, color: c.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.yesterdaysMeal(inSentence(context, mealName(l, _meal))),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('${yMeals.map((m) => m.label).join(', ')} · ${yMeals.fold(0.0, (s, m) => s + m.kcal).round()} ${l.kcal}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.ink2)),
                  ]),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: () {
                    final mark = lastMealId(data.user);
                    final n = repeatMeal(data.user, yesterday, _meal, DateTime.now());
                    data.changed();
                    setState(() {});
                    showLoggedSnack(context, data, l.reviewLogged(n), mark);
                  },
                  child: Text(l.logButton),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final (k, label) in [(null, searching ? l.kindAll : l.kindRecent), ...kinds.entries.map((e) => (e.key, e.value))])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _KindTab(label: label, selected: _kind == k, onTap: () => setState(() => _kind = k)),
                ),
            ]),
          ),
          const SizedBox(height: 10),
        ]),
      ),
      if (list.isEmpty && searching)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(data.tools.products == null ? '${l.noResults}\n${l.productsHint}' : l.noResults,
                textAlign: TextAlign.center),
          ),
        )
      else if (list.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: PanelList(children: [
              for (final f in list)
                InkWell(
                  onTap: () => _pick(f),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.label, style: const TextStyle(fontSize: 16)),
                          Text('${kinds[f.kind] ?? l.kindRecent} · ${f.estimated ? '≈' : ''}${_per(l, f)}',
                              style: TextStyle(fontSize: 13, color: c.muted)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l.logButton,
                        child: Material(
                          shape: CircleBorder(side: BorderSide(color: c.outline)),
                          color: c.surface,
                          child: SizedBox.square(dimension: 48, child: Icon(Icons.add, color: c.primary)),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
    ]);
  }

  static String _per(AppLocalizations l, FoodChoice f) => f.servingG == null
      ? l.per100g(f.per100['kcal']!.round())
      : l.perServing2((f.per100['kcal']! * f.servingG! / 100).round());
}

/// "Snap a photo" and "Quick add": one line each, beside each other under the search.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.badge});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: Radii.tile,
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: c.primary, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink))),
        if (badge != null) ...[const SizedBox(width: 6), badge!],
      ]),
    );
  }
}

/// Recent · Food · Dish · Recipe · Product: the selected one in a mint pill.
class _KindTab extends StatelessWidget {
  const _KindTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.mint : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(label,
                  style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? c.primary : c.muted)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Just 350 kcal" for a meal no search finds; macros optional. Pops with the label logged.
class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({required this.data, required this.meal});
  final ProfileData data;
  final String meal;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _name = TextEditingController();
  final _values = {for (final k in ['kcal', 'protein_g', 'carbs_g', 'fat_g']) k: TextEditingController()};
  late String _meal = widget.meal;

  @override
  void dispose() {
    _name.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String k) => double.tryParse(_values[k]!.text.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = nutrientLabels(l);
    final kcal = _num('kcal');
    TextField field(String k, {bool autofocus = false}) => TextField(
          controller: _values[k],
          autofocus: autofocus,
          decoration: InputDecoration(labelText: labels[k]!.$1, suffixText: labels[k]!.$2.isEmpty ? l.kcal : labels[k]!.$2),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.quickAdd, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // Calories first: all a quick add needs. The rest is optional.
          field('kcal', autofocus: true),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: InputDecoration(labelText: l.quickAddName)),
          const SizedBox(height: 8),
          Row(children: [
            for (final (i, k) in const ['protein_g', 'carbs_g', 'fat_g'].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: field(k)),
            ],
          ]),
          const SizedBox(height: 12),
          ChoicePills<String>(
            values: const ['breakfast', 'lunch', 'dinner', 'snack'],
            selected: _meal,
            label: (t) => mealName(l, t),
            scroll: true,
            onChanged: (t) => setState(() => _meal = t),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: kcal == null || kcal <= 0 || kcal > 5000
                ? null
                : () {
                    final name = _name.text.trim().isEmpty ? l.quickAdd : _name.text.trim();
                    widget.data.tools.quickAdd(name, {for (final k in _values.keys) k: _num(k) ?? 0}, _meal);
                    widget.data.changed();
                    Navigator.pop(context, name);
                  },
            child: Text(l.logButton),
          ),
        ]),
      ),
    );
  }
}

class _AmountSheet extends ConsumerStatefulWidget {
  const _AmountSheet({required this.food, required this.meal});
  final FoodChoice food;
  final String meal;

  @override
  ConsumerState<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends ConsumerState<_AmountSheet> {
  late final _grams = TextEditingController(text: '${(widget.food.servingG ?? 100).round()}');
  late String _meal = widget.meal;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double get grams => double.tryParse(_grams.text.replaceAll(',', '.')) ?? 0;

  void _servings(double delta) {
    final s = widget.food.servingG!;
    final next = ((grams / s) + delta).clamp(.5, 20);
    setState(() => _grams.text = '${(next * s).round()}');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final food = widget.food;
    final values = food.per100.map((k, v) => MapEntry(k, v * grams / 100));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(food.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (food.servingG != null) ...[
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: Text(l.servingsAmount((grams / food.servingG!).toStringAsFixed(1)),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              _Step(icon: Icons.remove, tooltip: l.lessServing, onPressed: () => _servings(-.5)),
              const SizedBox(width: 8),
              _Step(icon: Icons.add, tooltip: l.moreServing, onPressed: () => _servings(.5)),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _grams,
          decoration: InputDecoration(labelText: l.grams, suffixText: 'g'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ChoicePills<String>(
          values: const ['breakfast', 'lunch', 'dinner', 'snack'],
          selected: _meal,
          label: (t) => mealName(l, t),
          onChanged: (t) => setState(() => _meal = t),
        ),
        const SizedBox(height: 12),
        NutrientTiles(values: values, estimated: food.estimated),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: grams <= 0
                ? null
                : () {
                    final data = ref.read(profileDataProvider);
                    if (data == null) return;
                    data.tools.logFood(food, grams, _meal);
                    data.changed();
                    Navigator.of(context).pop(true);
                  },
            child: Text(l.logButton),
          ),
        ),
      ]),
    );
  }
}

/// A round outlined − or + (servings).
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
            minimumSize: const Size(52, 52), side: BorderSide(color: context.colors.outline), shape: const CircleBorder()),
        onPressed: onPressed,
        icon: Icon(icon),
      );
}
