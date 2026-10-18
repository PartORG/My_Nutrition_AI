import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/data/health_sync.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/plan.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late Database nutri, user;
  late AgentTools tools;
  final day = DateTime(2026, 10, 5);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_plan_');
    nutri = openNutriDb('test/nutri_test.db');
    user = openUserDb('${tmp.path}/user.db');
    tools = AgentTools(nutri, user, clock: () => day);
  });
  tearDown(() {
    nutri.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  test('plan: meals tagged for the slot, no recipe twice, 1-2 stars never; swap picks another', () {
    tools.rate(4, 1); // overnight oats: never again
    final plan = planWeek(tools, day, days: 2, random: Random(1));
    // The test db has 2 breakfasts (one rated out), 1 lunch, 4 dinners.
    expect([for (final p in plan) (p.day.day, p.mealType)], [(5, 'breakfast'), (5, 'lunch'), (5, 'dinner'), (6, 'dinner')]);
    expect(plan.first.title, 'Shakshuka');
    expect(plan.map((p) => p.recipeId).toSet().length, plan.length);
    expect(plan.every((p) => p.kcal > 0), isTrue);

    final dinner = plan[2].recipeId;
    swapPlanned(tools, day, 'dinner', random: Random(2));
    final after = plannedMealsFor(tools, day, days: 2);
    expect(after[2].recipeId, isNot(dinner));
    expect(after.map((p) => p.recipeId).toSet().length, after.length);
  });

  test('meal ideas: different recipes tagged for the meal, rated-out ones never', () {
    tools.rate(4, 1); // overnight oats: never again
    final dinners = mealIdeas(tools, 'dinner', 700, random: Random(1));
    expect(dinners, hasLength(2));
    expect(dinners.map((r) => r.id).toSet(), hasLength(2));
    expect(mealIdeas(tools, 'breakfast', 500, random: Random(1)).map((r) => r.title), ['Shakshuka']);
    expect(mealShare('snack'), isNull);
  });

  test('shopping list: plan per serving, whole recipe adds up, ticks and typed items stay', () {
    tools.rate(4, 1); // so breakfast is Shakshuka
    planWeek(tools, day, days: 1, random: Random(1));
    expect(shoppingFromPlan(tools, day), greaterThan(3));
    final eggs = shoppingList(tools).firstWhere((i) => i.name == 'egg'); // Shakshuka: 200 g egg / 2 servings
    expect(eggs.grams, closeTo(100, 1));

    addRecipeToShopping(tools, 2); // the whole Shakshuka: 200 g more egg
    expect(shoppingList(tools).firstWhere((i) => i.name == 'egg').grams, closeTo(300, 1));

    addShoppingItem(tools, 'coffee beans');
    checkShoppingItem(tools, eggs.id, true);
    shoppingFromPlan(tools, day); // rebuilt: the ticked eggs and the typed coffee stay
    final names = shoppingList(tools).map((i) => i.name);
    expect(names, containsAll(['egg', 'coffee beans']));
    expect(shoppingList(tools).last.checked, isTrue, reason: 'ticked items sort last');
    clearCheckedShopping(tools);
    expect(shoppingList(tools).any((i) => i.checked), isFalse);
  });

  test('shopping names: aisle words stay, states go', () {
    expect(shoppingName('Bananas, raw'), 'Bananas');
    expect(shoppingName('Cheese, feta'), 'Cheese, feta');
    expect(shoppingName('Spices, pepper, black'), 'Spices, pepper');
    expect(shoppingName('lentils, cooked'), 'lentils');
  });

  test('health weights: new ones in, same minute or a glitch out; the latest sets the goal weight', () {
    final at = DateTime(2026, 10, 4, 7, 30);
    expect(importWeights(user, [(at: at, kg: 80.04), (at: at.add(const Duration(seconds: 20)), kg: 80.1),
        (at: at.add(const Duration(days: 1)), kg: 79.6), (at: at, kg: 3)]), 2);
    expect(importWeights(user, [(at: at.add(const Duration(days: 1)), kg: 79.6)]), 0, reason: 'already there');
    expect(user.select("SELECT value FROM readings WHERE kind = 'weight' ORDER BY logged_at").map((r) => r['value']),
        [80.0, 79.6]);
  });

  test('burnt calories: active ones, else the total beyond the resting burn so far (Google Fit)', () {
    final noon = DateTime(2026, 10, 18, 12);
    expect(burntKcal(active: 250, now: noon), 250, reason: 'no total: active only');
    expect(burntKcal(active: 0, total: 1200, now: noon), 0, reason: 'no goals, no resting burn known');
    // Half the day gone: 1800 / 2 = 900 kcal of the total was resting.
    expect(burntKcal(active: 0, total: 1200, basalPerDay: 1800, now: noon), closeTo(300, .01));
    expect(burntKcal(active: 400, total: 1200, basalPerDay: 1800, now: noon), 400, reason: 'active wins when larger');
    expect(burntKcal(active: 0, total: 500, basalPerDay: 1800, now: noon), 0, reason: 'never below zero');
  });

  test('ingredients and shopping list in the app language, English where nutri.db has no translation', () {
    tools.language = 'uk';
    final card = tools.showRecipeById(2).card! as RecipeCard; // Shakshuka
    expect(card.ingredients.map((i) => i.name), containsAll(['помідор', 'яйце', 'цибуля', 'feta cheese']));
    expect(card.translatedNames, isTrue);
    addRecipeToShopping(tools, 2);
    expect(shoppingList(tools).map((i) => i.name), containsAll(['яйце', 'olive oil']));
    tools.language = 'en';
    final en = tools.showRecipeById(2).card! as RecipeCard;
    expect(en.ingredients.map((i) => i.name), contains('egg'));
    expect(en.translatedNames, isFalse);
  });
}
