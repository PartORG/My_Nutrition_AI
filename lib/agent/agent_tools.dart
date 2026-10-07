import 'package:sqlite3/sqlite3.dart';

import '../data/conditions.dart';
import '../data/diary.dart' show logWater;
import '../data/goals.dart';
import '../data/journal.dart';

/// Nutrient columns shared by foods, dishes, products, meal_log and the
/// recipe_nutrition view.
const nutrients = ['kcal', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g', 'sugar_g', 'sodium_mg'];
typedef Nutrients = Map<String, double>;

typedef RecipeSummary = ({int id, String title, int? minutes, double kcal});
typedef Passage = ({String source, String text});

/// What the chat shows under a model message. Numbers come from here, never
/// from the model's text.
sealed class AgentCard {}

class RecipeListCard extends AgentCard {
  RecipeListCard(this.recipes);
  final List<RecipeSummary> recipes;
}

class RecipeCard extends AgentCard {
  RecipeCard({required this.id, required this.title, required this.instructions, required this.minutes,
      required this.servings, required this.ingredients, required this.perServing, this.cautions = const []});
  final int id;
  final String title, instructions;
  final int? minutes;
  final int servings;
  final List<({String name, double grams})> ingredients;
  final Nutrients perServing;

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
  AgentTools(this.nutri, this.user, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final Database nutri, user;
  final DateTime Function() _now;

  /// Recipe ids of the last list shown, so "recipe 2" / "the first one" resolve.
  List<int> _lastRecipes = [];
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
      'set_allergen' when !remove && said.isNotEmpty && !_allergyWords.hasMatch(said) => _ateWords.hasMatch(said)
          ? _logMeal(said, '')
          : ToolResult.error('the user did not say they are allergic or intolerant, so no allergy was added. '
              'Never add an allergy unless they say so'),
      'search_recipes' when _ateWords.hasMatch(said) && !_recipeWords.hasMatch(said) => _logMeal(said, ''),
      'search_recipes' => _searchRecipes(arg('query'), arg('ingredients')),
      'show_recipe' => _showRecipe(arg('recipe')),
      'save_recipe' => _saveRecipe(arg('recipe')),
      'rate_recipe' => _rateRecipe(arg('recipe'), int.tryParse(arg('stars'))),
      'lookup_nutrition' => _lookupNutrition(arg('food')),
      'nutrition_status' => _nutritionStatus(arg('period')),
      'log_meal' => _logMeal(arg('items'), arg('meal_type')),
      'remember_fact' => _remember(arg('fact')),
      'set_allergen' => _setAllergen(arg('allergen'), remove),
      'log_symptom' => _logSymptom(arg('symptom'), int.tryParse(arg('severity'))),
      'log_reading' => _logReading(arg('kind'), arg('value')),
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
    if (said.contains('?') || _recipeWords.hasMatch(said)) return null;
    if (_allergyStatement.hasMatch(said)) {
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

  ToolResult _searchRecipes(String query, String ingredients) {
    final scores = <int, double>{};
    // Each ingredient the user has counts double: using what's in the fridge matters most.
    for (final item in _split(ingredients)) {
      // Only foods some recipe uses: among tens of thousands of foods the best text match
      // is often a branded product no recipe contains.
      final foodIds = _ftsIds(nutri, 'foods_fts', item, limit: 3,
          where: 'rowid IN (SELECT food_id FROM recipe_ingredients)');
      if (foodIds.isEmpty) continue;
      for (final r in nutri.select(
          'SELECT DISTINCT recipe_id FROM recipe_ingredients WHERE food_id IN (${foodIds.join(',')})')) {
        scores.update(r['recipe_id'] as int, (s) => s + 2, ifAbsent: () => 2);
      }
    }
    for (final id in _ftsIds(nutri, 'recipes_fts', '$query $ingredients', limit: 60)) {
      scores.update(id, (s) => s + 1, ifAbsent: () => 1);
    }
    // Stars steer ideas: 4-5 rank higher, 1-2 are never suggested again.
    final stars = _ratings();
    for (final MapEntry(key: id, value: s) in stars.entries) {
      if (scores.containsKey(id)) scores[id] = scores[id]! + (s - 3) * 0.75;
    }
    final unsafe = _blockedRecipes();
    final blocked = {...unsafe, for (final e in stars.entries) if (e.value <= 2) e.key};
    var ranked = scores.keys.where((id) => !blocked.contains(id)).toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    // A vague ask ("something new for dinner") matches nothing: random ideas for the meal.
    if (ranked.isEmpty && _split(ingredients).isEmpty) ranked = _randomRecipes(query, blocked);
    final titles = {
      for (final r in nutri.select('SELECT id, title FROM recipes WHERE id IN (${ranked.join(',')})'))
        r['id'] as int: (r['title'] as String).toLowerCase().trim()
    };
    final seen = {..._suggestedTitles};
    final fresh = [for (final id in ranked) if (!_suggested.contains(id) && seen.add(titles[id]!)) id];
    _lastRecipes = (fresh.isEmpty ? ranked : fresh).take(3).toList();
    _suggested.addAll(_lastRecipes);
    _suggestedTitles.addAll([for (final id in _lastRecipes) titles[id]!]);
    if (_lastRecipes.isEmpty) {
      return ToolResult({'recipes': [], 'note': 'no matching recipe in the database'});
    }
    final list = [for (final id in _lastRecipes) _summary(id)];
    return ToolResult({
      'recipes': [
        for (final (i, r) in list.indexed)
          '${i + 1}. ${r.title} (${r.kcal.round()} kcal per serving${r.minutes == null ? '' : ', ${r.minutes} min'})'
      ],
      if (unsafe.isNotEmpty) 'note': 'recipes with the user\'s allergens or foods to avoid for their conditions were excluded',
      if (fresh.isEmpty) 'repeated': 'no new recipe matches; these were suggested before, so say so and ask for other ingredients',
    }, RecipeListCard(list));
  }

  /// Up to 20 random recipes tagged with the meal named in [query], else the meal for now.
  List<int> _randomRecipes(String query, Set<int> blocked) {
    final meal = _mealTypes.firstWhere(query.toLowerCase().contains, orElse: () => _mealTypeFor(_now()));
    return [
      for (final r in nutri.select(
          "SELECT id FROM recipes WHERE ',' || tags || ',' LIKE ? ORDER BY RANDOM() LIMIT 40", ['%,$meal,%']))
        if (!blocked.contains(r['id'])) r['id'] as int
    ].take(20).toList();
  }

  /// Recipes containing any allergen the profile has, or any food its
  /// conditions say to avoid. Kept even after a downgrade from Medium.
  Set<int> _blockedRecipes() {
    final mine = [for (final r in user.select('SELECT allergen FROM user_allergens')) r['allergen']];
    final avoid = avoidedFoods(nutri, user).keys;
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

  /// Ingredients of [recipeId] on the profile's allergy or condition lists, one per food.
  List<Caution> _cautions(int recipeId) {
    final avoid = avoidedFoods(nutri, user);
    final mine = {for (final r in user.select('SELECT allergen FROM user_allergens')) r['allergen'] as String};
    final byFood = <int, Caution>{};
    for (final r in nutri.select(
        'SELECT f.id, f.name, a.allergen FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id '
        'LEFT JOIN allergens a ON a.food_id = f.id WHERE ri.recipe_id = ? ORDER BY f.name', [recipeId])) {
      final id = r['id'] as int;
      final allergen = mine.contains(r['allergen']) ? r['allergen'] as String : null;
      if (allergen == null && !avoid.containsKey(id)) continue;
      byFood[id] = (food: r['name'] as String, allergen: allergen ?? byFood[id]?.allergen, condition: avoid[id]);
    }
    return byFood.values.toList();
  }

  RecipeSummary _summary(int id) {
    final r = nutri.select(
        'SELECT r.title, r.minutes, n.kcal FROM recipes r JOIN recipe_nutrition n ON n.recipe_id = r.id '
        'WHERE r.id = ?', [id]).single;
    return (id: id, title: r['title'] as String, minutes: r['minutes'] as int?,
        kcal: (r['kcal'] as num).toDouble());
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
    if (n != null && n >= 1 && n <= _lastRecipes.length) return _lastRecipes[n - 1];
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
    final ingredients = [
      for (final i in nutri.select(
          'SELECT f.name, ri.grams FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id '
          'WHERE ri.recipe_id = ? ORDER BY ri.grams DESC', [id]))
        (name: i['name'] as String, grams: (i['grams'] as num).toDouble())
    ];
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
    // "overnight oats with banana" is one recipe; "chicken with rice" is two foods.
    final parts = _isDishName(items) ? [items] : _split(items);
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

    // The candidate whose name the user said most completely wins: "banana" is
    // the food, not "Overnight oats with banana"; "lentil soup" is the recipe,
    // "chicken caesar salad" the dish. Ties: dish, then recipe, then food.
    final candidates = [
      for (final id in _ftsIds(nutri, 'dishes_fts', name, limit: 3))
        ('dish', id, nutri.select('SELECT name FROM dishes WHERE id = ?', [id]).single['name'] as String),
      if (unit.isEmpty) // "200 g of shakshuka" is weighed food, not servings of a recipe
        for (final id in _ftsIds(nutri, 'recipes_fts', name, limit: 3))
          ('recipe', id, _summary(id).title),
      for (final id in _ftsIds(nutri, 'foods_fts', name, limit: 3))
        ('food', id, nutri.select('SELECT name FROM foods WHERE id = ?', [id]).single['name'] as String),
    ];
    // The plain food first: "banana" is "Banana", not "Banana chips, banana",
    // which search ranks higher for repeating the word.
    final n = name.trim();
    final forms = {n, if (n.length > 3 && n.endsWith('s')) n.substring(0, n.length - 1),
        if (n.length > 4 && n.endsWith('es')) n.substring(0, n.length - 2)};
    final names = [for (final f in forms) ...[f, '$f, raw']];
    final plain = nutri.select(
        'SELECT id FROM foods WHERE name COLLATE NOCASE IN (${List.filled(names.length, '?').join(',')}) '
        'ORDER BY length(name) LIMIT 1', names).firstOrNull;
    if (plain != null) candidates.insert(0, ('food', plain['id'] as int, name));
    if (candidates.isEmpty) return null;
    final said = _words(name);
    double coverage(String label) {
      final words = _words(label);
      return words.isEmpty ? 0 : words.where(said.contains).length / words.length;
    }
    final (kind, id, _) = candidates.reduce((best, c) => coverage(c.$3) > coverage(best.$3) ? c : best);

    switch (kind) {
      case 'dish':
        final d = nutri.select('SELECT * FROM dishes WHERE id = ?', [id]).single;
        final g = grams((d['serving_g'] as num).toDouble());
        final recipeId = d['recipe_id'] as int?;
        final per100 = recipeId == null ? _nutrientsOf(d) : _recipePer100(recipeId);
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
        'SELECT ${[for (final n in nutrients) 'TOTAL(f.$n * ri.grams) / TOTAL(ri.grams) AS $n'].join(', ')} '
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
      title: remove ? 'Remove allergy' : 'Add allergy',
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
        'INSERT INTO meal_log (eaten_at, meal_type, description, grams, ${nutrients.join(', ')}, estimated, '
        'recipe_id) VALUES (?, ?, ?, ?, ${List.filled(nutrients.length, '?').join(', ')}, ?, ?)',
        [at, type, label, grams, for (final n in nutrients) values[n], estimated ? 1 : 0, recipeId],
      );

  // ---- ratings ----------------------------------------------------------------

  /// 1-5 stars; null = not rated.
  int? rating(int recipeId) =>
      user.select('SELECT stars FROM recipe_ratings WHERE recipe_id = ?', [recipeId]).firstOrNull?['stars'] as int?;

  /// A tap on a star is the user's confirmation, as on the Log tab.
  void rate(int recipeId, int stars) => user.execute(
      'INSERT OR REPLACE INTO recipe_ratings (recipe_id, stars, rated_at) VALUES (?, ?, ?)',
      [recipeId, stars.clamp(1, 5), _ms()]);

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
              r['recipe_id'] == null ? _nutrientsOf(r) : _recipePer100(r['recipe_id'] as int), estimated: true),
      for (final id in _ftsIds(nutri, 'recipes_fts', text, limit: 5))
        for (final r in nutri.select('SELECT id, title AS name FROM recipes WHERE id = ?', [id]))
          of('recipe', r, _recipeServingGrams(id), _recipePer100(id)),
      for (final id in _ftsIds(nutri, 'foods_fts', text, limit: limit))
        for (final r in nutri.select('SELECT * FROM foods WHERE id = ?', [id]))
          of('food', r, (r['serving_g'] as num?)?.toDouble(), _nutrientsOf(r)),
      for (final r in nutri.select(
          'SELECT p.*, p.barcode AS id FROM products_fts f JOIN products p ON p.rowid = f.rowid '
          'WHERE products_fts MATCH ? LIMIT 5', [_ftsQuery(text) ?? '""']))
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
List<String> _split(String s) => [
      for (final p in s.split(RegExp(r',|\band\b|\+|;|\bwith\b', caseSensitive: false)))
        if (p.trim().isNotEmpty) p.trim()
    ];

/// The user says they have an allergy or intolerance.
final _allergyWords = RegExp(
    r"allerg|intoleran|celiac|coeliac|anaphyla|sensitive to|(?:can'?t|cannot|can not) (?:eat|have|tolerate)",
    caseSensitive: false);

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

/// "I'm allergic to peanuts", "I have a gluten intolerance" (not "is my kid allergic…?").
final _allergyStatement = RegExp(
    r"^\s*(?:i'?m|i am|i have|i've got|i got)\b.*\b(?:allergic|allergy|intolerant|intolerance|celiac|coeliac)\b",
    caseSensitive: false);

/// nutri.db allergen names ([_allergenAliases] targets).
final _allergenNames = {for (final (_, name) in _allergenAliases) name};

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

Nutrients _nutrientsOf(Row r) =>
    {for (final n in nutrients) n: ((r[n] as num?) ?? 0).toDouble()};

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
          m[0]!.length > 3 && m[0]!.endsWith('s') ? m[0]!.substring(0, m[0]!.length - 1) : m[0]!
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

/// Maps what people say to nutri.db allergen names. Order matters:
/// "peanuts" must hit 'peanut' before 'nuts'.
const _allergenAliases = [
  ('peanut', 'peanuts'), ('tree nut', 'tree nuts'), ('almond', 'tree nuts'), ('walnut', 'tree nuts'),
  ('cashew', 'tree nuts'), ('nut', 'tree nuts'), ('lactose', 'milk'), ('dairy', 'milk'),
  ('milk', 'milk'), ('egg', 'egg'), ('gluten', 'gluten'), ('wheat', 'gluten'), ('celiac', 'gluten'),
  ('coeliac', 'gluten'), ('shellfish', 'shellfish'), ('shrimp', 'shellfish'), ('prawn', 'shellfish'),
  ('fish', 'fish'), ('soy', 'soy'), ('sesame', 'sesame'),
];

String normalizeAllergen(String raw) {
  final s = raw.toLowerCase().replaceAll(RegExp(r'\b(allerg\w*|intoleran\w*)\b'), '').trim();
  for (final (alias, name) in _allergenAliases) {
    if (s.contains(alias)) return name;
  }
  return s;
}
