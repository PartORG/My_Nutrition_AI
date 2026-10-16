import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../data/conditions.dart';
import '../data/diary.dart' show logWater, pref, setPref;
import '../data/goals.dart';
import '../data/journal.dart';

/// Nutrient columns shared by foods, dishes, products, meal_log and the
/// recipe_nutrition view.
const nutrients = ['kcal', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g', 'sugar_g', 'sodium_mg'];

/// Per 100 g where known (USDA SR28 foods, recipes made of them, meals logged from those);
/// a missing key means unknown, not zero. Dishes and packaged products have none.
const micronutrients = [
  'calcium_mg', 'iron_mg', 'magnesium_mg', 'potassium_mg', 'vitamin_c_mg', 'vitamin_d_ug', 'vitamin_b12_ug',
];
typedef Nutrients = Map<String, double>;

typedef RecipeSummary = ({int id, String title, int? minutes, double kcal, double protein});
typedef Passage = ({String source, String text});

/// What the chat shows under a model message. Numbers come from here, never
/// from the model's text.
sealed class AgentCard {}

class RecipeListCard extends AgentCard {
  RecipeListCard(this.recipes, {this.avoided = const []});
  final List<RecipeSummary> recipes;

  /// What the user asked for but can't have (allergy or diet), left out of these recipes.
  final List<String> avoided;
}

class RecipeCard extends AgentCard {
  RecipeCard({required this.id, required this.title, required this.instructions, required this.minutes,
      required this.servings, required this.ingredients, required this.perServing, this.cautions = const [],
      this.translatedNames = false});
  final int id;
  final String title, instructions;
  final int? minutes;
  final int servings;
  final List<({String name, double grams})> ingredients;
  final Nutrients perServing;

  /// Some ingredient names are machine translations (food_names), not the database's own.
  final bool translatedNames;

  /// Ingredients that hit the profile's allergies or conditions. Search never
  /// suggests such a recipe; this shows when the user opens it by name.
  final List<Caution> cautions;
}

/// [food] is on the profile's list because of [allergen] or [condition].
typedef Caution = ({String food, String? allergen, String? condition});

class NutritionCard extends AgentCard {
  NutritionCard({required this.title, required this.values, this.estimated = false, this.goals = const {}});
  final String title;
  final Nutrients values;
  final bool estimated;
  final Nutrients goals; // empty = no goals set
}

class InfoCard extends AgentCard {
  InfoCard(this.passages);
  final List<Passage> passages;
}

class CameraCard extends AgentCard {
  CameraCard(this.mode);
  final String mode;
}

/// One food on a meal card. [grams] can change on the card before Save.
class MealItem {
  MealItem({required this.label, required this.grams, required this.per100, this.estimated = false, this.recipeId});
  final String label;
  double grams;
  final Nutrients per100;
  final bool estimated;
  final int? recipeId;
  Nutrients get values => per100.map((k, v) => MapEntry(k, v * grams / 100));
}

/// A write the model proposed. Nothing is stored until the user taps ✓.
class ConfirmCard extends AgentCard {
  ConfirmCard({required String title, List<String> lines = const [], required void Function(ConfirmCard) apply,
      this.mealType, this.items = const []})
      // ignore: prefer_initializing_formals
      : _title = title,
        // ignore: prefer_initializing_formals
        _lines = lines,
        // ignore: prefer_initializing_formals
        _apply = apply;
  final String _title;
  final List<String> _lines;

  /// Meal cards: the foods, editable; [lines] then also lists them.
  final List<MealItem> items;

  List<String> get lines => [
        for (final i in items) '${i.label} · ${i.grams.round()} g · ${i.estimated ? '≈' : ''}${i.values['kcal']!.round()} kcal',
        ..._lines,
      ];
  final void Function(ConfirmCard) _apply;
  bool? accepted; // null = not decided yet

  /// Meal cards only: the meal it is logged under. The user can change it on
  /// the card before Save, so it never depends on the time of day alone.
  String? mealType;

  String get title => mealType == null ? _title : 'Log $mealType';
  void apply() => _apply(this);
}

class ToolResult {
  ToolResult(this.forModel, [this.card]);
  ToolResult.error(String message) : this({'error': message});
  final Map<String, Object?> forModel;
  final AgentCard? card;
}

const _pendingNote = 'NOT saved yet: the user must tap Save on the card. Tell them to tap Save.';

/// Runs the agent's tools against nutri.db (read-only) and the profile's
/// user.db. Writes only happen through [ConfirmCard.apply].
class AgentTools {
  AgentTools(this.nutri, this.user, {DateTime Function()? clock, this.products})
      : _now = clock ?? DateTime.now;

  final Database nutri, user;

  /// The optional download of every Open Food Facts product (products.db); null = the
  /// 2019 products inside nutri.db. Set when the download finishes.
  Database? products;
  final DateTime Function() _now;

  /// The app's language: recipe ingredients show in it where nutri.db has a translation.
  String language = 'en';

  /// `name` of food `f` in [language]: food_names (machine-translated or reviewed), else foods.name.
  // An older nutri.db without the table (before data_version 2) shows the English names.
  late final bool _hasFoodNames =
      nutri.select("SELECT 1 FROM sqlite_master WHERE name = 'food_names'").isNotEmpty;
  String get foodNameJoin => _hasFoodNames
      ? "LEFT JOIN food_names fn ON fn.food_id = f.id AND fn.lang = '${language.replaceAll("'", '')}'"
      : '';
  String get foodNameColumn => _hasFoodNames ? 'COALESCE(fn.name, f.name)' : 'f.name';

  /// Recipe ids of the last list shown, so "recipe 2" / "the first one" resolve.
  /// Kept in user.db: after a restart the replayed chat still shows that list.
  List<int> get _lastRecipes => [for (final id in (pref(user, 'last_recipes') ?? '').split(',')) ?int.tryParse(id)];
  set _lastRecipes(List<int> ids) => setPref(user, 'last_recipes', ids.join(','));
  int? _lastShown;

  /// Every recipe suggested since the app started, so asking again shows new ones.
  final _suggested = <int>{};

  /// Their titles, lower case: nutri.db has 40 different "Banana bread" recipes,
  /// and a second one is not "something new".
  final _suggestedTitles = <String>{};

  /// [said] is the user's message: a small model sometimes picks the wrong
  /// tool, so "I ate peanuts" never adds an allergy and "I had 2 eggs" never
  /// turns into recipe ideas.
  ToolResult run(String name, Map<String, dynamic> args, {String said = ''}) {
    String arg(String k) => '${args[k] ?? ''}'.trim();
    final remove = args['remove'] == true || args['remove'] == 'true';
    return switch (name) {
      'set_allergen' when !remove && said.isNotEmpty && !_lasting(said) => _ateWords.hasMatch(said)
          ? _logMeal(said, '')
          : ToolResult.error('the user did not state a lasting allergy, intolerance or diet, so nothing was added. '
              '"Vegan tonight" or "vegetarian dinner ideas" is a recipe wish: search recipes instead'),
      // "Vegan tonight" is not a fact about the user; "I'm vegan" is a diet, which filters recipes.
      'remember_fact' when _dietWords.hasMatch(arg('fact')) && _oneOff.hasMatch(said) =>
        ToolResult.error('a wish for one meal is not a lasting fact, so nothing was remembered; help with the request'),
      'remember_fact' when _dietStatement.hasMatch(said) && _dietAllergens.containsKey(normalizeAllergen(arg('fact'))) =>
        _setAllergen(normalizeAllergen(arg('fact')), false),
      'search_recipes' when _ateWords.hasMatch(said) && !_recipeWords.hasMatch(said) => _logMeal(said, ''),
      'search_recipes' => _searchRecipes(arg('query'), arg('ingredients'), said),
      // Anything but save/rate shows: the one action that writes nothing.
      'recipe' => switch (arg('action')) {
          'save' => _saveRecipe(arg('recipe')),
          'rate' => _rateRecipe(arg('recipe'), int.tryParse(arg('stars'))),
          _ => _showRecipe(arg('recipe')),
        },
      'lookup_nutrition' => _lookupNutrition(arg('food')),
      'nutrition_status' => _nutritionStatus(arg('period')),
      'log_meal' => _logMeal(arg('items'), arg('meal_type')),
      'remember_fact' => _remember(arg('fact')),
      'set_allergen' => _setAllergen(arg('allergen'), remove),
      'log_health' when arg('kind') == 'symptom' => _logSymptom(arg('value'), int.tryParse(arg('severity'))),
      'log_health' => _logReading(arg('kind'), arg('value')),
      'condition_info' => _conditionInfo(arg('question')),
      'open_camera' => ToolResult({
          'status': 'a card with a camera button is shown; the user taps it (Pro plan). Nothing is logged '
              'until they check the result and tap Log',
        }, CameraCard(arg('mode'))),
      _ => ToolResult.error('unknown tool $name'),
    };
  }

  /// The intent router: a message that plainly logs food ("I ate 2 eggs") or
  /// states an allergy ("I'm allergic to peanuts") gets its card at once, without
  /// the model (seconds faster, and it can't pick the wrong tool). Null = ask the model.
  ToolResult? route(String said) {
    if (_statusAsk.hasMatch(said)) return _nutritionStatus(_weekWords.hasMatch(said) ? 'week' : 'today');
    if (_recipeRef.firstMatch(said) case final m?) {
      final id = _resolveRecipe(m[2]!);
      if (id == null) return null; // no list to point into: the model asks which one
      return _saveWords.hasMatch(m[1]!) ? _saveRecipeById(id) : showRecipeById(id);
    }
    // "Can you suggest good dinner recipes? Maybe with fish?": the search itself picks the food
    // words out of the sentence, so fish is never lost on the way through the model.
    if (_ideasAsk.hasMatch(said) && !_notIdeas.hasMatch(said)) {
      final r = _searchRecipes(said, '', said);
      return r.card == null ? null : r; // nothing found: the model asks what they'd like
    }
    if (said.contains('?') || _recipeWords.hasMatch(said)) return null;
    if (_allergyStatement.hasMatch(said) || (_dietStatement.hasMatch(said) && !_oneOff.hasMatch(said))) {
      final allergen = normalizeAllergen(said);
      return _allergenNames.contains(allergen) ? _setAllergen(allergen, false) : null;
    }
    if (!_ateStatement.hasMatch(said) || _allergyWords.hasMatch(said)) return null;
    if (waterMl(mealFoods(said)) case final ml?) {
      return ToolResult({'status': _pendingNote, 'water_ml': ml}, ConfirmCard(
        title: 'Log water',
        lines: ['Water · ${ml.round()} ml'],
        apply: (_) => logWater(user, ml, _now()),
      ));
    }
    final r = _logMeal(said, '');
    // Nothing found → the model asks what was meant.
    return r.card is ConfirmCard && !r.forModel.containsKey('not_found') ? r : null;
  }

  // ---- recipes ------------------------------------------------------------

  ToolResult _searchRecipes(String query, String ingredients, [String said = '']) {
    var wanted = _wanted(query, ingredients);
    // "More" / "other ideas" naming no food and no meal: the last ask again, so salmon and
    // tomatoes aren't lost on the way through the model (the app never repeats a recipe).
    if (_lastAsk case (final q, final i)
        when wanted.isEmpty && _moreAsk.hasMatch('$query $said') && !_mealTypes.any('$query $said'.toLowerCase().contains)) {
      (query, ingredients) = (q, i);
      wanted = _wanted(query, ingredients);
    }
    _lastAsk = (query, ingredients);
    // Asked for something the profile can't have ("peanut recipes", allergic to peanuts):
    // it's left out, and the card says why instead of quietly showing other recipes.
    final unsafeFoods = _unsafeFoods();
    final avoided = {
      for (final MapEntry(key: item, value: foods) in wanted.entries)
        if (foods.every(unsafeFoods.contains)) _allergenNames.contains(normalizeAllergen(item)) ? normalizeAllergen(item) : item
    };
    wanted.removeWhere((_, foods) => foods.every(unsafeFoods.contains));
    final has = <int, Set<String>>{};
    for (final MapEntry(key: item, value: foods) in wanted.entries) {
      for (final r in nutri.select(
          'SELECT DISTINCT recipe_id FROM recipe_ingredients WHERE food_id IN (${foods.join(',')})')) {
        (has[r['recipe_id'] as int] ??= {}).add(item);
      }
    }
    // Every wanted ingredient a recipe has outranks any title match: beef, mustard and honey
    // first, honey-mustard chicken after.
    final scores = <int, double>{for (final e in has.entries) e.key: 10.0 * e.value.length};
    for (final id in _ftsIds(nutri, 'recipes_fts', '$query $ingredients', limit: 200)) {
      if (wanted.isEmpty || scores.containsKey(id)) scores.update(id, (s) => s + 1, ifAbsent: () => 1);
    }
    // Stars steer ideas: 4-5 rank higher, 1-2 are never suggested again; and recipes sharing the
    // ingredients of liked and saved ones rank higher (taste, not just that one recipe).
    final stars = _ratings();
    for (final MapEntry(key: id, value: s) in stars.entries) {
      if (scores.containsKey(id)) scores[id] = scores[id]! + (s - 3) * 0.75;
    }
    // Only the best 300 can make the five shown; "chicken" alone matches tens of thousands.
    final top = (scores.keys.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!))).take(300);
    for (final MapEntry(key: id, value: b) in _tasteBoost(top).entries) {
      scores[id] = scores[id]! + b;
    }
    final unsafe = _blockedRecipes();
    final blocked = {...unsafe, for (final e in stars.entries) if (e.value <= 2) e.key};
    var ranked = scores.keys.where((id) => !blocked.contains(id)).toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    // A vague ask ("something new for dinner") matches nothing: random ideas for the meal.
    // Everything asked for is ruled out: titles naming it ("peanut noodles, peanut-free") don't count either.
    if (wanted.isEmpty && avoided.isNotEmpty) ranked = [];
    if (ranked.isEmpty && (_split(ingredients).isEmpty || avoided.isNotEmpty)) ranked = _randomRecipes(query, blocked);
    final titles = {
      for (final r in nutri.select('SELECT id, title FROM recipes WHERE id IN (${ranked.join(',')})'))
        r['id'] as int: (r['title'] as String).toLowerCase().trim()
    };
    final seen = {..._suggestedTitles};
    final fresh = [for (final id in ranked) if (!_suggested.contains(id) && seen.add(titles[id]!)) id];
    final shown = (fresh.isEmpty ? ranked : fresh).take(5).toList();
    _suggested.addAll(shown);
    _suggestedTitles.addAll([for (final id in shown) titles[id]!]);
    if (shown.isEmpty) {
      return ToolResult({
        'recipes': [],
        'note': 'no matching recipe in the database',
        if (avoided.isNotEmpty) 'avoided': 'the user is allergic to or avoids ${avoided.join(', ')}: say so',
      });
    }
    _lastRecipes = shown;
    final list = [for (final id in shown) _summary(id)];
    return ToolResult({
      'recipes': [
        for (final (i, r) in list.indexed)
          '${i + 1}. ${r.title} (${r.kcal.round()} kcal per serving${r.minutes == null ? '' : ', ${r.minutes} min'}'
              '${_missing(wanted.keys, has[r.id])})'
      ],
      if (unsafe.isNotEmpty) 'note': 'recipes with the user\'s allergens or foods to avoid for their conditions were excluded',
      if (avoided.isNotEmpty) 'avoided': 'the user is allergic to or avoids ${avoided.join(', ')}, so these recipes are without it',
      if (fresh.isEmpty) 'repeated': 'no new recipe matches; these were suggested before, so say so and ask for other ingredients',
    }, RecipeListCard(list, avoided: avoided.toList()));
  }

  /// What the user wants in it: the ingredients the model passed, plus the food words of the
  /// query ("dinner recipes with fish" -> fish), each with the recipe foods it names.
  Map<String, Set<int>> _wanted(String query, String ingredients) {
    final items = _split(ingredients).map((i) => i.toLowerCase()).toList();
    return {
      for (final item in [
        ...items,
        for (final w in _words(query))
          if (!_notIngredients.contains(w) && int.tryParse(w) == null && !items.any((i) => i.contains(w))) w,
      ])
        if (_ingredientFoods(item) case final foods when foods.isNotEmpty) item: foods,
    };
  }

  /// The last recipe search's (query, ingredients).
  (String, String)? _lastAsk;

  /// Recipe foods with one of the profile's allergens, or that its diets exclude.
  Set<int> _unsafeFoods() {
    final diets = _myAllergens();
    final mine = {for (final a in diets) ...(_dietAllergens[a] ?? [a])}.toList();
    return {
      if (mine.isNotEmpty)
        for (final r in nutri.select(
            'SELECT food_id FROM allergens WHERE allergen IN (${List.filled(mine.length, '?').join(',')})', mine))
          r['food_id'] as int,
      ..._dietFoods(diets),
    };
  }

  /// ", without honey" for a recipe that lacks some of what the user asked for.
  static String _missing(Iterable<String> wanted, Set<String>? has) {
    final missing = [for (final w in wanted) if (!(has?.contains(w) ?? false)) w];
    return missing.isEmpty ? '' : ', without ${missing.join(', ')}';
  }

  /// The foods recipes use that [item] names: every word of it in the food's name ("ground
  /// beef" -> "Beef, ground, 80% lean"), and for a group ("fish", "nuts") every food of it.
  Set<int> _ingredientFoods(String item) => _foodsFor.putIfAbsent(item, () {
        final words = _words(item);
        if (words.isEmpty) return {};
        final patterns = [
          for (final w in words)
            RegExp(w.endsWith('y') ? '\\b${w.substring(0, w.length - 1)}(?:y|ies)\\b' : '\\b$w(?:e?s)?\\b')
        ];
        final ids = {for (final f in _recipeFoods) if (patterns.every((p) => p.hasMatch(f.name))) f.id};
        final group = normalizeAllergen(item);
        if (words.length == 1 && _allergenNames.contains(group) && !_dietAllergens.containsKey(group)) {
          ids.addAll([
            for (final r in nutri.select(
                'SELECT food_id FROM allergens WHERE allergen = ? AND food_id IN (SELECT food_id FROM recipe_ingredients)',
                [group]))
              r['food_id'] as int
          ]);
        }
        return ids;
      });

  final _foodsFor = <String, Set<int>>{};

  // ponytail: ~2k names held in memory and scanned per new ingredient word; an FTS table would scale.
  late final _recipeFoods = [
    for (final r in nutri.select(
        'SELECT id, lower(name) AS name FROM foods WHERE id IN (SELECT DISTINCT food_id FROM recipe_ingredients)'))
      (id: r['id'] as int, name: r['name'] as String)
  ];

  /// Up to 20 random recipes tagged with the meal named in [query], else the meal for now.
  List<int> _randomRecipes(String query, Set<int> blocked) {
    final meal = _mealTypes.firstWhere(query.toLowerCase().contains, orElse: () => _mealTypeFor(_now()));
    final picks = [
      for (final r in nutri.select(
          "SELECT id FROM recipes WHERE ',' || tags || ',' LIKE ? ORDER BY RANDOM() LIMIT 40", ['%,$meal,%']))
        if (!blocked.contains(r['id'])) r['id'] as int
    ];
    // Still random, but closest to the user's taste first.
    final boost = _tasteBoost(picks);
    return (picks..sort((a, b) => (boost[b] ?? 0).compareTo(boost[a] ?? 0))).take(20).toList();
  }

  /// Taste from recipes rated 4-5 stars or saved: their ingredients, each weighted by how rare it is
  /// among all recipes (chickpeas say more than salt; foods in over 5% of recipes, and at least 3, say nothing).
  /// Each of [candidates] gets up to 3 points for sharing them: enough to reorder ideas, never enough
  /// to beat an ingredient the user asked for (10).
  Map<int, double> _tasteBoost(Iterable<int> candidates) {
    final liked = {
      for (final r in user.select('SELECT recipe_id FROM recipe_ratings WHERE stars >= 4 UNION SELECT recipe_id FROM saved_recipes'))
        r['recipe_id'] as int
    };
    final ids = candidates.toSet()..removeAll(liked);
    if (liked.isEmpty || ids.isEmpty) return {};
    final total = nutri.select('SELECT COUNT(*) AS n FROM recipes').single['n'] as int;
    final weight = <int, double>{
      for (final r in nutri.select(
          'SELECT food_id, (SELECT COUNT(*) FROM recipe_ingredients x WHERE x.food_id = ri.food_id) AS df '
          'FROM recipe_ingredients ri WHERE recipe_id IN (${liked.join(',')}) GROUP BY food_id'))
        if ((r['df'] as int) <= max(3, total * .05)) r['food_id'] as int: log(total / (r['df'] as int))
    };
    if (weight.isEmpty) return {};
    final boost = <int, double>{};
    for (final r in nutri.select(
        'SELECT recipe_id, food_id FROM recipe_ingredients WHERE food_id IN (${weight.keys.join(',')}) '
        'AND recipe_id IN (${ids.join(',')})')) {
      final id = r['recipe_id'] as int;
      boost[id] = min(3, (boost[id] ?? 0) + .3 * weight[r['food_id']]!);
    }
    return boost;
  }

  /// Recipes containing any allergen the profile has, or any food its
  /// conditions say to avoid. Kept even after a downgrade from Medium.
  Set<int> _blockedRecipes() {
    final diets = _myAllergens();
    final mine = {for (final a in diets) ...(_dietAllergens[a] ?? [a])}.toList();
    final avoid = {...avoidedFoods(nutri, user).keys, ..._dietFoods(diets)};
    if (mine.isEmpty && avoid.isEmpty) return {};
    return {
      for (final r in nutri.select(
          'SELECT DISTINCT ri.recipe_id FROM recipe_ingredients ri '
          'LEFT JOIN allergens a ON a.food_id = ri.food_id '
          'WHERE a.allergen IN (${List.filled(mine.length, '?').join(',')}) OR ri.food_id IN (${avoid.join(',')})',
          mine))
        r['recipe_id'] as int
    };
  }

  /// The profile's allergies and diets, as stored in user_allergens.
  /// The profile's allergens and diets ("peanuts", "vegetarian").
  List<String> myAllergens() => _myAllergens();

  List<String> _myAllergens() =>
      [for (final r in user.select('SELECT allergen FROM user_allergens')) r['allergen'] as String];

  /// Recipe foods a diet in [mine] excludes by name (meat; for vegans also honey and
  /// gelatin). Fish, eggs and milk come from nutri.db's allergens via [_dietAllergens].
  Set<int> _dietFoods(List<String> mine) {
    if (!mine.any(_dietAllergens.containsKey)) return {};
    return {
      ...(_meatIds ??= _recipeFoodsNamed(_meat)),
      if (mine.contains('vegan')) ...(_veganIds ??= _recipeFoodsNamed(_notVegan)),
    };
  }

  Set<int>? _meatIds, _veganIds;

  // ponytail: name keywords, like the cloud app's RESTRICTION_INGREDIENT_MAP; a food group
  // column in nutri.db would be exact. Scans only the ~2k foods recipes use.
  Set<int> _recipeFoodsNamed(RegExp re) => {
        for (final r in nutri.select('SELECT id, name FROM foods WHERE id IN (SELECT food_id FROM recipe_ingredients)'))
          if (re.hasMatch(r['name'] as String) && !_meatFree.hasMatch(r['name'] as String)) r['id'] as int
      };

  /// Ingredients of [recipeId] on the profile's allergy or condition lists, one per food.
  List<Caution> _cautions(int recipeId) {
    final avoid = avoidedFoods(nutri, user);
    final mine = _myAllergens();
    // nutri.db allergen -> what the user said: 'fish' -> 'fish', or 'vegetarian' for a vegetarian.
    final why = {for (final a in mine) for (final x in _dietAllergens[a] ?? [a]) x: a};
    final diet = mine.where(_dietAllergens.containsKey).firstOrNull;
    final dietFoods = _dietFoods(mine);
    final byFood = <int, Caution>{};
    for (final r in nutri.select(
        'SELECT f.id, f.name, a.allergen FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id '
        'LEFT JOIN allergens a ON a.food_id = f.id WHERE ri.recipe_id = ? ORDER BY f.name', [recipeId])) {
      final id = r['id'] as int;
      final allergen = why[r['allergen']] ?? (dietFoods.contains(id) ? diet : null);
      if (allergen == null && !avoid.containsKey(id)) continue;
      byFood[id] = (food: r['name'] as String, allergen: allergen ?? byFood[id]?.allergen, condition: avoid[id]);
    }
    return byFood.values.toList();
  }

  /// Title, minutes, kcal and protein per serving.
  RecipeSummary recipeSummary(int id) => _summary(id);

  RecipeSummary _summary(int id) {
    final r = nutri.select(
        'SELECT r.title, r.minutes, n.kcal, n.protein_g FROM recipes r JOIN recipe_nutrition n ON n.recipe_id = r.id '
        'WHERE r.id = ?', [id]).single;
    return (id: id, title: r['title'] as String, minutes: r['minutes'] as int?,
        kcal: (r['kcal'] as num).toDouble(), protein: (r['protein_g'] as num).toDouble());
  }

  /// "2", "recipe 2", "the second one", "last", or a title.
  int? _resolveRecipe(String ref) {
    final lower = ref.toLowerCase();
    // Before ordinals: "that one" means the recipe just shown, not recipe #1.
    // "rate it" with nothing shown yet: the recipe eaten last.
    final shown = _lastShown ?? recentRecipes(limit: 1).firstOrNull?.id;
    if (RegExp(r'\b(that|this|it|last)\b').hasMatch(lower) && shown != null) return shown;
    const ordinals = {'first': 1, 'second': 2, 'third': 3, 'one': 1, 'two': 2, 'three': 3};
    final n = int.tryParse(RegExp(r'\d+').firstMatch(lower)?[0] ?? '') ??
        ordinals.entries.where((e) => RegExp('\\b${e.key}\\b').hasMatch(lower)).firstOrNull?.value;
    final last = _lastRecipes;
    if (n != null && n >= 1 && n <= last.length) return last[n - 1];
    // "recipe 2" with no such list: a title search for "2" would open a random recipe.
    if (_bareRecipeRef.hasMatch(lower)) return null;
    return _ftsIds(nutri, 'recipes_fts', ref, limit: 1).firstOrNull;
  }

  ToolResult _showRecipe(String ref) {
    final id = _resolveRecipe(ref);
    if (id == null) return ToolResult.error('no recipe matches "$ref"');
    return showRecipeById(id);
  }

  /// Also what a tap on a recipe list item calls directly, without the model,
  /// so a tap can't open the wrong recipe and "save it" refers to this one.
  ToolResult showRecipeById(int id) {
    _lastShown = id;
    final r = nutri.select('SELECT * FROM recipes WHERE id = ?', [id]).single;
    final rows = nutri.select(
        'SELECT $foodNameColumn AS name, $foodNameColumn != f.name AS translated, ri.grams FROM recipe_ingredients ri '
        'JOIN foods f ON f.id = ri.food_id $foodNameJoin WHERE ri.recipe_id = ? ORDER BY ri.grams DESC', [id]);
    final ingredients = [for (final i in rows) (name: i['name'] as String, grams: (i['grams'] as num).toDouble())];
    final perServing = _nutrientsOf(nutri.select(
        'SELECT * FROM recipe_nutrition WHERE recipe_id = ?', [id]).single);
    final card = RecipeCard(
      id: id,
      title: r['title'] as String,
      instructions: r['instructions'] as String,
      minutes: r['minutes'] as int?,
      servings: r['servings'] as int,
      ingredients: ingredients,
      perServing: perServing,
      cautions: _cautions(id),
      translatedNames: rows.any((i) => i['translated'] == 1),
    );
    return ToolResult({
      'title': card.title,
      'minutes': card.minutes,
      'servings': card.servings,
      'kcal_per_serving': perServing['kcal']!.round(),
      'ingredients': [for (final i in ingredients) '${i.grams.round()} g ${i.name}'],
      'note': 'the full recipe is shown in a card with an "I ate this" button that logs one serving',
      if (card.cautions.isNotEmpty)
        'caution': 'contains ${card.cautions.map((c) => c.food).toSet().join(', ')}, which the user\'s '
            'allergies or conditions list; the card shows this. Mention it and offer other recipes',
    }, card);
  }

  /// "I ate this" on a recipe card: one serving, through the same ✓ card.
  ToolResult logRecipe(int recipeId, {double servings = 1}) {
    final title = _summary(recipeId).title;
    final grams = servings * _recipeServingGrams(recipeId);
    final at = _ms();
    return ToolResult({'status': _pendingNote, 'recipe': title}, ConfirmCard(
      title: 'Log meal',
      mealType: _mealTypeForRecipe(recipeId),
      items: [MealItem(label: title, grams: grams, per100: _recipePer100(recipeId), recipeId: recipeId)],
      apply: (c) => _insertItems(at, c),
    ));
  }

  ToolResult _saveRecipe(String ref) {
    final id = _resolveRecipe(ref);
    if (id == null) return ToolResult.error('no recipe matches "$ref"');
    return _saveRecipeById(id);
  }

  ToolResult _saveRecipeById(int id) {
    final title = _summary(id).title;
    return ToolResult({
      'status': _pendingNote,
      'recipe': title,
      'note': 'saving is a bookmark only; it does NOT log the meal as eaten',
    }, ConfirmCard(
      title: 'Save recipe',
      lines: [title],
      apply: (_) => user.execute(
          'INSERT OR REPLACE INTO saved_recipes (recipe_id, title, saved_at) VALUES (?, ?, ?)',
          [id, title, _ms()]),
    ));
  }

  ToolResult _rateRecipe(String ref, int? stars) {
    final id = _resolveRecipe(ref);
    if (id == null) return ToolResult.error('no recipe matches "$ref"');
    if (stars == null || stars < 1 || stars > 5) return ToolResult.error('ask the user for 1 to 5 stars');
    final title = _summary(id).title;
    return ToolResult({
      'status': _pendingNote,
      'recipe': title,
      'stars': stars,
      'note': stars <= 2 ? 'it will not be suggested again' : 'liked recipes are suggested more often',
    }, ConfirmCard(title: 'Rate recipe', lines: ['$title · ${'★' * stars}${'☆' * (5 - stars)}'], apply: (_) => rate(id, stars)));
  }

  // ---- nutrition ----------------------------------------------------------

  ToolResult _lookupNutrition(String food) {
    final id = _ftsIds(nutri, 'foods_fts', food, limit: 1).firstOrNull;
    if (id == null) return ToolResult.error('"$food" is not in the food database');
    final r = nutri.select('SELECT * FROM foods WHERE id = ?', [id]).single;
    final per100 = _nutrientsOf(r);
    return ToolResult({
      'food': r['name'],
      'per_100g': per100.map((k, v) => MapEntry(k, _round(v))),
      'typical_serving_g': ?r['serving_g'],
    }, NutritionCard(title: '${r['name']} · per 100 g', values: per100));
  }

  ToolResult _nutritionStatus(String period) {
    final now = _now();
    final week = period == 'week';
    final from = week ? now.subtract(const Duration(days: 7)) : DateTime(now.year, now.month, now.day);
    final r = user.select(
        'SELECT COUNT(*) AS meals, ${[for (final n in nutrients) 'TOTAL($n) AS $n'].join(', ')} '
        'FROM meal_log WHERE eaten_at >= ?', [from.millisecondsSinceEpoch]).single;
    final totals = _nutrientsOf(r);
    final daily = currentTargets(user, nutri: nutri, now: now).values;
    final goals = daily.map((k, v) => MapEntry(k, week ? v * 7 : v));
    return ToolResult({
      'period': week ? 'last 7 days' : 'today',
      'meals_logged': r['meals'],
      'eaten': totals.map((k, v) => MapEntry(k, _round(v))),
      'goals': goals.isEmpty
          ? 'not set; suggest setting them in the Me tab'
          : goals.map((k, v) => MapEntry(k, _round(v))),
      if (!week && goals.isNotEmpty)
        'left_today': {for (final e in goals.entries) e.key: _round(e.value - totals[e.key]!)},
      if (r['meals'] == 0)
        'note': 'nothing logged ${week ? 'in the last 7 days' : 'today'}. Saved recipes do not count as eaten; '
            'offer to log what the user ate',
    }, NutritionCard(title: week ? 'Last 7 days' : 'Today', values: totals, goals: goals));
  }

  ToolResult _logMeal(String items, String mealType) {
    // The model (or the user's own words) may say "I ate ... for breakfast": keep only the foods.
    mealType = _mealTypes.contains(mealType)
        ? mealType
        : _mealTypes.firstWhere(items.toLowerCase().contains, orElse: () => '');
    items = mealFoods(items);
    if (items.isEmpty) return ToolResult.error('the user did not say what they ate; ask them');
    // "overnight oats with banana" is one recipe; "chicken with rice" is two foods,
    // and so is "liver in cream" (else cream is silently dropped).
    final parts = _isDishName(items) ? [items] : _split(items.replaceAll(RegExp(r'\bin\b', caseSensitive: false), ','));
    final parsed = [for (final item in parts) _portion(item)];
    final found = [for (final p in parsed) ?p];
    final missing = [for (final (i, p) in parsed.indexed) if (p == null) parts[i]];
    if (found.isEmpty) {
      return ToolResult.error('could not find "${missing.join('", "')}" in the food database; '
          'ask the user to name the food differently or give grams');
    }
    // The model's choice, else the recipe's own tag ("Shakshuka" is breakfast
    // even at 20:00), else the time of day. The user can still change it.
    final type = _mealTypes.contains(mealType)
        ? mealType
        : found.map((p) => p.recipeId).nonNulls.map(_mealTypeForRecipe).firstOrNull ?? _mealTypeFor(_now());
    final total = <String, double>{for (final n in nutrients) n: 0};
    for (final p in found) {
      for (final n in nutrients) {
        total[n] = total[n]! + p.values[n]!;
      }
    }
    final at = _ms();
    return ToolResult({
      'status': _pendingNote,
      'meal_type': type,
      'items': [for (final p in found) '${p.label} ${p.grams.round()} g'],
      'kcal': total['kcal']!.round(),
      if (missing.isNotEmpty) 'not_found': missing,
    }, ConfirmCard(
      title: 'Log meal',
      mealType: type,
      items: [
        for (final p in found)
          MealItem(label: p.label, grams: p.grams, per100: _per100(p.values, p.grams), estimated: p.estimated,
              recipeId: p.recipeId),
      ],
      lines: [if (missing.isNotEmpty) 'Not found: ${missing.join(', ')}'],
      apply: (c) => _insertItems(at, c),
    ));
  }

  /// The whole phrase is exactly a dish or recipe name (same content words),
  /// so it must not be split on "and"/"with".
  bool _isDishName(String text) {
    final said = _words(text.replaceFirst(RegExp(r'^\s*\d+(?:[.,]\d+)?\s*'), ''));
    bool same(String name) => _words(name).length == said.length && _words(name).containsAll(said);
    return _ftsIds(nutri, 'dishes_fts', text, limit: 3)
            .any((id) => same(nutri.select('SELECT name FROM dishes WHERE id = ?', [id]).single['name'] as String)) ||
        _ftsIds(nutri, 'recipes_fts', text, limit: 3).any((id) => same(_summary(id).title));
  }

  /// "2 eggs", "200 g greek yogurt", "3 slices of pizza", "lasagna".
  ({String label, double grams, Nutrients values, bool estimated, int? recipeId})? _portion(String item) {
    // "about 200 g rice" is 200 g, not a default serving of "about 200 g rice". Items arrive
    // in English: the model translates, and route() only handles English.
    item = item.replaceAll(RegExp(r'(?:\b(?:about|around|roughly|approx(?:imately)?|maybe|some|almost|nearly)\b|~)\.?\s*', caseSensitive: false), '');
    // "grapes 100 gramms" → "100 g grapes"
    item = item.trim().replaceFirstMapped(
        RegExp(r'^([^\d]+?)\s*[-:]?\s*(\d+(?:[.,]\d+)?)\s*([a-z]*)\.?$', caseSensitive: false),
        (m) => '${m[2]} ${m[3]} ${m[1]}');
    final m = RegExp(
      // \b after the quantity word and unit: "almonds" is not "a lmonds", "greek" not "g reek".
      r'^(?:(\d+(?:[.,]\d+)?)|(an?|one|two|three|four|five|half(?: a)?)\b)?\s*'
      r'(?:(kg|g|gr|grams?|gramm?e?s?|ml|slices?|pieces?|portions?|servings?|bowls?|cups?|plates?|handfuls?)\b)?\s*'
      r'(?:of\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(item.trim())!;
    const words = {'a': 1.0, 'an': 1.0, 'one': 1.0, 'two': 2.0, 'three': 3.0, 'four': 4.0, 'five': 5.0};
    final qtyWord = m[2]?.toLowerCase();
    final qty = double.tryParse((m[1] ?? '').replaceAll(',', '.')) ??
        (qtyWord == null ? 1.0 : (qtyWord.startsWith('half') ? 0.5 : words[qtyWord]!));
    final unit = m[3]?.toLowerCase() ?? '';
    final name = m[4]!;
    double grams(double? serving) => switch (unit) {
          'kg' => qty * 1000,
          'ml' => qty,
          _ when unit.startsWith('g') => qty, // g, gr, gram(s), gramm(s)
          _ => qty * (serving ?? 100),
        };
    Nutrients scale(Nutrients per100, double g) => per100.map((k, v) => MapEntry(k, v * g / 100));

    if (staples[name.trim().toLowerCase()] case (final label, final serving)) {
      if (nutri.select('SELECT * FROM foods WHERE name = ? COLLATE NOCASE', [label]).firstOrNull case final f?) {
        final g = grams(serving ?? (f['serving_g'] as num?)?.toDouble());
        return (label: f['name'] as String, grams: g, values: scale(_nutrientsOf(f), g), estimated: false, recipeId: null);
      }
    }

    // The candidate whose name the user said most completely wins: "banana" is
    // the food, not "Overnight oats with banana"; "lentil soup" is the recipe,
    // "chicken caesar salad" the dish. Ties: dish, then recipe, then food.
    final candidates = [
      for (final id in _ftsIds(nutri, 'dishes_fts', name, limit: 3))
        ('dish', id, nutri.select('SELECT name FROM dishes WHERE id = ?', [id]).single['name'] as String, 2),
      if (unit.isEmpty) // "200 g of shakshuka" is weighed food, not servings of a recipe
        for (final id in _ftsIds(nutri, 'recipes_fts', name, limit: 3))
          ('recipe', id, _summary(id).title, 2),
      for (final id in _ftsIds(nutri, 'foods_fts', name, limit: 10)) // search ranks "Cream Puff" above "Cream, fluid"
        for (final f in nutri.select('SELECT name, source FROM foods WHERE id = ?', [id]))
          ('food', id, f['name'] as String, authority(f['source'] as String)),
    ];
    // The plain food first: "banana" is "Banana", not "Banana chips, banana",
    // which search ranks higher for repeating the word.
    final n = name.trim();
    final forms = {n, if (n.length > 3 && n.endsWith('s')) n.substring(0, n.length - 1),
        if (n.length > 4 && n.endsWith('es')) n.substring(0, n.length - 2)};
    final names = [for (final f in forms) ...[f, '$f, raw']];
    final plain = nutri.select(
        'SELECT id, source FROM foods WHERE name COLLATE NOCASE IN (${List.filled(names.length, '?').join(',')}) '
        'ORDER BY length(name) LIMIT 1', names).firstOrNull;
    if (plain != null) candidates.insert(0, ('food', plain['id'] as int, name, authority(plain['source'] as String)));
    if (candidates.isEmpty) return null;
    final said = _words(name);
    double share(Iterable<String> words, Set<String> among) =>
        words.isEmpty ? 0 : words.where(among.contains).length / words.length;
    // Best first: has every word the user said ("chicken liver" is not "Chicken breast"); its main
    // part, before a comma, is what they said ("cream" is "Cream, fluid", not "ice cream");
    // then the fewest unsaid words; then a government table over a branded or small dataset.
    // Ties keep the earlier one: dish, then recipe, then food.
    List<double> score((String, int, String, int) c) {
      final words = _words(c.$3);
      return [share(said, words), share(_words(c.$3.split(RegExp(r'[,(]')).first), said), share(words, said), c.$4.toDouble()];
    }
    bool better(List<double> a, List<double> b) {
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return a[i] > b[i];
      }
      return false;
    }
    final (kind, id, _, _) = candidates.reduce((best, c) => better(score(c), score(best)) ? c : best);

    switch (kind) {
      case 'dish':
        final d = nutri.select('SELECT * FROM dishes WHERE id = ?', [id]).single;
        final g = grams((d['serving_g'] as num).toDouble());
        // The linked recipe is for opening and rating; the dish's own values win (it may have none).
        final recipeId = d['recipe_id'] as int?;
        final per100 = d['kcal'] != null || recipeId == null ? _nutrientsOf(d) : _recipePer100(recipeId);
        return (label: d['name'] as String, grams: g, values: scale(per100, g), estimated: true, recipeId: recipeId);
      case 'recipe':
        final g = qty * _recipeServingGrams(id);
        return (label: _summary(id).title, grams: g, values: scale(_recipePer100(id), g), estimated: false, recipeId: id);
      default:
        final f = nutri.select('SELECT * FROM foods WHERE id = ?', [id]).single;
        final g = grams((f['serving_g'] as num?)?.toDouble());
        return (label: f['name'] as String, grams: g, values: scale(_nutrientsOf(f), g), estimated: false, recipeId: null);
    }
  }

  Nutrients _recipePer100(int recipeId) {
    final r = nutri.select(
        // SUM for micronutrients: NULL when no ingredient knows them (unknown, not 0).
        'SELECT ${[for (final n in nutrients) 'TOTAL(f.$n * ri.grams) / TOTAL(ri.grams) AS $n'].join(', ')}, '
        '${[for (final m in micronutrients) 'SUM(f.$m * ri.grams) / TOTAL(ri.grams) AS $m'].join(', ')} '
        'FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id WHERE ri.recipe_id = ?',
        [recipeId]).single;
    return _nutrientsOf(r);
  }

  static const _mealTypes = {'breakfast', 'lunch', 'dinner', 'snack'};

  /// First meal tag of the recipe ('breakfast,vegetarian' → breakfast), else the time of day.
  String _mealTypeForRecipe(int recipeId) =>
      (nutri.select('SELECT tags FROM recipes WHERE id = ?', [recipeId]).single['tags'] as String)
          .split(',')
          .map((t) => t.trim())
          .where(_mealTypes.contains)
          .firstOrNull ??
      _mealTypeFor(_now());

  static String _mealTypeFor(DateTime t) =>
      t.hour < 11 ? 'breakfast' : t.hour < 16 ? 'lunch' : t.hour < 21 ? 'dinner' : 'snack';

  // ---- memory, allergies, journal --------------------------------------------

  ToolResult _remember(String fact) {
    if (fact.isEmpty) return ToolResult.error('empty fact');
    return ToolResult({'status': _pendingNote, 'fact': fact}, ConfirmCard(
      title: 'Remember',
      lines: [fact],
      apply: (_) => user.execute('INSERT INTO memory_facts (text, created_at) VALUES (?, ?)', [fact, _ms()]),
    ));
  }

  ToolResult _setAllergen(String raw, bool remove) {
    final allergen = normalizeAllergen(raw);
    if (allergen.isEmpty) return ToolResult.error('which allergen?');
    return ToolResult({'status': _pendingNote, 'allergen': allergen, 'remove': remove}, ConfirmCard(
      title: _dietAllergens.containsKey(allergen)
          ? (remove ? 'Remove diet' : 'Add diet')
          : (remove ? 'Remove allergy' : 'Add allergy'),
      lines: [allergen],
      apply: (_) => remove
          ? user.execute('DELETE FROM user_allergens WHERE allergen = ?', [allergen])
          : user.execute('INSERT OR IGNORE INTO user_allergens (allergen, added_at) VALUES (?, ?)',
              [allergen, _ms()]),
    ));
  }

  ToolResult _logSymptom(String symptom, int? severity) {
    if (symptom.isEmpty) return ToolResult.error('which symptom?');
    final s = severity != null && severity >= 1 && severity <= 5 ? severity : null;
    return ToolResult({'status': _pendingNote, 'symptom': symptom, 'severity': s}, ConfirmCard(
      title: 'Log symptom',
      lines: [s == null ? symptom : '$symptom · severity $s/5'],
      apply: (_) => logSymptom(user, symptom, s, at: _now()),
    ));
  }

  ToolResult _logReading(String kind, String value) {
    final nums = [
      for (final m in RegExp(r'\d+(?:[.,]\d+)?').allMatches(value))
        double.parse(m[0]!.replaceAll(',', '.'))
    ];
    final lower = value.toLowerCase();
    final reading = switch (kind) {
      'glucose' when nums.isNotEmpty =>
        (v: nums[0], v2: null, unit: lower.contains('mmol') || nums[0] < 35 ? 'mmol/L' : 'mg/dL'),
      'blood_pressure' when nums.length >= 2 => (v: nums[0], v2: nums[1], unit: 'mmHg'),
      'weight' when nums.isNotEmpty =>
        (v: nums[0], v2: null, unit: RegExp(r'lb|pound').hasMatch(lower) ? 'lb' : 'kg'),
      _ => null,
    };
    if (reading == null) return ToolResult.error('could not read a $kind value from "$value"; ask the user');
    // Exact, as the user said it: 72.5 kg must not become 73.
    final text = '${exactNumber(reading.v)}${reading.v2 == null ? '' : '/${exactNumber(reading.v2!)}'} ${reading.unit}';
    return ToolResult({'status': _pendingNote, 'kind': kind, 'value': text}, ConfirmCard(
      title: 'Log ${kind.replaceAll('_', ' ')}',
      lines: [text],
      apply: (_) => logReading(user, kind, reading.v, reading.unit, value2: reading.v2, at: _now()),
    ));
  }

  ToolResult _conditionInfo(String question) {
    final passages = [
      for (final id in _ftsIds(nutri, 'docs_fts', question, limit: 2))
        for (final r in nutri.select('SELECT source, text FROM docs WHERE id = ?', [id]))
          (source: r['source'] as String, text: r['text'] as String)
    ];
    if (passages.isEmpty) {
      return ToolResult({'passages': [], 'note': 'nothing in the database; say so and suggest asking a doctor'});
    }
    return ToolResult({
      'passages': [for (final p in passages) p.text],
      'note': 'answer only from these passages, mention they are general information '
          'and not medical advice, and suggest discussing changes with a doctor',
    }, InfoCard(passages));
  }

  // ---- helpers --------------------------------------------------------------

  int _ms() => _now().millisecondsSinceEpoch;

  /// A meal card's items as the user left them (0 g = removed).
  void _insertItems(int at, ConfirmCard c) {
    for (final i in c.items) {
      if (i.grams > 0) _insertMeal(at, c.mealType!, i.label, i.grams, i.values, i.estimated, i.recipeId);
    }
  }

  static Nutrients _per100(Nutrients values, double grams) =>
      values.map((k, v) => MapEntry(k, grams > 0 ? v * 100 / grams : 0));

  /// The one place a meal_log row is written (chat card, "I ate this", Log tab).
  void _insertMeal(int at, String type, String label, double? grams, Nutrients values, bool estimated,
          [int? recipeId]) =>
      user.execute(
        'INSERT INTO meal_log (eaten_at, meal_type, description, grams, ${[...nutrients, ...micronutrients].join(', ')}, '
        'estimated, recipe_id) VALUES (?, ?, ?, ?, ${List.filled(nutrients.length + micronutrients.length, '?').join(', ')}, ?, ?)',
        [at, type, label, grams, for (final n in [...nutrients, ...micronutrients]) values[n], estimated ? 1 : 0, recipeId],
      );

  // ---- ratings ----------------------------------------------------------------

  /// 1-5 stars; null = not rated.
  int? rating(int recipeId) =>
      user.select('SELECT stars FROM recipe_ratings WHERE recipe_id = ?', [recipeId]).firstOrNull?['stars'] as int?;

  /// A tap on a star is the user's confirmation, as on the Log tab.
  void rate(int recipeId, int stars) => user.execute(
      'INSERT OR REPLACE INTO recipe_ratings (recipe_id, stars, rated_at) VALUES (?, ?, ?)',
      [recipeId, stars.clamp(1, 5), _ms()]);

  /// Recipes never to suggest or plan: the profile's allergens, foods its conditions
  /// avoid, and recipes the user rated 1-2 stars.
  Set<int> excludedRecipes() => {..._blockedRecipes(), for (final e in _ratings().entries) if (e.value <= 2) e.key};

  /// Recipe id -> the user's stars.
  Map<int, int> ratings() => _ratings();

  Map<int, int> _ratings() =>
      {for (final r in user.select('SELECT recipe_id, stars FROM recipe_ratings')) r['recipe_id'] as int: r['stars'] as int};

  /// The newest distinct recipes the user logged as eaten, with their stars.
  List<({int id, String title, DateTime at, int? stars})> recentRecipes({int limit = 5}) => [
        for (final r in user.select(
            'SELECT m.recipe_id, MAX(m.eaten_at) AS at, r.stars FROM meal_log m '
            'LEFT JOIN recipe_ratings r ON r.recipe_id = m.recipe_id WHERE m.recipe_id IS NOT NULL '
            'GROUP BY m.recipe_id ORDER BY at DESC LIMIT ?', [limit]))
          for (final t in nutri.select('SELECT title FROM recipes WHERE id = ?', [r['recipe_id']]))
            (id: r['recipe_id'] as int, title: t['title'] as String,
                at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int), stars: r['stars'] as int?)
      ];

  // ---- Log tab: search and log without the model ---------------------------------

  /// Foods, dishes, recipes and packaged products matching [text], best first.
  List<FoodChoice> searchFood(String text, {int limit = 20}) {
    FoodChoice of(String kind, Row r, double? serving, Nutrients per100, {bool estimated = false}) =>
        (kind: kind, id: r['id'], label: r['name'] as String, servingG: serving, per100: per100, estimated: estimated);
    return [
      for (final id in _ftsIds(nutri, 'dishes_fts', text, limit: 5))
        for (final r in nutri.select('SELECT *, id FROM dishes WHERE id = ?', [id]))
          of('dish', r, (r['serving_g'] as num).toDouble(),
              r['kcal'] != null || r['recipe_id'] == null ? _nutrientsOf(r) : _recipePer100(r['recipe_id'] as int),
              estimated: true),
      for (final id in _ftsIds(nutri, 'recipes_fts', text, limit: 5))
        for (final r in nutri.select('SELECT id, title AS name FROM recipes WHERE id = ?', [id]))
          of('recipe', r, _recipeServingGrams(id), _recipePer100(id)),
      // Government tables first, then search order: "egg" is USDA's egg before a brand's.
      for (final r in [
        for (final id in _ftsIds(nutri, 'foods_fts', text, limit: limit))
          ...nutri.select('SELECT * FROM foods WHERE id = ?', [id])
      ].indexed.toList()
        ..sort((a, b) => switch (authority(b.$2['source'] as String) - authority(a.$2['source'] as String)) {
              0 => a.$1 - b.$1,
              final d => d,
            }))
        of('food', r.$2, (r.$2['serving_g'] as num?)?.toDouble(), _nutrientsOf(r.$2)),
      // Every word must match: among millions of products "any word" buries the one meant.
      for (final r in (products ?? nutri).select(
          'SELECT p.*, p.barcode AS id FROM products_fts f JOIN products p ON p.rowid = f.rowid '
          'WHERE products_fts MATCH ? ORDER BY bm25(products_fts) LIMIT 8',
          [_ftsQuery(text)?.replaceAll(' OR ', ' ') ?? '""']))
        of('product', r, null, _nutrientsOf(r)),
    ];
  }

  /// Logs [grams] of [food] right away: pressing "Log" on that screen is the
  /// user's confirmation.
  void logFood(FoodChoice food, double grams, String mealType) => _insertMeal(_ms(), mealType, food.label, grams,
      food.per100.map((k, v) => MapEntry(k, v * grams / 100)), food.estimated, food.kind == 'recipe' ? food.id as int : null);

  /// "Just 350 kcal": no food, no grams; the button is the confirmation.
  void quickAdd(String label, Nutrients values, String mealType) => _insertMeal(
      _ms(), mealType, label, null, {for (final n in nutrients) n: values[n] ?? 0}, true);

  double _recipeServingGrams(int recipeId) => (nutri.select(
          'SELECT TOTAL(grams) / r.servings AS g FROM recipe_ingredients ri JOIN recipes r ON r.id = ri.recipe_id '
          'WHERE ri.recipe_id = ?', [recipeId]).single['g'] as num).toDouble();

  /// Breakfast before 11, lunch before 16, dinner before 21, then snack.
  String mealTypeNow() => _mealTypeFor(_now());
}

typedef FoodChoice = ({String kind, Object? id, String label, double? servingG, Nutrients per100, bool estimated});

/// Splits "2 eggs, toast and a coffee" into items.
/// Everyday words with no plain row in nutri.db, where search picks something odd ("bread" →
/// pan dulce, "cream" → whipped topping, "buckwheat" → raw groats): the row people mean, and a
/// realistic serving (null = the row's own). test/real_nutri_db_test.dart checks every row exists.
const staples = <String, (String, double?)>{
  'bread': ('White Bread', 30),
  'cream': ('Cream, fluid, light (coffee cream or table cream)', null),
  'oil': ('Oil, vegetable, blend', 14),
  'fish': ('Fish, cod, Atlantic, cooked, dry heat', null),
  'salad': ('Tossed salad', 150),
  'sausage': ('Sausage, pork, grilled, with no added fat, composite', 75),
  'sausages': ('Sausage, pork, grilled, with no added fat, composite', 75),
  'jam': ('Jams and preserves', null),
  'nuts': ('Mixed nuts', 30),
  'burger': ('Hamburger', 150),
  'hamburger': ('Hamburger', 150),
  'fries': ('French fries', 120),
  'french fries': ('French fries', 120),
  'cookie': ('Cookies, chocolate chip, commercially prepared, soft-type', 15),
  'cookies': ('Cookies, chocolate chip, commercially prepared, soft-type', 15),
  'cake': ('Cake, sponge, prepared from recipe', 80),
  'honey': ('Honey', 21), // the row's own serving is a 339 g jar
  'egg': ('Egg', 50), // no serving of its own: 100 g would be two eggs
  'eggs': ('Egg', 50),
  // Eaten cooked: the plain rows are dry groats.
  'buckwheat': ('Buckwheat groats, roasted, cooked', null),
  'rice': ('Rice, white, medium-grain, enriched, cooked', null),
  'white rice': ('Rice, white, medium-grain, enriched, cooked', null),
  'cooked rice': ('Rice, white, medium-grain, enriched, cooked', null),
  'boiled rice': ('Rice, white, medium-grain, enriched, cooked', null),
};

/// nutri.db foods.source -> how much its numbers are trusted: 2 government tables, 1 USDA-derived
/// generic (foodstruct), 0 smaller or branded datasets.
int authority(String source) => switch (source) {
      'usda_sr28' || 'usda_sr' || 'usda_fdc_foundation' || 'usda_fndds' || 'nz_foodfiles' => 2,
      'foodstruct' => 1,
      _ => 0,
    };

List<String> _split(String s) => [
      for (final p in s.split(RegExp(r',|\band\b|\+|;|\bwith\b', caseSensitive: false)))
        if (p.trim().isNotEmpty) p.trim()
    ];

/// The user says they have an allergy or intolerance (English, Ukrainian, German, French).
final _allergyWords = RegExp(
    r"allerg|intoleran|intoléran|celiac|coeliac|cœliaque|zöliakie|unverträglich|anaphyla|sensitive to|"
    r"(?:can'?t|cannot|can not) (?:eat|have|tolerate)|алерг|непереносим|целіак",
    caseSensitive: false);

/// Diets kept with the allergies (user_allergens) -> the nutri.db allergens they also
/// exclude. Meat (and, for vegans, honey and gelatin) is matched by food name: [_meat].
const _dietAllergens = {
  'vegetarian': ['fish', 'shellfish'],
  'vegan': ['fish', 'shellfish', 'egg', 'milk'],
  'pescatarian': <String>[],
};

/// Words for a diet, including the free-from ones that map to allergens ("gluten-free").
final _dietWords = RegExp(
    r'vegetari|vegan|végan|végétarien|pesc[ae]tari|plant[- ]based|(?:gluten|lactose|dairy|milk)[- ]free|'
    r'glutenfrei|laktosefrei|sans (?:gluten|lactose)|вегетаріан|веган|пескетаріан|без глютену|без лактози',
    caseSensitive: false);

/// "I'm vegetarian", "ich bin Veganerin", "je suis végétarienne", "я вегетаріанка".
final _dietStatement = RegExp(
    "(?:\\b(?:i'?m|i am|we'?re|we are|i've (?:been|gone|become|turned)|i (?:went|became|turned|follow|eat only|only eat)|"
    "ich bin|wir sind|ich esse|ich lebe|je suis|nous sommes|je mange)\\b|(?:^|\\s)(?:я|ми)(?=\\s)).*(?:${_dietWords.pattern})",
    caseSensitive: false);

/// A wish for now, not a lasting diet: "vegan tonight", "vegetarian dinner ideas".
final _oneOff = RegExp(
    r"\b(?:today|tonight|this (?:time|evening|morning|week|weekend)|for (?:now|once|a change)|breakfast|lunch|"
    r"dinner|supper|snack|recipes?|ideas?|want|wanna|like to|would like|heute|diesmal|frühstück|mittag|abend|"
    r"rezept|idee|möchte|aujourd|ce soir|cette fois|petit[- ]déj|déjeuner|dîner|recette|idée|veux|voudrais|"
    // Not strict either: "vegetarian on weekdays", "mostly vegan".
    r"weekdays?|weekends?|sometimes|mostly|flexitarian|wochentag\w*|wochenende|manchmal|meistens|semaine|parfois|surtout)|"
    r"будн|вихідн|іноді|переважно|"
    r"сьогодні|ввечері|цього разу|сніданок|обід|вечер|рецепт|ідеї|ідею|хочу|хотів|хотіла",
    caseSensitive: false);

/// Said as lasting: an allergy, or a diet that isn't just for this meal.
bool _lasting(String said) => _allergyWords.hasMatch(said) || (_dietStatement.hasMatch(said) && !_oneOff.hasMatch(said));

/// Meat in a food's name; [_meatFree] names are exempt ("Bacon bits, meatless").
final _meat = RegExp(
    r'\b(?:beef|veal|pork|ham|bacon|pancetta|lamb|mutton|goat|venison|bison|elk|rabbit|chicken|turkey|duck|goose|'
    r'quail|pheasant|meats?|meatballs?|sausages?|salami|pepperoni|prosciutto|chorizo|bratwurst|frankfurters?|'
    r'hot ?dogs?|bologna|pastrami|liverwurst|liver|giblets|tripe|jerky|steaks?|burgers?|hamburgers?|ribs|lard|gelatin)\b',
    caseSensitive: false);
final _notVegan = RegExp(r'\b(?:honey|gelatin|lard)\b', caseSensitive: false);
final _meatFree = RegExp(r'\b(?:meatless|vegetarian|vegan|imitation|meat substitute|plant[- ]based|veggie)\b',
    caseSensitive: false);

/// "How many calories do I have left?", "what did I eat today", "Wie viele Kalorien habe
/// ich noch übrig?", "combien de calories me reste-t-il", "скільки калорій залишилось".
final _statusAsk = RegExp(
    r"\b(?:calories|kcal|protein|carbs|sugar)\b.*\b(?:left|remaining)\b|"
    r"\bwhat (?:have i|did i) (?:eaten|eat|had)\b|\bhow (?:much|many)\b.*\b(?:have i|did i) (?:eaten|eat|had)\b|"
    r"\b(?:kalorien|eiweiß|protein)\b.*(?:übrig|verbleibend)|was habe ich .*gegessen|"
    r"\b(?:calories|protéines)\b.*\brest|qu'?est-ce que j'?ai mangé|"
    r"(?:калорі|білк).*(?:лишил|залишил)|що я .*(?:з['’]?їв|з['’]?їла)",
    caseSensitive: false);
final _weekWords = RegExp(r'week|7 days|woche|semaine|тиждень|тижня|тижні', caseSensitive: false);

/// "show me recipe 2", "save the second one", "zeig mir Rezept 2", "montre-moi la recette 2",
/// "збережи рецепт 1". Group 1: the verb, group 2: the number.
final _recipeRef = RegExp(
    r"^\s*(?:please\s+)?(show|open|see|view|save|bookmark|zeig\w*|öffne|speicher\w*|montre\w*|ouvre|affiche|"
    r"enregistre|sauvegarde|покажи|відкрий|збережи)(?:\s*-?\s*(?:me|mir|moi|мені))?\s+"
    r"(?:(?:the|recipe|number|no\.?|das|rezept|nummer|la|recette|numéro|рецепт|номер)\s+)*"
    r"(#?\d+|first|second|third)(?:\s+(?:one|recipe))?\s*[.!]?\s*$",
    caseSensitive: false);
/// Asks for recipe ideas (English; other languages go through the model).
final _ideasAsk = RegExp(
    r"\b(?:recipes?|ideas?|suggest\w*|inspir\w*|what (?:should|can|could|to) (?:i |we )?(?:cook|make|eat|have))\b",
    caseSensitive: false);

/// ...but about one recipe, a log or a rating, which the model handles.
final _notIdeas = RegExp(
    r"\b(?:show|open|see|view|save|bookmark|rate|rated|stars?|log|logged|ate|eaten|had|steps|details?|"
    r"how (?:do|to|long|many|much)|calories in|that|this|it|number|\d+)\b",
    caseSensitive: false);

final _saveWords = RegExp(r'save|bookmark|speicher|enregistre|sauvegarde|збережи', caseSensitive: false);

/// A reference only by position: "2", "recipe 2", "number 3", "the second one".
final _bareRecipeRef = RegExp(
    r'^\s*(?:(?:the|recipe|number|no\.?|#)\s*)*(?:\d+|first|second|third|one|two|three)(?:\s+(?:one|recipe))?\s*$');

/// The user reports something eaten or asks to log a meal.
final _ateWords = RegExp(r'\b(?:ate|eaten|had|drank|drunk|log|logged|add|record|track)\b', caseSensitive: false);

/// The user asks for ideas, not to log.
final _recipeWords = RegExp(
    r'\b(?:recipes?|suggest\w*|ideas?|cook\w*|make|bake|inspir\w*|menu|plan|different|another|else|new|what (?:should|can|could|to) (?:i |we )?(?:eat|have))\b',
    caseSensitive: false);

/// "2 glasses of water" → 500, "500 ml water" → 500, "a bottle of water" → 500; null = not just water.
double? waterMl(String text) {
  final m = RegExp(
    r'^(?:(\d+(?:[.,]\d+)?)|(an?|one|two|three|four|five))?\s*'
    r'(ml|l|liters?|litres?|glass(?:es)?|cups?|bottles?|mugs?)?\s*(?:of\s+)?(?:still\s+|sparkling\s+|mineral\s+|plain\s+)?water$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (m == null) return null;
  const words = {'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5};
  final qty = double.tryParse((m[1] ?? '').replaceAll(',', '.')) ?? (words[m[2]?.toLowerCase()] ?? 1).toDouble();
  final unit = m[3]?.toLowerCase() ?? '';
  final ml = switch (unit) {
    'ml' => qty,
    'l' || 'liter' || 'liters' || 'litre' || 'litres' => qty * 1000,
    _ when unit.startsWith('bottle') => qty * 500,
    '' when qty >= 50 => qty, // "500 water": millilitres
    _ => qty * 250, // glasses, cups, mugs
  };
  return ml > 0 && ml <= 5000 ? ml : null;
}

/// Starts like a report of a meal: "I ate…", "I had…", "Log 2 eggs", "add breakfast: …".
final _ateStatement = RegExp(
    r"^\s*(?:(?:i|i've|i have|we|just|also|and|so)\s+)*(?:ate|eaten|had|drank|drunk|log|add|record|track)\b",
    caseSensitive: false);

/// "I'm allergic to peanuts", "I have a gluten intolerance" (not "is my kid allergic…?"),
/// "Ich bin allergisch gegen Nüsse", "J'ai une allergie aux arachides", "У мене алергія на арахіс".
final _allergyStatement = RegExp(
    r"^\s*(?:i'?m|i am|i have|i've got|i got|ich bin|ich habe|ich hab|je suis|j'ai|у мене|в мене|я)(?=[\s,]).*"
    r"(?:allerg|intoleran|intoléran|unverträglich|celiac|coeliac|cœliaque|zöliakie|алерг|непереносим|целіак)",
    caseSensitive: false);

/// nutri.db allergen names ([_allergenAliases] targets).
/// "More", "other ideas", "ще", "andere", "d'autres": another round of the last recipe search.
final _moreAsk = RegExp(r"\b(?:more|others?|another|different|else|instead|again|mehr|andere\w*|weitere\w*|autres?|encore)\b|ще|інш",
    caseSensitive: false);

final _allergenNames = {for (final (_, name) in _allergenAliases) name};

/// "Peanuts", "арахіс", "vegan" → the allergen or diet the app filters by; null when it knows none.
String? knownAllergen(String raw) => switch (normalizeAllergen(raw)) { final a when _allergenNames.contains(a) => a, _ => null };

/// "I ate 2 bananas for breakfast today" → "2 bananas"; "add breakfast" → "".
String mealFoods(String text) => text
    .replaceFirst(
        RegExp(r"^\s*(?:(?:please|can you|could you|i|i've|i have|we|just|also|and|so)\s+)*"
            r'(?:ate|eaten|had|drank|drunk|log|add|record|track|eat)\b[\s:,-]*', caseSensitive: false),
        '')
    .replaceAll(
        RegExp(r'\b(?:(?:for|to|as|at|in|with)\s+)?(?:my\s+)?(?:breakfast|lunch|dinner|supper|snack)\b\s*:?|'
            r'\b(?:today|yesterday|this morning|this evening|tonight|just now|earlier|please)\b',
            caseSensitive: false),
        ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'^[\s,.:;-]*(?:and\s+)?|[\s,.!:;-]*$'), '');

Nutrients _nutrientsOf(Row r) => {
      for (final n in nutrients) n: ((r[n] as num?) ?? 0).toDouble(),
      for (final m in micronutrients)
        if (r[m] case final num v) m: v.toDouble(),
    };

num _round(double v) => v >= 10 ? v.round() : double.parse(v.toStringAsFixed(1));

const _stopwords = {
  'a', 'an', 'the', 'and', 'or', 'of', 'for', 'with', 'in', 'on', 'to', 'is', 'are', 'i', 'me', 'my',
  'can', 'what', 'how', 'much', 'many', 'some', 'something', 'please', 'make', 'cook', 'recipe',
  'recipes', 'idea', 'ideas', 'give', 'find', 'suggest', 'want', 'have', 'eat', 'food', 'foods',
  'new', 'different', 'another', 'other', 'else', 'more', 'anything', 'dish', 'meal', 'meals',
  'today', 'tonight', 'now', 'good', 'nice', 'tasty', 'healthy', 'should', 'could', 'like', 'not', 'same',
};

/// Content words, crudely singular ("eggs" → "egg"), for comparing names.
Set<String> _words(String text) => {
      for (final m in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase()))
        if (m[0]!.length > 1 && !_stopwords.contains(m[0]))
          _singular(m[0]!)
    };

String _singular(String w) => w.endsWith('ies') && w.length > 4
    ? '${w.substring(0, w.length - 3)}y'
    : w.endsWith('oes') && w.length > 4
        ? w.substring(0, w.length - 2)
        : w.length > 3 && w.endsWith('s') && !w.endsWith('ss')
            ? w.substring(0, w.length - 1)
            : w;

/// Query words that describe the meal, not what goes in it ("quick high protein dinner"),
/// though some are in food names ("Rolls, dinner", "Salt, table").
const _notIngredients = {
  'breakfast', 'brunch', 'lunch', 'dinner', 'supper', 'snack', 'dessert', 'appetizer', 'starter', 'side', 'main',
  'course', 'quick', 'easy', 'simple', 'fast', 'light', 'great', 'best', 'delicious', 'high', 'low', 'rich',
  'free', 'protein', 'carb', 'fat', 'fiber', 'fibre', 'sugar', 'calorie', 'kcal', 'sodium', 'salt', 'gluten',
  'lactose', 'dairy', 'vegetarian', 'vegan', 'keto', 'paleo', 'spicy', 'sweet', 'savory', 'savoury', 'hot',
  'cold', 'warm', 'cozy', 'soft', 'green', 'red', 'white', 'black', 'fresh', 'frozen', 'raw', 'cooked', 'baked',
  'fried', 'grilled', 'roasted', 'minute', 'hour', 'person', 'people', 'kid', 'family', 'week', 'weekend',
  'night', 'evening', 'morning', 'maybe', 'you', 'friendly', 'style', 'prep', 'meal', 'plain', 'whole',
};

/// FTS5 query: words OR-ed with prefix match, so "eggs" finds "egg" and
/// "chickpea" finds "chickpeas". Null when nothing searchable is left.
String? _ftsQuery(String text) {
  final words = RegExp(r'[a-z0-9]+')
      .allMatches(text.toLowerCase())
      .map((m) => m[0]!)
      .where((w) => w.length > 1 && !_stopwords.contains(w))
      // crude singular: "eggs" -> "egg*" also matches "eggs"
      .map((w) => w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w)
      .toSet();
  return words.isEmpty ? null : words.map((w) => '"$w"*').join(' OR ');
}

/// Row ids from an FTS5 table, best match first.
List<int> _ftsIds(Database db, String table, String text, {required int limit, String? where}) {
  final query = _ftsQuery(text);
  if (query == null) return [];
  return [
    for (final r in db.select(
        'SELECT rowid FROM $table WHERE $table MATCH ?${where == null ? '' : ' AND $where'} '
        'ORDER BY bm25($table) LIMIT ?', [query, limit]))
      r['rowid'] as int
  ];
}

/// Maps what people say (English, Ukrainian, German, French) to nutri.db allergen names
/// and diets. Order matters: "peanuts" must hit 'peanut' before 'nuts'.
const _allergenAliases = [
  ('vegetari', 'vegetarian'), ('végétarien', 'vegetarian'), ('вегетаріан', 'vegetarian'),
  ('pescatari', 'pescatarian'), ('pescetari', 'pescatarian'), ('пескетаріан', 'pescatarian'),
  ('vegan', 'vegan'), ('végan', 'vegan'), ('веган', 'vegan'), ('plant-based', 'vegan'), ('plant based', 'vegan'),
  ('erdnuss', 'peanuts'), ('arachide', 'peanuts'), ('cacahu', 'peanuts'), ('арахіс', 'peanuts'),
  ('nuss', 'tree nuts'), ('nüsse', 'tree nuts'), ('noix', 'tree nuts'), ('fruits à coque', 'tree nuts'),
  ('горіх', 'tree nuts'), ('laktose', 'milk'), ('milch', 'milk'), ('lait', 'milk'), ('лактоз', 'milk'),
  ('молок', 'milk'), ('молоч', 'milk'), ('eier', 'egg'), ('œuf', 'egg'), ('oeuf', 'egg'), ('яйц', 'egg'),
  ('яєц', 'egg'), ('weizen', 'gluten'), ('zöliakie', 'gluten'), ('blé', 'gluten'), ('cœliaque', 'gluten'),
  ('coeliaque', 'gluten'), ('глютен', 'gluten'), ('пшениц', 'gluten'), ('целіак', 'gluten'),
  ('garnele', 'shellfish'), ('krebstier', 'shellfish'), ('schalentier', 'shellfish'),
  ('meeresfrüchte', 'shellfish'), ('crustac', 'shellfish'), ('fruits de mer', 'shellfish'),
  ('crevette', 'shellfish'), ('креветк', 'shellfish'), ('молюск', 'shellfish'), ('ракоподіб', 'shellfish'),
  ('морепродукт', 'shellfish'), ('fisch', 'fish'), ('poisson', 'fish'), (' риб', 'fish'), /* not гриби, mushrooms */ ('soja', 'soy'),
  ('соя', 'soy'), ('сої', 'soy'), ('сою', 'soy'), ('sesam', 'sesame'), ('sésame', 'sesame'),
  ('кунжут', 'sesame'),
  ('peanut', 'peanuts'), ('tree nut', 'tree nuts'), ('almond', 'tree nuts'), ('walnut', 'tree nuts'),
  ('cashew', 'tree nuts'), ('nut', 'tree nuts'), ('lactose', 'milk'), ('dairy', 'milk'),
  ('milk', 'milk'), ('egg', 'egg'), ('gluten', 'gluten'), ('wheat', 'gluten'), ('celiac', 'gluten'),
  ('coeliac', 'gluten'), ('shellfish', 'shellfish'), ('shrimp', 'shellfish'), ('prawn', 'shellfish'),
  ('fish', 'fish'), ('soy', 'soy'), ('sesame', 'sesame'),
];

String normalizeAllergen(String raw) {
  final s = raw.toLowerCase().replaceAll(RegExp(r'\b(allerg\w*|intoleran\w*)\b'), '').trim();
  // "gluten-free" is the gluten allergen, "lactose-free" milk: the aliases below find them.
  for (final (alias, name) in _allergenAliases) {
    if (' $s'.contains(alias)) return name;
  }
  return s;
}
