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

/// [count] recipes for [mealType] near [kcal] (the same picking as the plan), for "Ideas for your dinner".
List<RecipeSummary> mealIdeas(AgentTools tools, String mealType, double kcal, {int count = 2, Random? random}) {
  final rnd = random ?? Random();
  final pool = _pool(tools, mealType), used = <int>{};
  final ids = [for (var i = 0; i < count; i++) _pick(pool, kcal, used, tools.ratings(), rnd)];
  return [for (final id in ids) if (id != null) tools.recipeSummary(id)];
}

/// The share of the day's calories a planned meal is sized to; null for snacks.
double? mealShare(String mealType) => _share[mealType];

/// "Add to plan" on a recipe: that recipe for [mealType] on [day], replacing what was planned.
void planRecipe(AgentTools tools, DateTime day, String mealType, int id) => _set(tools, day, mealType, id);

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

typedef ShoppingItem = ({int id, String name, double? grams, bool checked, String? forRecipe, Aisle aisle});

/// Shop sections, in walking order.
enum Aisle { produce, meatFish, dairyEggs, bakery, pantry, spices, frozen, drinks, other }

List<ShoppingItem> shoppingList(AgentTools tools) {
  final rows = tools.user.select('SELECT * FROM shopping_list ORDER BY checked, name COLLATE NOCASE');
  final ids = [for (final r in rows) if (r['food_id'] != null) r['food_id'] as int];
  // The aisle comes from the database's English name: the list may show a translation.
  final english = ids.isEmpty
      ? const <int, String>{}
      : {for (final f in tools.nutri.select('SELECT id, name FROM foods WHERE id IN (${ids.join(',')})')) f['id'] as int: f['name'] as String};
  return [
    for (final r in rows)
      (
        id: r['id'] as int,
        name: r['name'] as String,
        grams: (r['grams'] as num?)?.toDouble(),
        checked: r['checked'] == 1,
        forRecipe: r['for_recipe'] as String?,
        aisle: aisleOf(english[r['food_id']] ?? r['name'] as String),
      )
  ];
}

/// The shop section for a food name (English, or what the user typed). First match wins, so
/// "chicken broth" is pantry before "chicken" is meat.
Aisle aisleOf(String name) {
  final n = name.toLowerCase();
  for (final (aisle, re) in _aisles) {
    if (re.hasMatch(n)) return aisle;
  }
  return Aisle.other;
}

final _aisles = [
  (Aisle.frozen, RegExp(r'\bfrozen\b|ice cream|заморож|tiefkühl|surgel')),
  (Aisle.drinks, RegExp(r'\b(juice|wine|beer|coffee|tea|soda|water|milk drink|kombucha|liqueur|vodka|rum)\b|сік|вино|кава|чай|saft|kaffee|jus|café|vin\b')),
  (Aisle.pantry, RegExp(r'broth|stock|bouillon|sauce|ketchup|mustard|mayonnaise|vinegar|\boil\b|flour|sugar|honey|syrup|'
      r'\brice\b|pasta|noodle|spaghetti|macaroni|lentil|bean|chickpea|pea\b|oat|cereal|quinoa|couscous|nut|almond|'
      r'peanut|walnut|cashew|seed|chocolate|cocoa|canned|tomato paste|jam|crumbs|baking|yeast|cornstarch|gelatin|'
      r'борошно|цукор|рис|макарон|сочевиц|квасол|олія|mehl|zucker|reis|nudel|linsen|bohnen|öl|farine|sucre|riz|pâtes|lentille|haricot|huile')),
  (Aisle.spices, RegExp(r'salt\b|pepper, black|spice|cinnamon|nutmeg|cumin|paprika|oregano|basil, dried|thyme|'
      r'rosemary|chili powder|curry|vanilla|bay leaf|ginger, ground|turmeric|clove|сіль|спец|salz|gewürz|sel\b|épice')),
  (Aisle.dairyEggs, RegExp(r'\b(milk|cheese|yogurt|yoghurt|butter|cream|kefir|egg|eggs|feta|mozzarella|parmesan|ricotta|'
      r'cheddar|curd)\b|молок|сир|йогурт|масло верш|яйц|вершк|кефір|milch|käse|joghurt|butter|sahne|\bei|lait|fromage|yaourt|beurre|crème|œuf')),
  (Aisle.meatFish, RegExp(r'\b(beef|pork|chicken|turkey|lamb|veal|duck|ham|bacon|sausage|salami|liver|steak|mince|'
      r'fish|salmon|tuna|cod|shrimp|prawn|crab|mussel|squid|sardine|trout|anchov)\w*|м.ясо|курк|свинин|ялович|риба|лосос|'
      r'fleisch|huhn|hähnchen|rind|schwein|fisch|lachs|viande|poulet|bœuf|porc|poisson|saumon')),
  (Aisle.bakery, RegExp(r'\b(bread|bun|roll|bagel|tortilla|pita|croissant|baguette|toast)\b|хліб|brot|pain\b')),
  (Aisle.produce, RegExp(r'\b(apple|banana|orange|lemon|lime|berr|grape|melon|pear|peach|plum|cherr|mango|pineapple|'
      r'avocado|tomato|potato|onion|garlic|carrot|pepper|cucumber|lettuce|spinach|cabbage|broccoli|cauliflower|'
      r'zucchini|squash|eggplant|mushroom|celery|kale|herb|parsley|cilantro|coriander|dill|basil|mint|ginger|'
      r'leek|radish|beet|corn|pumpkin|fruit|vegetable)\w*|яблук|банан|лимон|помідор|картопл|цибул|часник|морк|огір|'
      r'капуст|шпинат|гриб|кріп|apfel|zitrone|tomate|kartoffel|zwiebel|knoblauch|karotte|gurke|pomme|citron|oignon|ail\b|carotte')),
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
  final plan = plannedMealsFor(tools, from);
  tools.user.execute("DELETE FROM shopping_list WHERE source = 'plan' AND checked = 0");
  if (plan.isEmpty) return 0;
  final grams = <int, double>{};
  final forRecipe = <int, String>{};
  for (final p in plan) {
    for (final r in tools.nutri.select(
        'SELECT ri.food_id, ri.grams / r.servings AS g FROM recipe_ingredients ri JOIN recipes r ON r.id = ri.recipe_id '
        'WHERE ri.recipe_id = ?', [p.recipeId])) {
      grams.update(r['food_id'] as int, (g) => g + (r['g'] as num), ifAbsent: () => (r['g'] as num).toDouble());
      forRecipe.putIfAbsent(r['food_id'] as int, () => p.title);
    }
  }
  _addFoods(tools, grams, 'plan', forRecipe);
  return grams.length;
}

/// A recipe's ingredients for [servings] (null = all the recipe makes).
void addRecipeToShopping(AgentTools tools, int recipeId, {int? servings}) {
  final r = tools.nutri.select('SELECT title, servings FROM recipes WHERE id = ?', [recipeId]).single;
  final factor = servings == null ? 1.0 : servings / (r['servings'] as int);
  final grams = {
    for (final i in tools.nutri.select('SELECT food_id, grams FROM recipe_ingredients WHERE recipe_id = ?', [recipeId]))
      i['food_id'] as int: (i['grams'] as num) * factor
  };
  _addFoods(tools, grams, 'recipe', {for (final id in grams.keys) id: r['title'] as String});
}

void _addFoods(AgentTools tools, Map<int, double> grams, String source, Map<int, String> forRecipe) {
  for (final MapEntry(key: id, value: g) in grams.entries) {
    final name = tools.nutri.select(
        'SELECT ${tools.foodNameColumn} AS name FROM foods f ${tools.foodNameJoin} WHERE f.id = ?', [id]).single['name'] as String;
    tools.user.execute(
        'INSERT INTO shopping_list (food_id, name, grams, source, for_recipe) VALUES (?, ?, ?, ?, ?) '
        // Ticked = "I have it": left as it is (and not added to again on every plan rebuild).
        'ON CONFLICT (food_id) DO UPDATE SET grams = grams + excluded.grams WHERE shopping_list.checked = 0',
        [id, shoppingName(name), g, source, forRecipe[id]]);
  }
}

void addShoppingItem(AgentTools tools, String name) =>
    tools.user.execute("INSERT INTO shopping_list (name, source) VALUES (?, 'manual')", [name.trim()]);

void checkShoppingItem(AgentTools tools, int id, bool checked) =>
    tools.user.execute('UPDATE shopping_list SET checked = ? WHERE id = ?', [checked ? 1 : 0, id]);

void clearCheckedShopping(AgentTools tools) => tools.user.execute('DELETE FROM shopping_list WHERE checked = 1');

// ---- recipe box -------------------------------------------------------------------

/// The recipe box's lists: what the user saved, cooked (logged), rated 4-5 stars, or any of
/// those ready in 30 minutes; [query] searches every recipe instead. Never a recipe with the
/// profile's allergens, conditions' foods to avoid, or rated 1-2 stars.
enum RecipeShelf { saved, cooked, loved, quick }

List<RecipeSummary> recipeBox(AgentTools tools, {String query = '', RecipeShelf? shelf, int limit = 40}) {
  final excluded = tools.excludedRecipes();
  final saved = savedRecipeIds(tools);
  final cooked = {for (final r in tools.user.select('SELECT DISTINCT recipe_id FROM meal_log WHERE recipe_id IS NOT NULL')) r['recipe_id'] as int};
  final loved = {for (final e in tools.ratings().entries) if (e.value >= 4) e.key};
  final q = query.trim();
  final List<int> ids;
  if (q.length >= 2) {
    final words = [for (final m in RegExp(r'[a-z0-9]+').allMatches(q.toLowerCase())) if (m[0]!.length > 1) '"${m[0]}"*'];
    ids = words.isEmpty
        ? []
        : [for (final r in tools.nutri.select('SELECT rowid FROM recipes_fts WHERE recipes_fts MATCH ? ORDER BY bm25(recipes_fts) LIMIT 200',
              [words.join(' ')])) r['rowid'] as int];
  } else {
    ids = [...{...saved, ...cooked, ...loved}];
  }
  final pick = [
    for (final id in ids)
      if (!excluded.contains(id) &&
          switch (shelf) {
            RecipeShelf.saved => saved.contains(id),
            RecipeShelf.cooked => cooked.contains(id),
            RecipeShelf.loved => loved.contains(id),
            _ => true,
          })
        id
  ];
  final list = [for (final id in pick.take(shelf == RecipeShelf.quick ? 400 : limit)) tools.recipeSummary(id)];
  return shelf == RecipeShelf.quick ? [for (final r in list) if ((r.minutes ?? 999) <= 30) r].take(limit).toList() : list;
}

Set<int> savedRecipeIds(AgentTools tools) =>
    {for (final r in tools.user.select('SELECT recipe_id FROM saved_recipes ORDER BY saved_at DESC')) r['recipe_id'] as int};

/// The bookmark on a recipe card: saving needs no confirmation in the recipe box (the tap is it).
void setRecipeSaved(AgentTools tools, int id, bool saved) => saved
    ? tools.user.execute('INSERT OR REPLACE INTO saved_recipes (recipe_id, title, saved_at) VALUES (?, ?, ?)',
        [id, _title(tools, id), DateTime.now().millisecondsSinceEpoch])
    : tools.user.execute('DELETE FROM saved_recipes WHERE recipe_id = ?', [id]);

/// How often the recipe was logged as eaten.
int timesCooked(AgentTools tools, int id) =>
    tools.user.select('SELECT COUNT(*) AS n FROM meal_log WHERE recipe_id = ?', [id]).single['n'] as int;

