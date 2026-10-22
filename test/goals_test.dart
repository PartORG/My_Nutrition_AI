import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/diary.dart' show activeKcalOn, storeActiveKcal, trendPerWeek, weightTrend;
import 'package:myfoodmind/agent/agent_tools.dart' show AgentTools, micronutrients, nutrients;
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/reminders.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/ui/nutrients.dart' show nutrientGroups;

void main() {
  final now = DateTime(2026, 10, 4);

  Body body({Sex sex = Sex.male, int age = 30, int? month, double h = 180, double w = 80,
          Activity a = Activity.moderate, Goal g = Goal.maintain}) =>
      (sex: sex, birthYear: now.year - age, birthMonth: month, heightCm: h, weightKg: w, activity: a, goal: g,
          imperial: false);

  group('reference values (worked by hand from the formulas)', () {
    test('man, 30 y, 180 cm, 80 kg, moderate, maintain', () {
      // BMR = 10·80 + 6.25·180 − 5·30 + 5 = 1780; × 1.55 = 2759
      final t = computeTargets(body(), now: now)!;
      expect(t['kcal'], closeTo(2759, 0.01));
      expect(t['protein_g'], closeTo(96, 0.01)); // 1.2 g/kg
      expect(t['fat_g'], closeTo(91.97, 0.01)); // 30% of kcal / 9
      expect(t['carbs_g'], closeTo(386.825, 0.01)); // (2759 − 384 − 827.7) / 4 = 1547.3 / 4
      expect(t['fiber_g'], closeTo(38.63, 0.01)); // 14 g / 1000 kcal
      expect(t['sugar_g'], closeTo(68.98, 0.01)); // 10% of kcal / 4
      expect(t['sodium_mg'], 2000);
    });

    test('woman, 25 y, 165 cm, 60 kg, light, lose 15%', () {
      // BMR = 600 + 1031.25 − 125 − 161 = 1345.25; × 1.375 × 0.85 = 1572.26
      expect(computeTargets(body(sex: Sex.female, age: 25, h: 165, w: 60, a: Activity.light, g: Goal.lose),
          now: now)!['kcal'], closeTo(1572.26, 0.01));
    });

    test('a "lose" goal never goes under the floor', () {
      // BMR = 450 + 937.5 − 350 − 161 = 876.5; × 1.2 × 0.85 = 894 → floor 1200
      expect(computeTargets(body(sex: Sex.female, age: 70, h: 150, w: 45, a: Activity.sedentary, g: Goal.lose),
          now: now)!['kcal'], 1200);
    });

    test('"other" uses the midpoint of the male and female BMR', () {
      final m = computeTargets(body(a: Activity.sedentary), now: now)!['kcal']!;
      final f = computeTargets(body(sex: Sex.female, a: Activity.sedentary), now: now)!['kcal']!;
      expect(computeTargets(body(sex: Sex.other, a: Activity.sedentary), now: now)!['kcal'], closeTo((m + f) / 2, 0.01));
    });

    test('under 18: no computed targets', () {
      expect(computeTargets(body(age: 17), now: now), isNull);
      expect(computeTargets(body(age: 18), now: now), isNotNull);
    });

    test('the birth month makes the 18 check exact; in the birth month the birthday counts as not yet', () {
      // now is 4 Oct 2026; born 2008 is 18 by the year alone.
      expect(ageOn(body(age: 18, month: 9), now), 18);
      expect(ageOn(body(age: 18, month: 10), now), 17, reason: 'birthday this month: maybe not yet');
      expect(ageOn(body(age: 18, month: 12), now), 17);
      expect(computeTargets(body(age: 18, month: 12), now: now), isNull, reason: 'born Dec 2008: still 17');
      expect(ageOn(body(age: 18), now), 18, reason: 'no month (before v13): the year alone');
    });

    test('underweight (BMI < 18.5): "lose" gives the maintain targets', () {
      final thin = body(h: 180, w: 55); // BMI 17.0
      expect(underweight(180, 55), isTrue);
      expect(underweight(180, 60), isFalse); // BMI 18.52
      expect(computeTargets((sex: thin.sex, birthYear: thin.birthYear, birthMonth: null, heightCm: 180, weightKg: 55,
              activity: thin.activity, goal: Goal.lose, imperial: false), now: now)!['kcal'],
          computeTargets(thin, now: now)!['kcal']);
      expect(computeTargets(body(g: Goal.lose), now: now)!['kcal'], closeTo(2759 * .85, .01), reason: 'BMI 24.7');
    });
  });

  group('storage', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('myfoodmind_goals_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('active calories are shown, never added to the kcal goal', () {
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(), now: now);
      expect(storeActiveKcal(user, now.add(const Duration(hours: 9)), 320.4), isTrue);
      expect(storeActiveKcal(user, now.add(const Duration(hours: 10)), 320.2), isFalse, reason: 'same rounded value');
      expect(activeKcalOn(user, now), 320);
      expect(activeKcalOn(user, now.add(const Duration(days: 1))), 0, reason: 'only the stored day');
      expect(currentTargets(user, nutri: null, now: now).values['kcal'], closeTo(2759, .01));
      user.close();
    });

    test('overrides beat computed values and can be removed', () {
      final user = openUserDb('${tmp.path}/user.db');
      expect(currentTargets(user, nutri: null, now: now).values, isEmpty);
      saveBody(user, body(), now: now);
      setOverride(user, 'kcal', 2200);
      final t = currentTargets(user, nutri: null, now: now);
      expect(t.values['kcal'], 2200);
      expect(t.values['protein_g'], closeTo(96, .01));
      expect(t.custom, {'kcal'});
      setOverride(user, 'kcal', null);
      expect(currentTargets(user, nutri: null, now: now).values['kcal'], closeTo(2759, .01));
      user.close();
    });

    test('under 18 only manual targets apply', () {
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(age: 15), now: now);
      expect(currentTargets(user, nutri: null, now: now).values, isEmpty);
      setOverride(user, 'kcal', 2000);
      expect(currentTargets(user, nutri: null, now: now).values, {'kcal': 2000});
      user.close();
    });

    test('the birth month is saved and read back; a v12 row has none', () {
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(month: 7), now: now);
      expect(loadBody(user)!.birthMonth, 7);
      user.execute('UPDATE body SET birth_month = NULL');
      expect(loadBody(user)!.birthMonth, isNull);
      user.close();
    });

    test('a newer weight reading replaces the onboarding weight (lb converted)', () {
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(w: 80), now: now);
      user.execute("INSERT INTO readings (logged_at, kind, value, unit) VALUES (?, 'weight', 165, 'lb')",
          [now.add(const Duration(days: 1)).millisecondsSinceEpoch]);
      expect(loadBody(user)!.weightKg, closeTo(74.84, .01));
      user.close();
    });
  });

  group('reference intakes (health.db, NASEM)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('myfoodmind_ref_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('RDA, else AI, by sex, age and life stage; adults only; "other" the mean', () {
      final nutri = openNutriDb('test/nutri_test.db');
      Map<String, double> goals(Sex sex, {int age = 30, String stage = ''}) =>
          referenceGoals(nutri, body(sex: sex, age: age), stage, now: now);
      expect(goals(Sex.female)['iron_mg'], 18);
      expect(goals(Sex.male)['iron_mg'], 8);
      expect(goals(Sex.female, age: 60)['iron_mg'], 8);
      expect(goals(Sex.other)['iron_mg'], 13);
      expect(goals(Sex.female, stage: 'pregnancy')['iron_mg'], 27);
      expect(goals(Sex.female, age: 60, stage: 'pregnancy')['iron_mg'], 8, reason: 'no rows at 60: plain values');
      expect(goals(Sex.male)['potassium_mg'], 3400, reason: 'AI when there is no RDA');
      expect(goals(Sex.male, age: 75)['vitamin_d_ug'], 20);
      expect(goals(Sex.male, age: 17), isEmpty, reason: 'under 18 targets are manual');
      nutri.close();
    });

    test('upper limits: food-only ones, the lower for "other"; vitamin A counts retinol only', () {
      final nutri = openNutriDb('test/nutri_test.db');
      final ul = upperLimits(nutri, body(), '', now: now);
      expect(ul, containsPair('iron_mg', 45));
      expect(ul, containsPair('sodium_mg', 2300));
      expect(ul.containsKey('magnesium_mg'), isFalse, reason: 'its UL is for supplements');
      expect(upperLimits(nutri, body(age: 15), '', now: now), isEmpty, reason: 'the test rows are adult only');
      // 500 g of carrots: lots of RAE, nearly all of it beta-carotene.
      expect(overLimits({'vitamin_a_ug': 4200, 'beta_carotene_ug': 41000}, ul), isEmpty);
      expect(overLimits({'vitamin_a_ug': 9000, 'beta_carotene_ug': 100}, ul).single.$1, 'vitamin_a_ug', reason: 'liver');
      nutri.close();
    });

    test('current targets: the formula keeps the macros, health.db adds the rest; any of it can be overridden', () {
      final nutri = openNutriDb('test/nutri_test.db');
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(sex: Sex.female, w: 60), now: now);
      var t = currentTargets(user, nutri: nutri, now: now).values;
      expect(t['protein_g'], closeTo(72, .01), reason: '1.2 g/kg, not the RDA of 46 g');
      expect(t['iron_mg'], 18);
      setLifeStage(user, 'pregnancy');
      expect(currentTargets(user, nutri: nutri, now: now).values['iron_mg'], 27);
      setOverride(user, 'iron_mg', 20);
      t = currentTargets(user, nutri: nutri, now: now).values;
      expect(t['iron_mg'], 20);
      // Sodium's ceiling: the target (2000) is under the UL (2300).
      expect(dayLimits(user, nutri, now: now)['sodium_mg'], 2000);
      user.close();
      nutri.close();
    });

    test('Low (after the usual dinner time) and Over (always)', () {
      final nutri = openNutriDb('test/nutri_test.db');
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(sex: Sex.female, w: 60), now: now);
      final morning = DateTime(2026, 10, 4, 9);
      final tools = AgentTools(nutri, user, clock: () => morning);
      final none = lowAndOver(user, nutri, now: morning);
      expect([...none.low, ...none.over], isEmpty, reason: 'nothing logged');
      tools.quickAdd('Ramen', {'kcal': 600, 'protein_g': 20, 'sodium_mg': 3000}, 'lunch');
      tools.logFood(tools.searchFood('egg').firstWhere((f) => f.kind == 'food'), 100, 'breakfast');
      var r = lowAndOver(user, nutri, now: morning);
      expect(r.low, isEmpty, reason: 'before dinner the day is not over');
      expect([for (final o in r.over) o.$1], ['sodium_mg']);
      final evening = DateTime(2026, 10, 4, 21);
      r = lowAndOver(user, nutri, now: evening);
      expect(r.low.map((e) => e.$1), contains('protein_g'));
      expect(r.low.map((e) => e.$1), isNot(contains('iron_mg')), reason: 'the ramen does not know its iron: "at least"');
      saveReminder(user, (slot: 'dinner', enabled: true, hour: 22, minute: 0));
      expect(lowAndOver(user, nutri, now: evening).low, isEmpty, reason: 'dinner is later for this user');
      user.close();
      nutri.close();
    });
  });

  test('the nutrient lists match db/catalog/nutrients.tsv', () {
    final keys = [
      for (final line in File('db/catalog/nutrients.tsv').readAsLinesSync())
        if (!line.startsWith('#') && !line.startsWith('key\t')) line.split('\t').first
    ];
    expect({...nutrients, ...micronutrients}, keys.toSet());
    expect(micronutrients, [for (final k in keys) if (!nutrients.contains(k)) k], reason: 'same order');
    expect([for (final g in nutrientGroups.values) ...g], keys, reason: "the screens' groups, in the file's order");
  });

  test('imperial conversions round-trip', () {
    expect(kgToLb(80), closeTo(176.37, .01));
    final fi = cmToFeetInches(180);
    expect(fi.feet, 5);
    expect(fi.inches, closeTo(10.87, .01));
    expect(feetInchesToCm(5, 10.87), closeTo(180, .02));
  });

  test('weight trend: smooths daily swings, follows a real change', () {
    final d0 = DateTime(2026, 9, 1);
    final readings = [
      for (var i = 0; i < 28; i++) (at: d0.add(Duration(days: i)), kg: 80.0 - i * 0.05 + (i.isEven ? .8 : -.8)),
    ];
    final t = weightTrend(readings);
    expect(t.first.trend, readings.first.kg, reason: 'starts at the first reading');
    // Swings of ±0.8 kg move the trend far less than the scale.
    final scaleSwing = (readings[11].kg - readings[10].kg).abs();
    final trendSwing = (t[11].trend - t[10].trend).abs();
    expect(trendSwing, lessThan(scaleSwing / 5));
    // It still follows the 0.35 kg/week loss underneath.
    expect(trendPerWeek(t.sublist(10)), closeTo(-.35, .15));
    expect(trendPerWeek(t.sublist(0, 3)), isNull, reason: 'under a week');
  });
}
