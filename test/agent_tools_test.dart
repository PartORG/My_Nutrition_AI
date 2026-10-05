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
    nutri = openNutriDb('assets/nutri.db');
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
      final list = (tools.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, rice, broccoli'})
          .card! as RecipeListCard).recipes;
      expect(list.length, 3);
      final second = list[1].title;
      expect((tools.run('show_recipe', {'recipe': '2'}).card! as RecipeCard).title, second);
      expect((tools.run('show_recipe', {'recipe': 'the first one'}).card! as RecipeCard).title,
          'Chicken broccoli stir-fry');
      final soup = tools.run('show_recipe', {'recipe': 'lentil soup'}).card! as RecipeCard;
      expect(soup.title, 'Lentil soup');
      expect(soup.ingredients.first, (name: 'lentils, cooked', grams: 400.0));
      final save = tools.run('save_recipe', {'recipe': 'that one'});
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

    test('unknown recipe is an error for the model, not a crash', () {
      expect(tools.run('show_recipe', {'recipe': 'unicorn pie'}).forModel['error'], isNotNull);
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
      expect(label('shakshuka'), 'shakshuka', reason: 'tie between the dish and the recipe: the dish');
      expect(label('2 eggs'), 'egg');
      // Splitting still happens when the phrase isn't one dish's name.
      expect(confirmOf(tools.run('log_meal', {'items': 'lasagna and banana'})).lines.length, 2);
      expect(confirmOf(tools.run('log_meal', {'items': 'chicken with rice'})).lines.length, 2);
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
    test('search covers dishes, recipes, foods and products', () {
      final kinds = {for (final f in tools.searchFood('pasta')) f.kind};
      expect(kinds, containsAll(['food', 'product']));
      final shak = tools.searchFood('shakshuka');
      expect(shak.first.kind, 'dish', reason: 'a prepared dish beats the recipe');
      expect(shak.map((f) => f.kind), contains('recipe'));
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
          confirmOf(tools.run('log_reading', {'kind': kind, 'value': value})).lines.single;
      expect(line('glucose', '140'), '140 mg/dL');
      expect(line('glucose', '6.1 mmol/L'), '6.1 mmol/L');
      expect(line('blood_pressure', '130 over 85'), '130/85 mmHg');
      expect(line('weight', '165 lbs'), '165 lb');
      expect(line('weight', '72,5 kg'), '72.5 kg');
      expect(tools.run('log_reading', {'kind': 'blood_pressure', 'value': '130'}).forModel['error'],
          isNotNull);
      final r = tools.run('log_reading', {'kind': 'blood_pressure', 'value': '118/76'});
      confirmOf(r).apply();
      final row = user.select('SELECT value, value2, unit FROM readings').single;
      expect([row['value'], row['value2'], row['unit']], [118.0, 76.0, 'mmHg']);
    });

    test('symptom and fact writes wait for ✓', () {
      final s = tools.run('log_symptom', {'symptom': 'Fatigue', 'severity': '4'});
      expect(confirmOf(s).lines.single, 'Fatigue · severity 4/5');
      final f = tools.run('remember_fact', {'fact': 'Has an air fryer'});
      expect(count('symptoms') + count('memory_facts'), 0);
      confirmOf(s).apply();
      confirmOf(f).apply();
      expect(count('symptoms') + count('memory_facts'), 2);
    });

    test('condition questions answer only from docs', () {
      final r = tools.run('condition_info', {'question': 'Can I eat sugar with type 2 diabetes?'});
      expect((r.card! as InfoCard).passages.first.text, contains('type 2 diabetes'));
      expect(r.forModel['note'], contains('not medical advice'));
      expect((tools.run('condition_info', {'question': 'zzz'}).forModel['passages'] as List), isEmpty);
    });
  });
}
