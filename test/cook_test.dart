import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/cook.dart';
import 'package:myfoodmind/data/plan.dart' show Aisle, aisleOf;

void main() {
  test('steps: numbered lines, without numbers and "Directions:"', () {
    expect(recipeSteps('1. Directions:\n2. Preheat oven to 400.\n3. Bake 11-14 minutes.'),
        ['Preheat oven to 400.', 'Bake 11-14 minutes.']);
    // One paragraph: two sentences to a step.
    expect(recipeSteps('Boil water. Add pasta. Cook 9 minutes. Drain. Serve.'),
        ['Boil water. Add pasta.', 'Cook 9 minutes. Drain.', 'Serve.']);
    expect(recipeSteps('Mix everything.'), ['Mix everything.']);
  });

  test('timers: minutes, hours, ranges take the longer end; none without a time', () {
    expect(stepTimer('Simmer 20 minutes, stirring.'), const Duration(minutes: 20));
    expect(stepTimer('Bake 11-14 minutes until set.'), const Duration(minutes: 14));
    expect(stepTimer('Chill for 2 hours.'), const Duration(hours: 2));
    expect(stepTimer('Preheat oven to 400.'), isNull);
    expect(stepTimer('Marinate 24 hours.'), isNull, reason: 'over 12 h is not a kitchen timer');
  });

  test('a step lists the ingredients it names', () {
    const ingredients = [
      (name: 'Red lentils', english: 'Lentils, raw', grams: 125.0),
      (name: 'Tomatoes', english: 'Tomatoes, red, ripe, raw', grams: 200.0),
      (name: 'Spinach', english: 'Spinach, raw', grams: 100.0),
    ];
    expect(stepIngredients('Add the lentils and tomatoes, bring to a boil.', ingredients).map((i) => i.name),
        ['Red lentils', 'Tomatoes']);
    expect(stepIngredients('Stir in the spinach.', ingredients).single.name, 'Spinach');
  });

  test('aisles: first match wins, so broth is pantry before chicken is meat', () {
    expect(aisleOf('Chicken broth'), Aisle.pantry);
    expect(aisleOf('Chicken, breast, raw'), Aisle.meatFish);
    expect(aisleOf('Spinach, raw'), Aisle.produce);
    expect(aisleOf('Cheese, feta'), Aisle.dairyEggs);
    expect(aisleOf('Eggplant, raw'), Aisle.produce, reason: 'not an egg');
    expect(aisleOf('Peanut butter'), Aisle.pantry);
    expect(aisleOf('Salt, table'), Aisle.spices);
    expect(aisleOf('Помідори'), Aisle.produce);
    expect(aisleOf('Something odd'), Aisle.other);
  });
}
