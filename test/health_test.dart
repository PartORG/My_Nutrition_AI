import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/data/conditions.dart';
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/journal.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/report.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqlite3/sqlite3.dart';

import 'memory_test.dart' show fakeEmbed;

/// M5: conditions, journal, doctor report.
void main() {
  late Directory tmp;
  late Database nutri, user;
  late AgentTools tools;
  final now = DateTime(2026, 10, 5, 12);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_health_');
    nutri = openNutriDb('test/nutri_test.db');
    user = openUserDb('${tmp.path}/user.db');
    tools = AgentTools(nutri, user, clock: () => now);
  });
  tearDown(() {
    nutri.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  Condition named(String name) => allConditions(nutri).firstWhere((c) => c.name == name);
  Set<int> foodsOf(int recipeId) =>
      {for (final r in nutri.select('SELECT food_id FROM recipe_ingredients WHERE recipe_id = ?', [recipeId])) r['food_id'] as int};

  // The M5 gate: whatever is asked, no suggested recipe contains a food the
  // profile's condition says to avoid.
  test('no forbidden ingredient for a given condition', () {
    final queries = [
      for (final r in nutri.select('SELECT title, tags FROM recipes')) ...[r['title'] as String, r['tags'] as String],
      for (final r in nutri.select('SELECT name FROM foods')) r['name'] as String,
      'dinner', 'breakfast', 'quick lunch', 'high protein', 'something with fish',
    ];
    var blockedSomething = false;
    for (final c in allConditions(nutri)) {
      user.execute('DELETE FROM user_conditions');
      setCondition(user, c, true, now: now);
      final avoid = avoidedFoods(nutri, user).keys.toSet();
      for (final q in queries) {
        for (final args in [{'query': q}, {'query': 'dinner', 'ingredients': q}]) {
          final card = tools.run('search_recipes', args).card;
          for (final r in card is RecipeListCard ? card.recipes : const <RecipeSummary>[]) {
            expect(foodsOf(r.id).intersection(avoid), isEmpty, reason: '${c.name}: "$q" suggested ${r.title}');
          }
        }
      }
      // Not vacuous: without the condition, the same searches do find those recipes.
      if (avoid.isNotEmpty) {
        user.execute('DELETE FROM user_conditions');
        final found = {
          for (final q in queries)
            for (final r in (tools.run('search_recipes', {'query': q}).card as RecipeListCard?)?.recipes ?? const [])
              if (foodsOf(r.id).intersection(avoid).isNotEmpty) r.id
        };
        blockedSomething |= found.isNotEmpty;
      }
    }
    expect(blockedSomething, isTrue);
  });

  test('a recipe opened by name names what to avoid, once per food', () {
    setCondition(user, named('hypertension'), true, now: now); // dummy: soy sauce, feta
    user.execute("INSERT INTO user_allergens VALUES ('soy', 0)");
    final stirFry = tools.run('show_recipe', {'recipe': 'chicken broccoli stir-fry'});
    final cautions = (stirFry.card! as RecipeCard).cautions;
    expect(cautions, [(food: 'soy sauce', allergen: 'soy', condition: 'hypertension')]);
    expect(stirFry.forModel['caution'], contains('soy sauce'));
    expect((tools.run('show_recipe', {'recipe': 'lentil soup'}).card! as RecipeCard).cautions, isEmpty);
  });

  test('condition limits only tighten targets, even manual ones', () {
    saveBody(user, (sex: Sex.female, birthYear: 1980, heightCm: 165, weightKg: 62,
        activity: Activity.light, goal: Goal.maintain, imperial: false), now: now);
    final before = currentTargets(user, nutri: nutri, now: now).values;
    expect(before['sugar_g'], greaterThan(25));

    setCondition(user, named('diabetes_t2'), true, now: now); // dummy: sugar 25, carbs 200
    var t = currentTargets(user, nutri: nutri, now: now);
    expect(t.values['sugar_g'], 25);
    expect(t.values['carbs_g'], 200);
    expect(t.limited, {'sugar_g': 'diabetes_t2', 'carbs_g': 'diabetes_t2'});
    expect(t.values['kcal'], before['kcal']); // untouched

    setOverride(user, 'sugar_g', 50); // a manual target can't loosen a limit…
    expect(currentTargets(user, nutri: nutri, now: now).values['sugar_g'], 25);
    setOverride(user, 'sugar_g', 15); // …but can be stricter
    t = currentTargets(user, nutri: nutri, now: now);
    expect(t.values['sugar_g'], 15);
    expect(t.limited.containsKey('sugar_g'), isFalse);

    setCondition(user, named('diabetes_t2'), false, now: now);
    expect(currentTargets(user, nutri: nutri, now: now).values['carbs_g'], before['carbs_g']);
  });

  test('no goals set: the condition limits are the targets', () {
    setCondition(user, named('hypertension'), true, now: now);
    expect(currentTargets(user, nutri: nutri, now: now).values, {'sodium_mg': 1500});
  });

  test('the AI context names the conditions and foods to avoid', () {
    final vectors = openVectorsDb('${tmp.path}/vectors.db');
    addTearDown(vectors.close);
    setCondition(user, named('hypertension'), true, now: now);
    final context = Memory(user, vectors, fakeEmbed, nutri: nutri, clock: () => now).context();
    expect(context, contains('Conditions: hypertension'));
    expect(context, contains('feta cheese, soy sauce'));
  });

  group('report', () {
    setUp(() {
      user.execute(
          "INSERT INTO meal_log (eaten_at, meal_type, description, grams, kcal, protein_g, fat_g, carbs_g, sugar_g) "
          "VALUES (?, 'lunch', 'soup, \"homemade\"', 300, 250.123, 10, 5, 30, 4)",
          [now.subtract(const Duration(days: 2)).millisecondsSinceEpoch]);
      logReading(user, 'blood_pressure', 128, 'mmHg', value2: 82, at: now.subtract(const Duration(days: 1)));
      logReading(user, 'glucose', 5.6, 'mmol/L', at: now.subtract(const Duration(hours: 3)));
      logSymptom(user, '=HYPERLINK("x")', 2, at: now.subtract(const Duration(hours: 1)));
      logSymptom(user, 'too old', 1, at: now.subtract(const Duration(days: 40)));
    });

    test('CSV: every record in the range, oldest first, safe for spreadsheets', () {
      final lines = reportCsv(user, now: now, days: 30).split('\r\n');
      expect(lines.first, startsWith('date,time,record,type,item,value,value2,unit,grams,kcal,'));
      expect(lines.length, 5); // header + meal + 2 readings + 1 symptom; the 40-day-old one is out
      final cols = lines.first.split(',').length;
      expect(lines[1], startsWith('2026-10-03,12:00,meal,lunch,"soup, ""homemade""",,,,300,250.12,'));
      expect(lines[2], '2026-10-04,12:00,reading,blood_pressure,,128,82,mmHg${',' * (cols - 8)}');
      expect(lines[3], contains('reading,glucose,,5.6,,mmol/L'));
      // A typed formula is quoted text, never a live formula.
      expect(lines[4], contains(',symptom,,"\'=hyperlink(""x"")",2,,1-5'));
    });

    test('PDF builds with the embedded font', () async {
      setCondition(user, named('diabetes_t2'), true, now: now);
      final l = lookupAppLocalizations(const Locale('en'));
      pw.Font font(String f) => pw.Font.ttf(File('assets/fonts/$f').readAsBytesSync().buffer.asByteData());
      final pdf = await reportPdf(user, nutri,
          name: 'Анна', // Cyrillic needs the embedded font
          now: now,
          days: 30,
          l: l,
          regular: font('NotoSans-Regular.ttf'),
          bold: font('NotoSans-Bold.ttf'),
          conditionName: (c) => c,
          nutrientNames: {for (final n in nutrients) n: n});
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      expect(pdf.length, greaterThan(1000));
    });
  });
}
