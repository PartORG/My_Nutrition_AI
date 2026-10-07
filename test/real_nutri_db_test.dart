import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/plan.dart';
import 'package:myfoodmind/data/user_db.dart';

/// Gate for the real assets/nutri.db (built by tool/build_real_nutri_db.py, not in git).
/// The other tests use the dummy fixture test/nutri_test.db.
void main() {
  final asset = File('assets/nutri.db');
  final skip = asset.existsSync() ? false : 'assets/nutri.db not built (tool/build_real_nutri_db.py)';

  test('real nutri.db keeps the data contract', () {
    expect(asset.lengthSync(), lessThanOrEqualTo(300000000), reason: 'contract: nutri.db <= 300 MB');
    final db = openNutriDb(asset.path);
    int count(String sql) => db.select(sql).single.values.first as int;

    expect(count('SELECT count(*) FROM foods'), greaterThan(10000));
    expect(count('SELECT count(*) FROM recipes'), greaterThan(10000));
    expect(count('SELECT count(*) FROM products'), greaterThan(10000));
    expect(count('SELECT count(*) FROM dishes'), greaterThan(100));
    // Every recipe has ingredients, so its nutrition and allergens are computable.
    expect(count('SELECT count(*) FROM recipes WHERE id NOT IN (SELECT recipe_id FROM recipe_nutrition)'), 0);
    expect(count('SELECT count(*) FROM recipe_nutrition WHERE kcal < 15 OR kcal > 2500'), 0);
    // Only allergen names the app knows (agent_tools normalizeAllergen).
    expect(
        db.select('SELECT DISTINCT allergen FROM allergens').map((r) => r['allergen']).toSet(),
        everyElement(isIn({'peanuts', 'tree nuts', 'milk', 'egg', 'gluten', 'shellfish', 'fish', 'soy', 'sesame'})));
    // Spot checks that matching and allergens came out right.
    final butter = db.select("SELECT a.allergen FROM foods f JOIN allergens a ON a.food_id = f.id "
        "WHERE f.name = 'Butter, with salt'");
    expect(butter.map((r) => r['allergen']), contains('milk'));
    expect(db.select("SELECT rowid FROM recipes_fts WHERE recipes_fts MATCH 'chicken' LIMIT 1"), isNotEmpty);
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
    expect(titles.length, 12);
    expect(titles.toSet().length, 12);
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
    expect(lines[0], startsWith('Banana ·'));
    expect(lines[2], matches(RegExp(r'^Grapes? · 100 g')));
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: skip);
}
