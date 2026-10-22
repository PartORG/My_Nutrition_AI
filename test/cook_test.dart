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

  test('units: steps in the user\'s system, real lines from the recipes', () {
    String metric(String s) => unitsFor(s, imperial: false);
    String imperial(String s) => unitsFor(s, imperial: true);
    expect(metric('Preheat oven to 375 degrees F.'), 'Preheat oven to 190°C.');
    expect(metric('Bake at 400°F for 15-20 minutes.'), 'Bake at 205°C for 15-20 minutes.');
    expect(metric('Preheat oven to 350 degrees.'), 'Preheat oven to 175°C.');
    expect(metric('Simmer at 180 degrees.'), 'Simmer at 180 degrees.', reason: 'under 250 it could be Celsius');
    expect(metric('bake at 350F for 45 minutes'), 'bake at 175°C for 45 minutes');
    expect(metric('PREHEAT oven to 375ºF (190ºC).'), 'PREHEAT oven to 190ºC.', reason: 'the step\'s own figure');
    expect(metric('deep-frier to 350 degrees F (175 degrees C).'), 'deep-frier to 175 degrees C.');
    expect(metric('Pour into a greased 9 inch square baking pan.'), 'Pour into a greased 23 cm square baking pan.');
    expect(metric('In a 10-inch skillet'), 'In a 25 cm skillet');
    expect(metric('Coat a 13 x 9" baking dish'), 'Coat a 33 x 23 cm baking dish');
    expect(metric('a greased 9x13 inch pan'), 'a greased 23 x 33 cm pan');
    expect(metric('cut into 1/2 inch slices'), 'cut into 1.5 cm slices');
    expect(metric('Combine 1/3 cup brown sugar'), 'Combine 80 ml brown sugar');
    expect(metric('remove roughly 2 cups of the potatoes'), 'remove roughly 480 ml of the potatoes');
    expect(metric('CHOP 4 ounces (1 bar) chocolate'), 'CHOP 115 g (1 bar) chocolate');
    expect(metric('1 (8 oz) package cream cheese'), '1 (225 g) package cream cheese');
    expect(metric('Makes about 2 1/2 pounds.'), 'Makes about 1.1 kg.');
    expect(metric('Butter 1 1/2 quart souffle dish'), 'Butter 1.4 L souffle dish');
    expect(metric('six 1/2 cup (4 fl oz) ramekins'), 'six 120 ml ramekins', reason: 'not "120 ml (120 ml)"');
    expect(metric('Add 2 tbsp butter and 1½ cups milk'), 'Add 2 tbsp butter and 360 ml milk');
    expect(metric('Heat oven to 325°F/160°C, and grease a dish.'), 'Heat oven to 160°C, and grease a dish.');
    expect(metric('Place 2-1/2 cups lettuce mixture'), 'Place 600 ml lettuce mixture', reason: 'US "2-1/2" is 2½');
    expect(metric('Grease a 13x9-inch (3-quart) glass baking dish'), 'Grease a 33 x 23 cm (2.8 L) glass baking dish');
    expect(metric('1 (15-ounce) can beans'), '1 (425 g) can beans');
    expect(metric('Makes 3 - 9" pizzas.'), 'Makes 3 - 23 cm pizzas.', reason: 'three of them, not 3 to 9 inches');
    expect(imperial('Reduce the oven to 160C/140C Fan/Gas 3.'), 'Reduce the oven to 320°F/285°F Fan/Gas 3.');
    expect(imperial('Add 3/4°C Parmigiano'), 'Add 3/4°C Parmigiano', reason: 'a cup written as C, not a temperature');
    expect(imperial('2°C Fontina grated'), '2°C Fontina grated');
    expect(metric('Bake at 180°C in a 20cm tin.'), 'Bake at 180°C in a 20cm tin.', reason: 'already metric');
    expect(imperial('Bake at 180°C for 50 minutes.'), 'Bake at 355°F for 50 minutes.');
    expect(imperial('Grease a 20cm pie dish.'), 'Grease a 8 in pie dish.');
    expect(imperial('Melt 125g of the butter'), 'Melt 4 1/2 oz of the butter');
    expect(imperial('using 500ml of water'), 'using 2 cups of water');
    expect(imperial('total fat 0g, 3g net carbs'), 'total fat 0g, 3g net carbs', reason: 'small amounts stay');
    expect(imperial('Preheat oven to 350 degrees F.'), 'Preheat oven to 350 degrees F.', reason: 'already imperial');
    expect(imperial('PREHEAT oven to 375ºF (190ºC).'), 'PREHEAT oven to 375ºF.');
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
