import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/nutri_db.dart';

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
}
