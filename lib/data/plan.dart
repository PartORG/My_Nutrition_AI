import 'dart:math';

import 'package:intl/intl.dart';

import '../agent/agent_tools.dart';
import 'goals.dart';

/// The planned meals; snacks aren't planned.
const plannedMeals = ['breakfast', 'lunch', 'dinner'];

/// Share of the day's calories per planned meal (the rest is snacks).
const _share = {'breakfast': .25, 'lunch': .35, 'dinner': .30};

typedef Planned = ({DateTime day, String mealType, int recipeId, String title, double kcal});

String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// [days] days from [from], each meal in [plannedMeals] order; missing slots are left out.
List<Planned> plannedMealsFor(AgentTools tools, DateTime from, {int days = 7}) {
  final keys = [for (var i = 0; i < days; i++) _key(DateTime(from.year, from.month, from.day + i))];
  final rows = tools.user.select(
      'SELECT * FROM meal_plan WHERE day IN (${List.filled(keys.length, '?').join(',')})', keys);
  final kcal = _kcal(tools, {for (final r in rows) r['recipe_id'] as int});
  return [
    for (final k in keys)
      for (final t in plannedMeals)
        for (final r in rows)
          if (r['day'] == k && r['meal_type'] == t)
            (day: DateTime.parse(k), mealType: t, recipeId: r['recipe_id'] as int, title: r['title'] as String,
                kcal: kcal[r['recipe_id']] ?? 0)
  ];
}

Map<int, double> _kcal(AgentTools tools, Set<int> ids) => ids.isEmpty
    ? {}
    : {
        for (final r in tools.nutri.select(
            'SELECT recipe_id, kcal FROM recipe_nutrition WHERE recipe_id IN (${ids.join(',')})'))
          r['recipe_id'] as int: (r['kcal'] as num).toDouble()
      };

/// Fills [days] days from [from] with recipes: tagged for the meal, sized to the meal's share
/// of the calorie goal, liked ones (4-5 stars) first, nothing excluded, no recipe twice.
/// Replaces what was planned for those days. Returns the plan.
List<Planned> planWeek(AgentTools tools, DateTime from, {int days = 7, Random? random}) {
  final rnd = random ?? Random();
  final used = <int>{};
  final dayKcal = currentTargets(tools.user, nutri: tools.nutri, now: from).values['kcal'] ?? 2000;
  final pools = {for (final t in plannedMeals) t: _pool(tools, t)};
  for (var i = 0; i < days; i++) {
    final day = DateTime(from.year, from.month, from.day + i);
    for (final t in plannedMeals) {
      final id = _pick(pools[t]!, dayKcal * _share[t]!, used, tools.ratings(), rnd);
      if (id != null) _set(tools, day, t, id);
    }
  }
  return plannedMealsFor(tools, from, days: days);
}

/// Another recipe for one planned meal (not one already in the plan).
void swapPlanned(AgentTools tools, DateTime day, String mealType, {Random? random}) {
  final rnd = random ?? Random();
  final used = {for (final r in tools.user.select('SELECT recipe_id FROM meal_plan')) r['recipe_id'] as int};
  final dayKcal = currentTargets(tools.user, nutri: tools.nutri, now: day).values['kcal'] ?? 2000;
  final id = _pick(_pool(tools, mealType), dayKcal * _share[mealType]!, used, tools.ratings(), rnd);
  if (id != null) _set(tools, day, mealType, id);
}

void _set(AgentTools tools, DateTime day, String mealType, int id) => tools.user.execute(
    'INSERT OR REPLACE INTO meal_plan (day, meal_type, recipe_id, title) '
    'VALUES (?, ?, ?, ?)', [_key(day), mealType, id, _title(tools, id)]);

String _title(AgentTools tools, int id) =>
    tools.nutri.select('SELECT title FROM recipes WHERE id = ?', [id]).single['title'] as String;

typedef _Candidate = ({int id, double kcal, int? minutes});

/// A random sample of recipes tagged for [mealType], with their kcal per serving, safe for the profile;
/// the user's liked recipes for that meal are always in it.
// ponytail: one random sample of 400 per meal; a full scan per pick if variety ever runs short.
// Two steps: joining the recipe_nutrition view first computes it for every recipe (5 s vs 0.1 s).
List<_Candidate> _pool(AgentTools tools, String mealType) {
  final excluded = tools.excludedRecipes();
  final liked = [for (final e in tools.ratings().entries) if (e.value >= 4) e.key];
  final rows = tools.nutri.select(
      "SELECT id, minutes FROM recipes WHERE ',' || tags || ',' LIKE ? AND id IN (${liked.join(',')}) "
      "UNION SELECT * FROM (SELECT id, minutes FROM recipes WHERE ',' || tags || ',' LIKE ? ORDER BY RANDOM() LIMIT 400)",
      ['%,$mealType,%', '%,$mealType,%']);
  final minutes = {for (final r in rows) if (!excluded.contains(r['id'])) r['id'] as int: r['minutes'] as int?};
  final kcal = _kcal(tools, minutes.keys.toSet());
  return [for (final e in minutes.entries) if (kcal[e.key] != null) (id: e.key, kcal: kcal[e.key]!, minutes: e.value)];
}

/// Closest to [target] kcal wins; 4-5 stars count as 25% closer, over an hour as 25% further.
/// Among the best five, one at random, so two plans differ.
int? _pick(List<_Candidate> pool, double target, Set<int> used, Map<int, int> stars, Random rnd) {
  double cost(_Candidate c) =>
      (c.kcal - target).abs() / target * ((stars[c.id] ?? 3) >= 4 ? .75 : 1) * ((c.minutes ?? 0) > 60 ? 1.25 : 1);
  final ranked = pool.where((c) => !used.contains(c.id)).toList()..sort((a, b) => cost(a).compareTo(cost(b)));
  if (ranked.isEmpty) return null;
  final id = ranked[rnd.nextInt(min(5, ranked.length))].id;
  used.add(id);
  return id;
}

// ---- shopping list ---------------------------------------------------------------

typedef ShoppingItem = ({int id, String name, double? grams, bool checked});

List<ShoppingItem> shoppingList(AgentTools tools) => [
      for (final r in tools.user.select('SELECT * FROM shopping_list ORDER BY checked, name COLLATE NOCASE'))
        (id: r['id'] as int, name: r['name'] as String, grams: (r['grams'] as num?)?.toDouble(),
            checked: r['checked'] == 1)
    ];

/// "Cheese, feta" stays (sorting groups an aisle together); "Bananas, raw" → "Bananas";
/// at most two parts: "Spices, pepper, black" → "Spices, pepper".
String shoppingName(String food) {
  final parts = food.split(', ');
  final keep = [
    for (final p in parts)
      if (!RegExp(r'^(raw|fresh|cooked|boiled|canned|frozen|dried|drained|unprepared|prepared|whole)$', caseSensitive: false)
          .hasMatch(p))
        p
  ];
  return (keep.isEmpty ? parts : keep).take(2).join(', ');
}

/// The plan's ingredients from [from] on (one serving per planned meal), replacing the
/// previous plan items; what the user ticked or typed stays.
int shoppingFromPlan(AgentTools tools, DateTime from) {
  final ids = [for (final p in plannedMealsFor(tools, from)) p.recipeId];
  tools.user.execute("DELETE FROM shopping_list WHERE source = 'plan' AND checked = 0");
  if (ids.isEmpty) return 0;
  final grams = <int, double>{};
  for (final id in ids) {
    for (final r in tools.nutri.select(
        'SELECT ri.food_id, ri.grams / r.servings AS g FROM recipe_ingredients ri JOIN recipes r ON r.id = ri.recipe_id '
        'WHERE ri.recipe_id = ?', [id])) {
      grams.update(r['food_id'] as int, (g) => g + (r['g'] as num), ifAbsent: () => (r['g'] as num).toDouble());
    }
  }
  _addFoods(tools, grams, 'plan');
  return grams.length;
}

/// A whole recipe's ingredients (as the recipe states them, all servings).
void addRecipeToShopping(AgentTools tools, int recipeId) => _addFoods(tools, {
      for (final r in tools.nutri.select('SELECT food_id, grams FROM recipe_ingredients WHERE recipe_id = ?', [recipeId]))
        r['food_id'] as int: (r['grams'] as num).toDouble()
    }, 'recipe');

void _addFoods(AgentTools tools, Map<int, double> grams, String source) {
  for (final MapEntry(key: id, value: g) in grams.entries) {
    final name = tools.nutri.select(
        'SELECT ${tools.foodNameColumn} AS name FROM foods f ${tools.foodNameJoin} WHERE f.id = ?', [id]).single['name'] as String;
    tools.user.execute(
        'INSERT INTO shopping_list (food_id, name, grams, source) VALUES (?, ?, ?, ?) '
        // Ticked = "I have it": left as it is (and not added to again on every plan rebuild).
        'ON CONFLICT (food_id) DO UPDATE SET grams = grams + excluded.grams WHERE shopping_list.checked = 0',
        [id, shoppingName(name), g, source]);
  }
}

void addShoppingItem(AgentTools tools, String name) =>
    tools.user.execute("INSERT INTO shopping_list (name, source) VALUES (?, 'manual')", [name.trim()]);

void checkShoppingItem(AgentTools tools, int id, bool checked) =>
    tools.user.execute('UPDATE shopping_list SET checked = ? WHERE id = ?', [checked ? 1 : 0, id]);

void clearCheckedShopping(AgentTools tools) => tools.user.execute('DELETE FROM shopping_list WHERE checked = 1');
