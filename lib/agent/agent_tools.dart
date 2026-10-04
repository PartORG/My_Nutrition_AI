import 'package:sqlite3/sqlite3.dart';

import '../data/goals.dart';

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
      required this.servings, required this.ingredients, required this.perServing});
  final int id;
  final String title, instructions;
  final int? minutes;
  final int servings;
  final List<({String name, double grams})> ingredients;
  final Nutrients perServing;
}

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

/// A write the model proposed. Nothing is stored until the user taps ✓.
class ConfirmCard extends AgentCard {
  ConfirmCard({required this.title, required this.lines, required this.apply});
  final String title;
  final List<String> lines;
  final void Function() apply;
  bool? accepted; // null = not decided yet
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

  ToolResult run(String name, Map<String, dynamic> args) {
    String arg(String k) => '${args[k] ?? ''}'.trim();
    return switch (name) {
      'search_recipes' => _searchRecipes(arg('query'), arg('ingredients')),
      'show_recipe' => _showRecipe(arg('recipe')),
      'save_recipe' => _saveRecipe(arg('recipe')),
      'lookup_nutrition' => _lookupNutrition(arg('food')),
      'nutrition_status' => _nutritionStatus(arg('period')),
      'log_meal' => _logMeal(arg('items'), arg('meal_type')),
      'remember_fact' => _remember(arg('fact')),
      'set_allergen' => _setAllergen(arg('allergen'), args['remove'] == true || args['remove'] == 'true'),
      'log_symptom' => _logSymptom(arg('symptom'), int.tryParse(arg('severity'))),
      'log_reading' => _logReading(arg('kind'), arg('value')),
      'condition_info' => _conditionInfo(arg('question')),
      'open_camera' => ToolResult({'status': 'the camera is not available yet'}, CameraCard(arg('mode'))),
      _ => ToolResult.error('unknown tool $name'),
    };
  }

  // ---- recipes ------------------------------------------------------------

  ToolResult _searchRecipes(String query, String ingredients) {
    final scores = <int, double>{};
    // Each ingredient the user has counts double: using what's in the fridge matters most.
    for (final item in _split(ingredients)) {
      final foodIds = _ftsIds(nutri, 'foods_fts', item, limit: 3);
      if (foodIds.isEmpty) continue;
      for (final r in nutri.select(
          'SELECT DISTINCT recipe_id FROM recipe_ingredients WHERE food_id IN (${foodIds.join(',')})')) {
        scores.update(r['recipe_id'] as int, (s) => s + 2, ifAbsent: () => 2);
      }
    }
    for (final id in _ftsIds(nutri, 'recipes_fts', '$query $ingredients', limit: 20)) {
      scores.update(id, (s) => s + 1, ifAbsent: () => 1);
    }
    final blocked = _blockedRecipes();
    final ranked = scores.keys.where((id) => !blocked.contains(id)).toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    _lastRecipes = ranked.take(3).toList();
    if (_lastRecipes.isEmpty) {
      return ToolResult({'recipes': [], 'note': 'no matching recipe in the database'});
    }
    final list = [for (final id in _lastRecipes) _summary(id)];
    return ToolResult({
      'recipes': [
        for (final (i, r) in list.indexed)
          '${i + 1}. ${r.title} (${r.kcal.round()} kcal per serving${r.minutes == null ? '' : ', ${r.minutes} min'})'
      ],
      if (blocked.isNotEmpty) 'note': 'recipes with the user\'s allergens were excluded',
    }, RecipeListCard(list));
  }

  /// Recipes containing any allergen the profile has.
  Set<int> _blockedRecipes() {
    final mine = [for (final r in user.select('SELECT allergen FROM user_allergens')) r['allergen']];
    if (mine.isEmpty) return {};
    return {
      for (final r in nutri.select(
          'SELECT DISTINCT ri.recipe_id FROM recipe_ingredients ri '
          'JOIN allergens a ON a.food_id = ri.food_id '
          'WHERE a.allergen IN (${List.filled(mine.length, '?').join(',')})',
          mine))
        r['recipe_id'] as int
    };
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
    if (RegExp(r'\b(that|this|it)\b').hasMatch(lower) && _lastShown != null) return _lastShown;
    const ordinals = {'first': 1, 'second': 2, 'third': 3, 'one': 1, 'two': 2, 'three': 3};
    final n = int.tryParse(RegExp(r'\d+').firstMatch(lower)?[0] ?? '') ??
        ordinals.entries.where((e) => RegExp('\\b${e.key}\\b').hasMatch(lower)).firstOrNull?.value;
    if (n != null && n >= 1 && n <= _lastRecipes.length) return _lastRecipes[n - 1];
    return _ftsIds(nutri, 'recipes_fts', ref, limit: 1).firstOrNull;
  }

  ToolResult _showRecipe(String ref) {
    final id = _resolveRecipe(ref);
    if (id == null) return ToolResult.error('no recipe matches "$ref"');
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
    );
    return ToolResult({
      'title': card.title,
      'minutes': card.minutes,
      'servings': card.servings,
      'kcal_per_serving': perServing['kcal']!.round(),
      'ingredients': [for (final i in ingredients) '${i.grams.round()} g ${i.name}'],
      'note': 'the full recipe is shown in a card with an "I ate this" button that logs one serving',
    }, card);
  }

  /// "I ate this" on a recipe card: one serving, through the same ✓ card.
  ToolResult logRecipe(int recipeId, {double servings = 1}) {
    final title = _summary(recipeId).title;
    final grams = servings * _recipeServingGrams(recipeId);
    final values = _recipePer100(recipeId).map((k, v) => MapEntry(k, v * grams / 100));
    final type = _mealTypeFor(_now());
    final at = _ms();
    return ToolResult({'status': _pendingNote, 'recipe': title}, ConfirmCard(
      title: 'Log $type',
      lines: ['$title · ${grams.round()} g · ${values['kcal']!.round()} kcal'],
      apply: () => _insertMeal(at, type, title, grams, values, false),
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
      apply: () => user.execute(
          'INSERT OR REPLACE INTO saved_recipes (recipe_id, title, saved_at) VALUES (?, ?, ?)',
          [id, title, _ms()]),
    ));
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
    final daily = currentTargets(user, now: now).values;
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
    final parsed = [for (final item in _split(items)) _portion(item)];
    final found = [for (final p in parsed) ?p];
    final missing = [for (final (i, p) in parsed.indexed) if (p == null) _split(items)[i]];
    if (found.isEmpty) {
      return ToolResult.error('could not find "${missing.join('", "')}" in the food database; '
          'ask the user to name the food differently or give grams');
    }
    const types = {'breakfast', 'lunch', 'dinner', 'snack'};
    final type = types.contains(mealType) ? mealType : _mealTypeFor(_now());
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
      title: 'Log $type',
      lines: [
        for (final p in found) '${p.label} · ${p.grams.round()} g · ${p.estimated ? '≈' : ''}${p.values['kcal']!.round()} kcal',
        if (missing.isNotEmpty) 'Not found: ${missing.join(', ')}',
      ],
      apply: () {
        for (final p in found) {
          _insertMeal(at, type, p.label, p.grams, p.values, p.estimated);
        }
      },
    ));
  }

  /// "2 eggs", "200 g greek yogurt", "3 slices of pizza", "lasagna".
  ({String label, double grams, Nutrients values, bool estimated})? _portion(String item) {
    final m = RegExp(
      // \b after the quantity word and unit: "almonds" is not "a lmonds", "greek" not "g reek".
      r'^(?:(\d+(?:[.,]\d+)?)|(an?|one|two|three|four|five|half(?: a)?)\b)?\s*'
      r'(?:(kg|g|grams?|ml|slices?|pieces?|portions?|servings?|bowls?|cups?|plates?|handfuls?)\b)?\s*'
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
          'g' || 'gram' || 'grams' || 'ml' => qty,
          _ => qty * (serving ?? 100),
        };
    Nutrients scale(Nutrients per100, double g) => per100.map((k, v) => MapEntry(k, v * g / 100));

    // Prepared dishes first ("caesar salad" is a dish, not lettuce), then recipes, then foods.
    final dish = _ftsIds(nutri, 'dishes_fts', name, limit: 1).firstOrNull;
    if (dish != null) {
      final d = nutri.select('SELECT * FROM dishes WHERE id = ?', [dish]).single;
      final g = grams((d['serving_g'] as num).toDouble());
      final recipeId = d['recipe_id'] as int?;
      final per100 = recipeId == null ? _nutrientsOf(d) : _recipePer100(recipeId);
      return (label: d['name'] as String, grams: g, values: scale(per100, g), estimated: true);
    }
    final recipe = _ftsIds(nutri, 'recipes_fts', name, limit: 1).firstOrNull;
    if (recipe != null && unit.isEmpty) {
      final g = qty * _recipeServingGrams(recipe);
      return (label: _summary(recipe).title, grams: g, values: scale(_recipePer100(recipe), g), estimated: false);
    }
    final food = _ftsIds(nutri, 'foods_fts', name, limit: 1).firstOrNull;
    if (food == null) return null;
    final f = nutri.select('SELECT * FROM foods WHERE id = ?', [food]).single;
    final g = grams((f['serving_g'] as num?)?.toDouble());
    return (label: f['name'] as String, grams: g, values: scale(_nutrientsOf(f), g), estimated: false);
  }

  Nutrients _recipePer100(int recipeId) {
    final r = nutri.select(
        'SELECT ${[for (final n in nutrients) 'TOTAL(f.$n * ri.grams) / TOTAL(ri.grams) AS $n'].join(', ')} '
        'FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id WHERE ri.recipe_id = ?',
        [recipeId]).single;
    return _nutrientsOf(r);
  }

  static String _mealTypeFor(DateTime t) =>
      t.hour < 11 ? 'breakfast' : t.hour < 16 ? 'lunch' : t.hour < 21 ? 'dinner' : 'snack';

  // ---- memory, allergies, journal --------------------------------------------

  ToolResult _remember(String fact) {
    if (fact.isEmpty) return ToolResult.error('empty fact');
    return ToolResult({'status': _pendingNote, 'fact': fact}, ConfirmCard(
      title: 'Remember',
      lines: [fact],
      apply: () => user.execute('INSERT INTO memory_facts (text, created_at) VALUES (?, ?)', [fact, _ms()]),
    ));
  }

  ToolResult _setAllergen(String raw, bool remove) {
    final allergen = normalizeAllergen(raw);
    if (allergen.isEmpty) return ToolResult.error('which allergen?');
    return ToolResult({'status': _pendingNote, 'allergen': allergen, 'remove': remove}, ConfirmCard(
      title: remove ? 'Remove allergy' : 'Add allergy',
      lines: [allergen],
      apply: () => remove
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
      apply: () => user.execute('INSERT INTO symptoms (logged_at, symptom, severity) VALUES (?, ?, ?)',
          [_ms(), symptom.toLowerCase(), s]),
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
    String exact(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    final text = '${exact(reading.v)}${reading.v2 == null ? '' : '/${exact(reading.v2!)}'} ${reading.unit}';
    return ToolResult({'status': _pendingNote, 'kind': kind, 'value': text}, ConfirmCard(
      title: 'Log ${kind.replaceAll('_', ' ')}',
      lines: [text],
      apply: () => user.execute(
          'INSERT INTO readings (logged_at, kind, value, value2, unit) VALUES (?, ?, ?, ?, ?)',
          [_ms(), kind, reading.v, reading.v2, reading.unit]),
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

  /// The one place a meal_log row is written (chat card, "I ate this", Log tab).
  void _insertMeal(int at, String type, String label, double grams, Nutrients values, bool estimated) =>
      user.execute(
        'INSERT INTO meal_log (eaten_at, meal_type, description, grams, '
        '${nutrients.join(', ')}, estimated) VALUES (?, ?, ?, ?, ${List.filled(nutrients.length, '?').join(', ')}, ?)',
        [at, type, label, grams, for (final n in nutrients) values[n], estimated ? 1 : 0],
      );

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
  void logFood(FoodChoice food, double grams, String mealType) => _insertMeal(
      _ms(), mealType, food.label, grams, food.per100.map((k, v) => MapEntry(k, v * grams / 100)), food.estimated);

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

Nutrients _nutrientsOf(Row r) =>
    {for (final n in nutrients) n: ((r[n] as num?) ?? 0).toDouble()};

num _round(double v) => v >= 10 ? v.round() : double.parse(v.toStringAsFixed(1));

const _stopwords = {
  'a', 'an', 'the', 'and', 'or', 'of', 'for', 'with', 'in', 'on', 'to', 'is', 'are', 'i', 'me', 'my',
  'can', 'what', 'how', 'much', 'many', 'some', 'something', 'please', 'make', 'cook', 'recipe',
  'recipes', 'idea', 'ideas', 'give', 'find', 'suggest', 'want', 'have', 'eat', 'food', 'foods',
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
List<int> _ftsIds(Database db, String table, String text, {required int limit}) {
  final query = _ftsQuery(text);
  if (query == null) return [];
  return [
    for (final r in db.select(
        'SELECT rowid FROM $table WHERE $table MATCH ? ORDER BY bm25($table) LIMIT ?', [query, limit]))
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
