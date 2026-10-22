import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/data/diary.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late Database nutri, user;
  late AgentTools tools;
  var now = DateTime(2026, 10, 4, 8, 30);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_tools_');
    nutri = openNutriDb('test/nutri_test.db');
    user = openUserDb('${tmp.path}/user.db');
    now = DateTime(2026, 10, 4, 8, 30);
    tools = AgentTools(nutri, user, clock: () => now);
  });
  tearDown(() {
    nutri.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  ConfirmCard confirmOf(ToolResult r) => r.card! as ConfirmCard;
  int count(String table) => user.select('SELECT COUNT(*) AS n FROM $table').single['n'] as int;

  group('recipes', () {
    test('ingredients the user has rank first', () {
      final r = tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, rice, broccoli'});
      final list = (r.card! as RecipeListCard).recipes;
      expect(list.first.title, 'Chicken broccoli stir-fry');
      expect(list.first.kcal, closeTo(548.8, 0.1));
      expect((r.forModel['recipes'] as List).first, startsWith('1. Chicken broccoli stir-fry (549 kcal'));
    });

    test('recipes with the profile\'s allergens are excluded', () {
      confirmOf(tools.run('set_allergen', {'allergen': 'eggs'})).apply();
      final r = tools.run('search_recipes', {'query': 'breakfast'});
      final titles = (r.card! as RecipeListCard).recipes.map((e) => e.title);
      expect(titles, isNot(contains('Shakshuka')));
      expect(titles, contains('Overnight oats with banana'));
      expect(r.forModel['note'], contains('allergens or foods to avoid'));
    });

    test('show and save resolve "2", "the first one", titles and "that"', () {
      final list = (tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, broccoli, lentils, egg, oats'})
          .card! as RecipeListCard).recipes;
      expect(list.length, 4, reason: 'all 4 recipes with any of them (up to 5 are shown)');
      final second = list[1].title;
      expect((tools.run('recipe', {'action': 'show', 'recipe': '2'}).card! as RecipeCard).title, second);
      // No or unknown action shows: never a write the model didn't ask for.
      expect((tools.run('recipe', {'recipe': '2'}).card! as RecipeCard).title, second);
      expect((tools.run('recipe', {'action': 'show', 'recipe': 'the first one'}).card! as RecipeCard).title,
          'Chicken broccoli stir-fry');
      final soup = tools.run('recipe', {'action': 'show', 'recipe': 'lentil soup'}).card! as RecipeCard;
      expect(soup.title, 'Lentil soup');
      expect(soup.ingredients.first, (name: 'lentils, cooked', grams: 400.0));
      final save = tools.run('recipe', {'action': 'save', 'recipe': 'that one'});
      expect(confirmOf(save).lines, ['Lentil soup']);
      expect(count('saved_recipes'), 0, reason: 'nothing saved before ✓');
      confirmOf(save).apply();
      expect(user.select('SELECT title FROM saved_recipes').single['title'], 'Lentil soup');
    });

    test('"I ate this" logs one serving of the recipe on ✓', () {
      final r = tools.logRecipe(4); // overnight oats: 315 g in 1 serving
      expect(confirmOf(r).title, 'Log breakfast');
      expect(confirmOf(r).lines.single, 'Overnight oats with banana · 315 g · 462 kcal');
      expect(count('meal_log'), 0);
      confirmOf(r).apply();
      final status = tools.run('nutrition_status', {'period': 'today'});
      expect((status.forModel['eaten'] as Map)['kcal'], 462);
    });

    test('a recipe is logged under its own meal, not the time of day; the user can change it', () {
      now = DateTime(2026, 10, 4, 20, 40); // evening, as in the phone test
      final oats = confirmOf(tools.logRecipe(4)); // tagged breakfast
      expect(oats.mealType, 'breakfast');
      expect(oats.title, 'Log breakfast');
      final viaChat = confirmOf(tools.run('log_meal', {'items': 'lentil soup'})); // tagged lunch
      expect(viaChat.mealType, 'lunch');
      oats.mealType = 'snack'; // picked on the card before Save
      oats.apply();
      viaChat.apply();
      expect([for (final r in user.select('SELECT meal_type FROM meal_log ORDER BY id')) r['meal_type']],
          ['snack', 'lunch']);
      // Untagged food still follows the time of day.
      expect(confirmOf(tools.run('log_meal', {'items': 'banana'})).mealType, 'dinner');
    });

    test('asking again shows recipes not suggested yet; a vague ask gets random ideas', () {
      List<String> titles(Map<String, String> args) =>
          [for (final r in (tools.run('search_recipes', args).card! as RecipeListCard).recipes) r.title];
      const have = 'egg, lentils, salmon, oats, tomato, spinach, chickpeas'; // 6 recipes: 5, then 1 more
      final first = titles({'query': 'dinner', 'ingredients': have});
      final again = titles({'query': 'something different', 'ingredients': have});
      expect(again.toSet().intersection(first.toSet()), isEmpty);
      expect(titles({'query': 'something new for breakfast'}), isNotEmpty);
    });

    test('taste steers ideas: recipes sharing a saved or 5-star recipe\'s ingredients come first', () {
      List<String> dinner(AgentTools t) =>
          [for (final r in (t.run('search_recipes', {'query': 'dinner'}).card! as RecipeListCard).recipes) r.title];
      expect(dinner(tools).first, isNot('Chickpea tofu curry'));
      // Shakshuka (tomato, onion, eggs, feta) saved: the curry shares its tomato and onion.
      user.execute("INSERT INTO saved_recipes VALUES (2, 'Shakshuka', 0)");
      expect(dinner(AgentTools(nutri, user, clock: () => now)).first, 'Chickpea tofu curry');
      // Liked by stars works the same; the liked recipe itself is not boosted by taste.
      user.execute('DELETE FROM saved_recipes');
      tools.rate(2, 5);
      expect(dinner(AgentTools(nutri, user, clock: () => now)).first, 'Chickpea tofu curry');
    });

    test('stars steer ideas: 1-2 never again, 4-5 first; eaten recipes are listed with stars', () {
      List<String> titles() => [
            for (final r in (tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, rice, broccoli'})
                    .card! as RecipeListCard)
                .recipes)
              r.title
          ];
      final before = titles();
      final stir = (tools.run('recipe', {'action': 'show', 'recipe': 'chicken broccoli stir-fry'}).card! as RecipeCard).id;
      tools.rate(stir, 1);
      expect(tools.rating(stir), 1);
      expect(AgentTools(nutri, user, clock: () => now).run('search_recipes',
          {'query': 'dinner', 'ingredients': 'chicken, rice, broccoli'}).forModel['recipes'].toString(),
          isNot(contains('stir-fry')));
      expect(before, contains('Chicken broccoli stir-fry'));

      confirmOf(tools.logRecipe(stir)).apply();
      expect(user.select('SELECT recipe_id FROM meal_log').single['recipe_id'], stir);
      expect(tools.recentRecipes().single, (id: stir, title: 'Chicken broccoli stir-fry', at: now, stars: 1));
      // "rate it 5 stars" with nothing on screen: the recipe eaten last.
      confirmOf(AgentTools(nutri, user, clock: () => now).run('recipe', {'action': 'rate', 'recipe': 'it', 'stars': 5})).apply();
      expect(tools.rating(stir), 5);
    });

    test('asked-for ingredients are really in the recipes; food words in the query count too', () {
      List<String> titles(Map<String, dynamic> args) =>
          [for (final r in (tools.run('search_recipes', args).card! as RecipeListCard).recipes) r.title];
      // "fish" is the whole group (salmon), not foods named "fish".
      expect(titles({'query': 'good dinner recipes with fish'}), ['Salmon zucchini bowl']);
      expect(titles({'query': 'dinner', 'ingredients': 'fish'}), ['Salmon zucchini bowl']);
      // Most of what was asked for first; what a recipe lacks is told to the model.
      final r = tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, broccoli, egg'});
      expect((r.forModel['recipes'] as List).first, contains('Chicken broccoli stir-fry (549 kcal per serving, 20 min, without egg)'));
      expect((r.forModel['recipes'] as List).last, contains('without chicken, broccoli'));
    });

    test('asking for an allergen says so and shows recipes without it', () {
      confirmOf(tools.run('set_allergen', {'allergen': 'almonds'})).apply();
      final r = tools.run('search_recipes', {'query': 'dinner with almonds', 'ingredients': 'almonds'});
      final card = r.card! as RecipeListCard;
      expect(card.avoided, ['tree nuts']);
      expect(card.recipes, isNotEmpty);
      expect(card.recipes.map((e) => e.title), isNot(contains('Overnight oats with banana')));
      expect(r.forModel['avoided'], contains('tree nuts'));
      expect((tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken'}).card! as RecipeListCard).avoided,
          isEmpty);
    });

    test('"more" keeps the ingredients of the last search; a new meal or food starts over', () {
      List<String> titles(Map<String, dynamic> args, [String said = '']) =>
          [for (final r in (tools.run('search_recipes', args, said: said).card! as RecipeListCard).recipes) r.title];
      expect(titles({'query': 'dinner', 'ingredients': 'salmon'}), ['Salmon zucchini bowl']);
      expect(titles({'query': 'more recipes'}, 'Give me more'), ['Salmon zucchini bowl'],
          reason: 'phone test: "more" lost salmon and tomatoes and gave random ideas');
      expect(titles({'query': 'ideas'}, 'Інші рецепти'), ['Salmon zucchini bowl']);
      expect(titles({'query': 'other recipes', 'ingredients': 'chicken'}).first, 'Chicken broccoli stir-fry');
    });

    test('the router sends English recipe requests straight to the search', () {
      final r = tools.route('Can you suggest good dinner recipes? Maybe with fish?')!;
      expect((r.card! as RecipeListCard).recipes.single.title, 'Salmon zucchini bowl');
      expect(tools.route('show me the recipe for shakshuka'), isNull, reason: 'one recipe: the model');
      expect(tools.route('I had the recipe you suggested'), isNull);
    });

    test('unknown recipe is an error for the model, not a crash', () {
      expect(tools.run('recipe', {'action': 'show', 'recipe': 'unicorn pie'}).forModel['error'], isNotNull);
    });
  });

  group('nutrition', () {
    test('lookup returns per-100 g values from the database', () {
      final r = tools.run('lookup_nutrition', {'food': 'How many calories are in an avocado?'});
      expect((r.forModel['per_100g'] as Map)['kcal'], 160);
      expect((r.card! as NutritionCard).values['fat_g'], 14.7);
    });

    test('log meal: counts × serving size, grams, dishes; saved only on ✓', () {
      final r = tools.run('log_meal', {'items': '2 eggs, toast', 'meal_type': 'breakfast'});
      expect(confirmOf(r).lines, ['egg · 100 g · 143 kcal', 'bread, toasted · 30 g · 94 kcal']);
      expect(r.forModel['status'], contains('NOT saved'));
      expect(count('meal_log'), 0);
      confirmOf(r).apply();
      final status = tools.run('nutrition_status', {'period': 'today'});
      expect((status.forModel['eaten'] as Map)['kcal'], 237);
      expect(status.forModel['meals_logged'], 2);
      expect(status.forModel['goals'], startsWith('not set'));
      user.execute("INSERT INTO goal_overrides VALUES ('kcal', 2000), ('protein_g', 100)");
      final withGoals = tools.run('nutrition_status', {'period': 'today'});
      expect(withGoals.forModel['left_today'], {'kcal': 1763, 'protein_g': 84}); // 100 − (12.6 + 3.9)
      expect((tools.run('nutrition_status', {'period': 'week'}).forModel['goals'] as Map)['kcal'], 14000);
    });

    test('status: vitamins and minerals as a share of their goal with Basic; the upper limits for everyone', () {
      user.execute('INSERT INTO body (id, sex, birth_year, height_cm, weight_kg, activity, goal, units, updated_at) '
          "VALUES (1, 'female', 1996, 165, 60, 'light', 'maintain', 'metric', 0)");
      tools.quickAdd('Ramen', {'kcal': 600, 'protein_g': 20, 'fat_g': 20, 'carbs_g': 80, 'sodium_mg': 3000}, 'lunch');
      tools.logFood(tools.searchFood('egg').firstWhere((f) => f.kind == 'food'), 100, 'breakfast');
      var r = tools.run('nutrition_status', {'period': 'today'}).forModel;
      expect(r['vitamins_minerals_percent_of_goal'], containsPair('iron_mg', 10)); // 1.75 of 18 mg
      expect(r['over_upper_limit'], ['sodium_mg 3142 of 2000']); // the egg has 142 mg
      expect(r['not_known_for_every_meal'], contains('iron_mg'), reason: 'the ramen has no label for it');
      tools.basic = () => false;
      r = tools.run('nutrition_status', {'period': 'today'}).forModel;
      expect(r.containsKey('vitamins_minerals_percent_of_goal'), isFalse, reason: 'micronutrient goals are Basic');
      expect(r['over_upper_limit'], ['sodium_mg 3142 of 2000'], reason: 'safety, like allergens');
    });

    test('my_patterns: the card with Basic, a note on Free', () {
      for (var d = 1; d <= 3; d++) {
        now = DateTime(2026, 10, d, 13);
        tools.quickAdd('Soup', {'kcal': 900, 'protein_g': 20, 'fat_g': 20, 'carbs_g': 80}, 'lunch');
        now = DateTime(2026, 10, d, 22);
        tools.quickAdd('Pasta', {'kcal': 900, 'protein_g': 20, 'fat_g': 20, 'carbs_g': 80}, 'dinner');
      }
      now = DateTime(2026, 10, 4, 12);
      expect(tools.run('my_patterns', {}).forModel['note'], contains('need a week'));
      for (var d = 4; d <= 9; d++) {
        now = DateTime(2026, 10, d, 13);
        tools.quickAdd('Soup', {'kcal': 900, 'protein_g': 20, 'fat_g': 20, 'carbs_g': 80}, 'lunch');
        now = DateTime(2026, 10, d, 22);
        tools.quickAdd('Pasta', {'kcal': 900, 'protein_g': 20, 'fat_g': 20, 'carbs_g': 80}, 'dinner');
      }
      now = DateTime(2026, 10, 10, 12);
      final r = tools.run('my_patterns', {});
      expect(r.forModel['patterns'], contains('breakfast skipped on 9 of 9 days'));
      expect(r.card, isA<PatternsCard>());
      tools.basic = () => false;
      expect(tools.run('my_patterns', {}).forModel['note'], contains('Basic'));
    });

    test('adding to a saved breakfast shows only the new food, even when the model repeats the breakfast', () {
      confirmOf(tools.run('log_meal', {'items': '2 eggs, toast', 'meal_type': 'breakfast'})).apply();
      now = now.add(const Duration(minutes: 5));
      final more = confirmOf(tools.run('log_meal', {'items': '2 eggs, toast, banana', 'meal_type': 'breakfast'}));
      expect(more.items.map((i) => i.label), ['banana']);
      more.apply();
      expect(count('meal_log'), 3, reason: 'no second eggs and toast');
      // Nothing new: a second helping is logged again; another meal type is not touched.
      expect(confirmOf(tools.run('log_meal', {'items': 'banana', 'meal_type': 'breakfast'})).items.length, 1);
      expect(confirmOf(tools.run('log_meal', {'items': '2 eggs, toast, banana', 'meal_type': 'lunch'})).items.length, 3);
    });

    test('"a handful of almonds" and "200 g greek yogurt" parse (regression)', () {
      expect(confirmOf(tools.run('log_meal', {'items': 'a handful of almonds'})).lines.single,
          'almonds · 28 g · 162 kcal');
      expect(confirmOf(tools.run('log_meal', {'items': '200 g greek yogurt'})).lines.single,
          'greek yogurt, plain · 200 g · 118 kcal');
      expect(confirmOf(tools.run('log_meal', {'items': 'almonds'})).lines.single,
          'almonds · 28 g · 162 kcal');
    });

    test('dishes are estimates shown with ≈; meal type falls back to the time of day', () {
      now = DateTime(2026, 10, 4, 19);
      final r = tools.run('log_meal', {'items': 'lasagna'});
      expect(confirmOf(r).title, 'Log dinner');
      expect(confirmOf(r).lines.single, 'lasagna · 350 g · ≈473 kcal');
      confirmOf(r).apply();
      expect(user.select('SELECT estimated FROM meal_log').single['estimated'], 1);
    });

    test('the best-covered name wins: "banana" is the fruit, not the oats recipe (regression)', () {
      String label(String items) => confirmOf(tools.run('log_meal', {'items': items})).lines.first.split(' · ').first;
      expect(label('banana'), 'banana');
      expect(label('overnight oats with banana'), 'Overnight oats with banana');
      expect(label('lentil soup'), 'Lentil soup');
      expect(label('chicken caesar salad'), 'caesar salad');
      expect(label('shakshuka'), 'Shakshuka', reason: 'the recipe: v4 has no recipe-linked dish without values');
      expect(label('2 eggs'), 'egg');
      // Splitting still happens when the phrase isn't one dish's name.
      expect(confirmOf(tools.run('log_meal', {'items': 'lasagna and banana'})).lines.length, 2);
      expect(confirmOf(tools.run('log_meal', {'items': 'chicken with rice'})).lines.length, 2);
    });

    test('the user\'s own words: lead-in, meal and trailing amounts are understood', () {
      expect(mealFoods('I ate 2 bananas, 1 apple and grapes 100 gramms for breakfast today'),
          '2 bananas, 1 apple and grapes 100 gramms');
      expect(mealFoods('Add breakfast: oats and milk'), 'oats and milk');
      expect(mealFoods('can you add breakfast'), '');
      final r = tools.run('log_meal', {'items': 'I had 2 bananas and peanuts 50 gramms for lunch'});
      expect(confirmOf(r).mealType, 'lunch');
      expect(confirmOf(r).lines, ['banana · 236 g · 210 kcal', 'peanuts · 50 g · 284 kcal']);
      expect(tools.run('log_meal', {'items': 'add breakfast'}).forModel['error'], contains('ask'));
    });

    test('"I ate peanuts" is a meal, never an allergy; "I ate…" never becomes recipe ideas', () {
      const said = 'I ate peanuts 50 gramms';
      final r = tools.run('set_allergen', {'allergen': 'peanuts'}, said: said);
      expect(confirmOf(r).title, 'Log breakfast');
      expect(confirmOf(r).lines.single, startsWith('peanuts · 50 g'));
      expect(tools.run('set_allergen', {'allergen': 'peanuts'}, said: 'what is in peanuts?').forModel['error'],
          contains('nothing was added'));
      expect(confirmOf(tools.run('set_allergen', {'allergen': 'peanuts'}, said: "I'm allergic to peanuts")).title,
          'Add allergy');
      expect(tools.run('search_recipes', {'query': 'banana'}, said: 'I had a banana').card, isA<ConfirmCard>());
      expect(tools.run('search_recipes', {'query': 'banana'}, said: 'I had a banana, what should I cook?').card,
          isA<RecipeListCard>());
      expect(tools.run('search_recipes', {'query': 'dinner'}, said: 'I had chicken yesterday, something different').card,
          isA<RecipeListCard>());
    });

    test('meal cards: grams edited before Save are what is logged; 0 g leaves a food out', () {
      final c = confirmOf(tools.run('log_meal', {'items': '2 eggs, 1 apple'}));
      c.items[0].grams = 150; // three eggs, not two
      c.items[1].grams = 0;
      expect(c.lines.first, 'egg · 150 g · 215 kcal');
      c.apply();
      final rows = user.select('SELECT description, grams, kcal FROM meal_log');
      expect(rows.map((r) => (r['description'], r['grams'], (r['kcal'] as num).round())), [('egg', 150.0, 215)]);
    });

    test('Log tab: recent foods, repeat yesterday, edit a meal, quick add', () {
      final egg = tools.searchFood('egg').firstWhere((f) => f.kind == 'food');
      now = DateTime(2026, 10, 3, 8);
      tools.logFood(egg, 100, 'breakfast');
      tools.logFood(egg, 100, 'breakfast');
      now = DateTime(2026, 10, 4, 8, 30);
      final recent = recentFoods(user, now).single;
      expect((recent.label, recent.servingG, recent.per100['kcal']!.round()), ('egg', 100.0, 143));

      expect(mealTotalsOn(user, DateTime(2026, 10, 3)), {'breakfast': 286.0});
      expect(repeatMeal(user, DateTime(2026, 10, 3), 'breakfast', now), 2);
      expect(totalsOn(user, now)['kcal'], 286);

      final id = mealsOn(user, now).first.id;
      updateMeal(user, id, grams: 50, type: 'snack');
      final m = mealsOn(user, now).first;
      expect((m.grams, m.kcal.round(), m.type), (50.0, 72, 'snack'));

      // The agent picked the wrong food: swap it, keeping amount, time and meal.
      final rice = tools.searchFood('white rice').firstWhere((f) => f.kind == 'food');
      replaceMeal(user, id, rice);
      final swapped = mealsOn(user, now).first;
      expect((swapped.label, swapped.grams, swapped.type, swapped.at), (rice.label, 50.0, 'snack', m.at));
      expect(swapped.kcal, closeTo(rice.per100['kcal']! / 2, .01));

      tools.quickAdd('Restaurant pasta', {'kcal': 650, 'protein_g': 20}, 'dinner');
      expect(mealsOn(user, now).last.label, 'Restaurant pasta');
      expect(totalsOn(user, now)['kcal']!.round(), 858); // egg 143 + rice 65 (swapped above) + 650
    });

    test('water: "2 glasses of water" is a water card, not food; goal from weight', () {
      expect(waterMl('2 glasses of water'), 500);
      expect(waterMl('500 ml water'), 500);
      expect(waterMl('a bottle of sparkling water'), 500);
      expect(waterMl('1.5 l water'), 1500);
      expect(waterMl('water'), 250);
      expect(waterMl('water and a banana'), isNull);
      final r = tools.route('I drank 2 glasses of water')!;
      expect(confirmOf(r).lines, ['Water · 500 ml']);
      confirmOf(r).apply();
      expect(waterOn(user, now), 500);
      undoWater(user, now);
      expect(waterOn(user, now), 0);
      expect(waterGoal(user), 2000);
      setPref(user, 'water_goal_ml', '2500');
      expect(waterGoal(user), 2500);
    });

    test('fasting: start since the last meal, one running fast, end', () {
      final egg = tools.searchFood('egg').firstWhere((f) => f.kind == 'food');
      tools.logFood(egg, 50, 'dinner');
      expect(lastMealAt(user), now);
      startFast(user, lastMealAt(user)!, 16);
      startFast(user, now.add(const Duration(hours: 1)), 14); // a second start ends the first
      expect(user.select('SELECT COUNT(*) AS n FROM fasts WHERE ended_at IS NULL').single['n'], 1);
      expect(currentFast(user)!.targetHours, 14);
      endFast(user, now.add(const Duration(hours: 15)));
      expect(currentFast(user), isNull);
    });

    test('products come from the downloaded products.db; every word must match', () {
      final off = sqlite3.openInMemory()
        ..execute('CREATE TABLE products (barcode TEXT PRIMARY KEY, name TEXT NOT NULL, kcal REAL NOT NULL, '
            'protein_g REAL NOT NULL, fat_g REAL NOT NULL, carbs_g REAL NOT NULL, fiber_g REAL, sugar_g REAL, sodium_mg REAL); '
            "CREATE VIRTUAL TABLE products_fts USING fts5 (name, barcode UNINDEXED, content = 'products'); "
            "INSERT INTO products VALUES ('4000417326102', 'Ritter Sport Alpenmilch', 532, 8, 32, 53, 2, 50, 100), "
            "('7622201679958', 'Milka Alpenmilch', 539, 6, 31, 58, 2, 57, 300); "
            "INSERT INTO products_fts(products_fts) VALUES ('rebuild');");
      final withOff = AgentTools(nutri, user, clock: () => now, products: off);
      final hits = withOff.searchFood('ritter alpenmilch').where((f) => f.kind == 'product');
      expect(hits.map((f) => f.label), ['Ritter Sport Alpenmilch']);
      expect(withOff.searchFood('yogurt').where((f) => f.kind == 'product'), isEmpty, reason: 'only the products.db given');
      off.close();
    });

    test('micronutrients: known ones flow from foods and recipes into the log; unknown stays unknown', () {
      confirmOf(tools.run('log_meal', {'items': '2 eggs, 100 g broccoli'})).apply(); // broccoli: no values in the test db
      final (from, to) = dayRange(now);
      final m = panelTotals(user, nutri, from, to);
      expect(m.meals, 2);
      expect(m.partial, contains('iron_mg'), reason: 'broccoli does not know it: the total is "at least"');
      expect(m.totals['iron_mg'], closeTo(1.75, .01)); // 100 g egg
      expect(m.approx, isEmpty);
      tools.logFood(tools.searchFood('banana').firstWhere((f) => f.kind == 'food'), 120, 'snack');
      expect(panelTotals(user, nutri, from, to).approx, {'zinc_mg', 'vitamin_b7_ug'}, reason: "banana's estimates");
      expect(user.select("SELECT iron_mg FROM meal_log WHERE description = 'broccoli'").single['iron_mg'], isNull);
      final shakshuka = tools.showRecipeById(2).card! as RecipeCard;
      expect(shakshuka.perServing['iron_mg'], closeTo(1.75, .01)); // 100 g egg per serving
      expect(tools.run('lookup_nutrition', {'food': 'banana'}).forModel['per_100g'], containsPair('potassium_mg', 358));
    });

    test('weekly review: from the logs; the weakest point twice in a week is the focus', () {
      final egg = tools.searchFood('egg').firstWhere((f) => f.kind == 'food');
      for (final d in [2, 3, 4]) {
        now = DateTime(2026, 10, d, 8);
        tools.logFood(egg, 100, 'breakfast'); // 143 kcal, 12.6 g protein
      }
      now = DateTime(2026, 10, 4, 20);
      logWater(user, 1000, now);
      final r = weeklyReview(user, {'kcal': 2000, 'protein_g': 100}, now);
      expect((r.logged, r.avgKcal!.round(), r.lowProtein, r.overSugar), (3, 143, 3, 0));
      expect(r.avgWater.round(), 143); // 1000 ml over 7 days
      expect(r.topFood, 'egg');
      expect(r.focus, 'protein_g');
      expect(weeklyReview(user, {}, now).focus, isNull, reason: 'no goals, nothing to miss');
    });

    test('unknown food is reported, known ones still logged', () {
      expect(tools.run('log_meal', {'items': 'unicorn steak'}).forModel['error'], isNotNull);
      final r = tools.run('log_meal', {'items': 'banana, unicorn steak'});
      expect(r.forModel['not_found'], ['unicorn steak']);
      expect(confirmOf(r).lines.last, 'Not found: unicorn steak');
    });

    test('week status counts the last 7 days only', () {
      now = DateTime(2026, 9, 20, 12);
      confirmOf(tools.run('log_meal', {'items': 'banana'})).apply(); // 14 days ago
      now = DateTime(2026, 10, 2, 12);
      confirmOf(tools.run('log_meal', {'items': 'banana'})).apply();
      now = DateTime(2026, 10, 4, 12);
      final week = tools.run('nutrition_status', {'period': 'week'});
      expect(week.forModel['meals_logged'], 1);
      final today = tools.run('nutrition_status', {'period': 'today'});
      expect(today.forModel['meals_logged'], 0);
      expect(today.forModel['note'], contains('Saved recipes do not count as eaten'),
          reason: 'user saved recipes, then asked what they ate and got zeros (phone test)');
    });
  });

  group('Log tab', () {
    test('search covers foods (dishes among them), recipes and, with products.db, products', () {
      expect({for (final f in tools.searchFood('pasta')) f.kind}, {'food'}, reason: 'no products.db, no products');
      final products = sqlite3.open('test/products_test.db', mode: OpenMode.readOnly);
      final withProducts = AgentTools(nutri, user, clock: () => now, products: products);
      expect({for (final f in withProducts.searchFood('pasta')) f.kind}, containsAll(['food', 'product']));
      products.close();
      final lasagna = tools.searchFood('lasagna').first;
      expect((lasagna.kind, lasagna.estimated), ('food', true), reason: 'a dish is a food, and an estimate');
      expect(tools.searchFood('shakshuka').map((f) => f.kind), contains('recipe'));
      final egg = tools.searchFood('egg').firstWhere((f) => f.kind == 'food');
      expect((egg.label, egg.servingG, egg.per100['kcal']), ('egg', 50.0, 143.0));
      expect(tools.searchFood('the of'), isEmpty);
    });

    test('logFood writes the scaled snapshot and the diary sees it', () {
      now = DateTime(2026, 10, 4, 13);
      final egg = tools.searchFood('egg').firstWhere((f) => f.kind == 'food');
      tools.logFood(egg, 150, tools.mealTypeNow());
      final meals = mealsOn(user, now);
      expect(meals.single.label, 'egg');
      expect(meals.single.type, 'lunch');
      expect(meals.single.kcal, closeTo(214.5, .01));
      expect(totalsOn(user, now)['protein_g'], closeTo(18.9, .01));
      expect(totalsOn(user, now.add(const Duration(days: 1)))['kcal'], 0);
      deleteMeal(user, meals.single.id);
      expect(mealsOn(user, now), isEmpty);
    });
  });

  group('allergies, journal, readings', () {
    test('allergen names are normalised', () {
      expect(normalizeAllergen('peanuts'), 'peanuts');
      expect(normalizeAllergen('Tree nut allergy'), 'tree nuts');
      expect(normalizeAllergen('lactose intolerant'), 'milk');
      expect(normalizeAllergen('celiac'), 'gluten');
      expect(normalizeAllergen('shrimp'), 'shellfish');
      confirmOf(tools.run('set_allergen', {'allergen': 'peanut'})).apply();
      confirmOf(tools.run('set_allergen', {'allergen': 'peanuts', 'remove': true})).apply();
      expect(count('user_allergens'), 0);
    });

    test('readings parse units; unreadable values go back to the model', () {
      String line(String kind, String value) =>
          confirmOf(tools.run('log_health', {'kind': kind, 'value': value})).lines.single;
      expect(line('glucose', '140'), '140 mg/dL');
      expect(line('glucose', '6.1 mmol/L'), '6.1 mmol/L');
      expect(line('blood_pressure', '130 over 85'), '130/85 mmHg');
      expect(line('weight', '165 lbs'), '165 lb');
      expect(line('weight', '72,5 kg'), '72.5 kg');
      expect(tools.run('log_health', {'kind': 'blood_pressure', 'value': '130'}).forModel['error'],
          isNotNull);
      final r = tools.run('log_health', {'kind': 'blood_pressure', 'value': '118/76'});
      confirmOf(r).apply();
      final row = user.select('SELECT value, value2, unit FROM readings').single;
      expect([row['value'], row['value2'], row['unit']], [118.0, 76.0, 'mmHg']);
    });

    test('symptom and fact writes wait for ✓', () {
      final s = tools.run('log_health', {'kind': 'symptom', 'value': 'Fatigue', 'severity': '4'});
      expect(confirmOf(s).lines.single, 'Fatigue · severity 4/5');
      final f = tools.run('remember_fact', {'fact': 'Has an air fryer'});
      expect(count('symptoms') + count('memory_facts'), 0);
      confirmOf(s).apply();
      confirmOf(f).apply();
      expect(count('symptoms') + count('memory_facts'), 2);
    });

    test('diets block recipes by food name and allergens; cautions name the diet', () {
      confirmOf(tools.run('set_allergen', {'allergen': 'vegetarian'}, said: "I'm vegetarian")).apply();
      expect(tools.excludedRecipes(), containsAll([1, 5])); // chicken; salmon (fish)
      expect(tools.excludedRecipes(), isNot(contains(2))); // shakshuka: eggs are fine
      final stir = tools.showRecipeById(1).card! as RecipeCard;
      expect(stir.cautions.map((c) => (c.food, c.allergen)), [('chicken breast, cooked', 'vegetarian')]);

      final vegan = tools.run('set_allergen', {'allergen': 'vegan'}, said: 'I am vegan now');
      expect(confirmOf(vegan).title, 'Add diet');
      confirmOf(vegan).apply();
      expect(tools.excludedRecipes(), contains(2));

      user.execute('DELETE FROM user_allergens');
      confirmOf(tools.run('set_allergen', {'allergen': 'pescatarian'})).apply();
      expect(tools.excludedRecipes(), contains(1));
      expect(tools.excludedRecipes(), isNot(contains(5)));
    });

    test('"vegan tonight" is a wish, not a diet or a fact; "I\'m vegetarian" is a diet', () {
      expect(tools.run('set_allergen', {'allergen': 'vegan'}, said: 'something vegan tonight').forModel['error'],
          contains('nothing was added'));
      expect(tools.run('set_allergen', {'allergen': 'vegetarian'}, said: 'vegetarian dinner ideas').forModel['error'],
          isNotNull);
      expect(tools.run('remember_fact', {'fact': 'wants vegan food tonight'}, said: 'I want vegan food tonight')
          .forModel['error'], isNotNull);
      expect(confirmOf(tools.run('remember_fact', {'fact': 'is vegetarian'}, said: "I'm vegetarian")).title, 'Add diet');
      expect(confirmOf(tools.run('remember_fact', {'fact': 'likes vegan food'}, said: 'I like vegan food')).title,
          'Remember');
    });

    test('the router: diets and allergies in four languages, wishes go to the model', () {
      List<String>? said(String s) => (tools.route(s)?.card as ConfirmCard?)?.lines;
      expect(said("I'm vegetarian"), ['vegetarian']);
      expect(said('Ich bin Veganerin'), ['vegan']);
      expect(said('je suis végétarienne'), ['vegetarian']);
      expect(said('я вегетаріанка'), ['vegetarian']);
      expect(said('У мене алергія на арахіс'), ['peanuts']);
      expect(said("J'ai une allergie aux arachides"), ['peanuts']);
      expect(said('Ich habe eine Laktoseintoleranz'), ['milk']);
      expect(tools.route('vegetarian dinner tonight'), isNull);
      expect(tools.route('я хочу веганську вечерю'), isNull);
      expect(normalizeAllergen('алергія на гриби'), isNot('fish')); // mushrooms, not fish
      expect(normalizeAllergen('алергія на рибу'), 'fish');
    });

    test('the router: "calories left" and "show recipe 2" skip the model, in four languages', () {
      String? status(String s) => (tools.route(s)?.card as NutritionCard?)?.title;
      expect(status('How many calories do I have left?'), 'Today');
      expect(status('Wie viele Kalorien habe ich noch übrig?'), 'Today');
      expect(status('Combien de calories me reste-t-il ?'), 'Today');
      expect(status('Скільки калорій у мене залишилось?'), 'Today');
      expect(status('What did I eat this week?'), 'Last 7 days');
      expect(tools.route('How many calories are in a banana?'), isNull);

      expect(tools.route('show me recipe 2'), isNull, reason: 'no list yet: the model asks which one');
      final list = (tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, broccoli, lentils, egg, oats'})
          .card! as RecipeListCard).recipes;
      expect((tools.route('show me recipe 2')!.card! as RecipeCard).title, list[1].title);
      expect((tools.route('zeig mir Rezept 3')!.card! as RecipeCard).title, list[2].title);
      expect((tools.route('montre-moi la recette 1')!.card! as RecipeCard).title, list[0].title);
      expect(confirmOf(tools.route('збережи рецепт 1')!).lines, [list[0].title]);
    });

    test('the last recipe list survives a restart; "recipe 2" with no list is not a title search', () {
      expect(tools.run('recipe', {'action': 'show', 'recipe': '2'}).forModel['error'], isNotNull);
      final list = (tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, broccoli, lentils, egg, oats'})
          .card! as RecipeListCard).recipes;
      final restarted = AgentTools(nutri, user, clock: () => now);
      expect((restarted.run('recipe', {'action': 'show', 'recipe': '2'}).card! as RecipeCard).title, list[1].title);
    });

    test('condition questions answer only from docs', () {
      final r = tools.run('condition_info', {'question': 'Can I eat sugar with type 2 diabetes?'});
      expect((r.card! as InfoCard).passages.first.text, contains('type 2 diabetes'));
      expect(r.forModel['note'], contains('not medical advice'));
      expect((tools.run('condition_info', {'question': 'zzz'}).forModel['passages'] as List), isEmpty);
    });
  });
}
