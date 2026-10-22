import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/plan.dart';
import 'package:myfoodmind/data/user_db.dart';

/// Gate for the real assets/nutri.db and assets/health.db (built by tool/catalog, not in git).
/// The other tests use the dummy fixture test/nutri_test.db.
void main() {
  final asset = File('assets/nutri.db');
  final skip = asset.existsSync() ? false : 'assets/nutri.db not built (tool/catalog/write.py)';

  test('real nutri.db and health.db keep the data contract (catalogue v4)', () {
    final health = File('assets/health.db');
    expect(asset.lengthSync() + health.lengthSync(), lessThanOrEqualTo(800000000),
        reason: 'contract: the two bundled files <= 800 MB');
    final db = openNutriDb(asset.path);
    expect(hasHealth(db), isTrue, reason: 'assets/health.db next to it');
    int count(String sql) => db.select(sql).single.values.first as int;

    expect(count('SELECT count(*) FROM foods'), greaterThan(30000));
    expect(count('SELECT count(*) FROM recipes'), greaterThan(100000));
    expect(count("SELECT count(*) FROM foods WHERE category = 'dish'"), greaterThan(1000), reason: 'dishes are foods');
    expect(db.select("SELECT name FROM sqlite_master WHERE name IN ('products', 'dishes')"), isEmpty,
        reason: 'products are in products.db, dishes in foods');
    // One default per everyday name; every word of db/catalog/defaults.tsv finds its food.
    expect(count('SELECT count(*) FROM (SELECT common_name FROM foods WHERE is_default GROUP BY 1 HAVING count(*) > 1)'), 0);
    for (final line in File('db/catalog/defaults.tsv').readAsLinesSync()) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final alias = line.split('\t').first;
      expect(db.select("SELECT 1 FROM food_aliases WHERE alias = ? AND lang = 'en'", [alias]), isNotEmpty, reason: alias);
    }
    // Every recipe line with a food points at a food; recipes compute nutrition, plausibly.
    expect(count('SELECT count(*) FROM recipe_ingredients WHERE food_id IS NOT NULL AND food_id NOT IN '
        '(SELECT id FROM foods)'), 0);
    expect(count('SELECT count(*) FROM recipes WHERE id NOT IN (SELECT recipe_id FROM recipe_ingredients '
        'WHERE food_id IS NOT NULL AND grams > 0)'), 0);
    // Only allergen names the app knows (agent_tools normalizeAllergen).
    expect(
        db.select('SELECT DISTINCT allergen FROM food_allergens').map((r) => r['allergen']).toSet(),
        everyElement(isIn({'peanuts', 'tree nuts', 'milk', 'egg', 'gluten', 'shellfish', 'fish', 'soy', 'sesame'})));
    final butter = db.select("SELECT a.allergen FROM foods f JOIN food_allergens a ON a.food_id = f.id "
        "WHERE f.name = 'Butter, salted' AND f.source_id = 'usda_sr'");
    expect(butter.map((r) => r['allergen']), contains('milk'));
    expect(db.select("SELECT rowid FROM recipes_fts WHERE recipes_fts MATCH 'chicken' LIMIT 1"), isNotEmpty);
    expect(int.parse(db.select("SELECT value FROM meta WHERE key = 'data_version'").single['value'] as String),
        greaterThanOrEqualTo(nutriDataVersion));
    // health.db: the curated guidelines, NIH answers, reference intakes, gout's foods to avoid.
    expect(count("SELECT count(*) FROM health.docs WHERE kind = 'guideline'"), greaterThan(40));
    expect(count("SELECT count(*) FROM health.docs WHERE kind = 'qa'"), greaterThan(10000));
    expect(count('SELECT count(*) FROM health.reference_values'), greaterThan(500));
    expect(count("SELECT count(*) FROM health.condition_foods WHERE condition_id = 3 AND effect = 'avoid'"),
        greaterThan(50));
    // Vitamins and minerals for what people log, on the food each word means.
    final user = openUserDb(':memory:');
    final tools = AgentTools(db, user);
    for (final word in ['rice', 'banana', 'egg', 'milk', 'chicken liver', 'cheese', 'apple', 'potato', 'salmon']) {
      expect(tools.staple(word)?.per100['iron_mg'], isNotNull, reason: word);
    }
    final liver = tools.staple('chicken liver')!.per100;
    expect(liver['iron_mg'], closeTo(9, 2.5));
    expect(liver['vitamin_b12_ug'], closeTo(17, 5));
    user.close();
    db.close();
  }, skip: skip);

  test('recipe ideas never repeat a title, even across 40 "Banana bread" recipes', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final tools = AgentTools(db, user);
    final titles = [
      for (var i = 0; i < 4; i++)
        for (final r in (tools.run('search_recipes', {'query': 'banana bread'}).card! as RecipeListCard).recipes)
          r.title.toLowerCase().trim()
    ];
    expect(titles.length, 20);
    expect(titles.toSet().length, 20);
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('"dinner with beef, mustard and honey": every suggestion has all three (regression)', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final tools = AgentTools(db, user);
    for (final args in [
      {'query': 'dinner', 'ingredients': 'beef, mustard, honey'},
      {'query': 'dinner with beef, mustard and honey'},
    ]) {
      final r = tools.run('search_recipes', args);
      expect((r.card! as RecipeListCard).recipes.length, 5);
      expect(r.forModel['recipes'].toString(), isNot(contains('without')), reason: '$args');
    }
    // Before: "fish" in the query only matched titles; now every idea contains fish.
    for (final s in (tools.route('can you suggest good dinner recipes? maybe with fish?')!.card! as RecipeListCard).recipes) {
      expect(db.select('SELECT 1 FROM recipe_ingredients ri JOIN food_allergens a ON a.food_id = ri.food_id '
          "WHERE ri.recipe_id = ? AND a.allergen = 'fish'", [s.id]), isNotEmpty, reason: s.title);
    }
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('phone test: allergic to peanuts, asked for peanuts; "more" keeps salmon and tomatoes', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final tools = AgentTools(db, user);
    (tools.run('set_allergen', {'allergen': 'peanuts'}).card! as ConfirmCard).apply();
    final peanut = tools.run('search_recipes', {'query': 'recipes with peanuts', 'ingredients': 'peanuts'});
    final list = peanut.card! as RecipeListCard;
    expect(list.avoided, ['peanuts']);
    expect(list.recipes.length, 5);
    for (final r in list.recipes) {
      expect(db.select('SELECT 1 FROM recipe_ingredients ri JOIN food_allergens a ON a.food_id = ri.food_id '
          "WHERE ri.recipe_id = ? AND a.allergen = 'peanuts'", [r.id]), isEmpty, reason: r.title);
    }
    final first = tools.run('search_recipes', {'query': 'recipes', 'ingredients': 'tomatoes, salmon'});
    final more = tools.run('search_recipes', {'query': 'more recipes'}, said: 'give me more');
    for (final r in [first, more]) {
      expect((r.card! as RecipeListCard).recipes.length, 5);
      expect(r.forModel['recipes'].toString(), isNot(contains('without')), reason: '${r.forModel['recipes']}');
    }
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('a week plan fills all 21 meals with different recipes, fast', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final watch = Stopwatch()..start();
    final plan = planWeek(AgentTools(db, user), DateTime(2026, 10, 5));
    expect(watch.elapsedMilliseconds, lessThan(3000));
    expect(plan.length, 21);
    expect(plan.map((p) => p.recipeId).toSet().length, 21);
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('plain foods win over products that repeat the word (bananas are not banana chips)', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final r = AgentTools(db, user).run('log_meal', {'items': '2 bananas, 1 protein bar and grapes 100 gramms'});
    final lines = (r.card! as ConfirmCard).lines;
    expect(lines[0], startsWith('Bananas, raw ·'));
    expect(lines[2], matches(RegExp(r'^Grapes?(, raw)? · 100 g')));
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('phone test: wholegrain toast is toasted whole wheat bread, not gruel; a slice of toast is 25 g', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final r = AgentTools(db, user).run('log_meal', {'items': 'a slice of wholegrain toast, whole wheat toast, a slice of toast'});
    expect((r.card! as ConfirmCard).lines, [
      startsWith('Bread, whole wheat, commercial, toasted · 33 g'),
      startsWith('Bread, whole wheat, commercial, toasted · 33 g'), // not "Whole Wheat French Toast"
      startsWith('Bread, white, toasted · 25 g'),
    ]);
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('phone test: "rice with chicken liver in cream" is cooked rice, liver and cream, not ice cream', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final tools = AgentTools(db, user);
    List<String> log(String items) => (tools.run('log_meal', {'items': items}).card! as ConfirmCard).lines;

    final meal = log('rice with chicken liver in cream');
    expect(meal, hasLength(3), reason: '"in cream" was silently dropped');
    expect(meal[0], contains('cooked'));
    expect(meal[1].toLowerCase(), allOf(contains('liver'), contains('chicken')));
    expect(int.parse(RegExp(r'· (\d+) g').firstMatch(meal[1])![1]!), greaterThanOrEqualTo(50), reason: 'a real portion');
    expect(meal[2], startsWith('Cream, fluid'));
    expect(log('cream').single, isNot(contains('ice cream')));
    expect(log('ice cream').single.toLowerCase(), startsWith('ice cream'));
    expect(log('sour cream').single.toLowerCase(), allOf(contains('sour'), contains('cream')));
    // Approximate amounts keep the amount, not a default serving.
    expect(log('roughly 200g rice').single, contains('200 g'));
    expect(log('about 100 g bread').single, contains('100 g'));
    expect(log('2 eggs').single, contains('100 g'));
    expect(log('buckwheat').single, contains('cooked'));
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);

  test('dishes are foods, government tables win, every value is measured, borrowed or estimated', () {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_real_');
    final db = openNutriDb(asset.path), user = openUserDb('${tmp.path}/user.db');
    final tools = AgentTools(db, user);
    int count(String sql) => db.select(sql).single.values.first as int;

    final pizza = (tools.run('log_meal', {'items': 'pizza'}).card! as ConfirmCard).items.single;
    expect(pizza.estimated, isTrue, reason: 'a dish is an estimate');
    expect(pizza.per100['iron_mg'], isNotNull);
    expect(count("SELECT COUNT(*) FROM foods WHERE source_id = 'usda_fndds'"), greaterThan(5000));
    expect(count("SELECT COUNT(*) FROM foods WHERE source_id IN ('ciqual', 'cofid')"), greaterThan(5000));
    expect(count("SELECT COUNT(*) FROM foods WHERE source_id IN ('cnf', 'frida', 'livsmedelsverket', "
        "'matvaretabellen', 'afcd', 'swiss')"), greaterThan(10000), reason: 'the new national tables');
    expect(authority(db.select('SELECT source_id FROM foods WHERE id = ?',
        [tools.searchFood('egg').firstWhere((f) => f.kind == 'food').id]).single['source_id'] as String), 2);
    final toad = db.select('SELECT source_id, iron_mg FROM foods WHERE id = ?',
        [tools.searchFood('toad in the hole').firstWhere((f) => f.kind == 'food').id]).single;
    expect(authority(toad['source_id'] as String), 2);
    expect(toad['iron_mg'], isNotNull);
    // A value not measured for a row is listed as borrowed or estimated on it.
    expect(count("SELECT count(*) FROM foods WHERE borrowed != ''"), greaterThan(1000));
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);
}
