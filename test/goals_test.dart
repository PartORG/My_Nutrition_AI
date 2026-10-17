import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/diary.dart' show activeKcalOn, storeActiveKcal, trendPerWeek, weightTrend;
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/user_db.dart';

void main() {
  final now = DateTime(2026, 10, 4);

  Body body({Sex sex = Sex.male, int age = 30, double h = 180, double w = 80,
          Activity a = Activity.moderate, Goal g = Goal.maintain}) =>
      (sex: sex, birthYear: now.year - age, heightCm: h, weightKg: w, activity: a, goal: g, imperial: false);

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

    test('a newer weight reading replaces the onboarding weight (lb converted)', () {
      final user = openUserDb('${tmp.path}/user.db');
      saveBody(user, body(w: 80), now: now);
      user.execute("INSERT INTO readings (logged_at, kind, value, unit) VALUES (?, 'weight', 165, 'lb')",
          [now.add(const Duration(days: 1)).millisecondsSinceEpoch]);
      expect(loadBody(user)!.weightKg, closeTo(74.84, .01));
      user.close();
    });
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
