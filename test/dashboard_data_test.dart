import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/diary.dart';
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late Database user;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_dash_');
    user = openUserDb('${tmp.path}/user.db');
  });
  tearDown(() {
    user.close();
    tmp.deleteSync(recursive: true);
  });

  void meal(DateTime at, double kcal) => user.execute(
      'INSERT INTO meal_log (eaten_at, description, kcal, protein_g, fat_g, carbs_g) VALUES (?, ?, ?, 1, 1, 1)',
      [at.millisecondsSinceEpoch, 'x', kcal]);

  test('daily totals: one row per day, zeros for empty days, local day boundaries', () {
    final today = DateTime(2026, 10, 4, 12);
    meal(DateTime(2026, 10, 4, 0, 5), 300); // just after midnight: today
    meal(DateTime(2026, 10, 3, 23, 55), 200); // just before: yesterday
    meal(DateTime(2026, 10, 1, 8), 500);
    final week = dailyTotals(user, today, 7);
    expect(week.length, 7);
    expect(week.first.day, DateTime(2026, 9, 28));
    expect([for (final d in week) d.totals['kcal']], [0, 0, 0, 500, 0, 200, 300]);
    expect(week.last.entries, 1);
  });

  test('streak counts back from today, or from yesterday before the first log', () {
    final today = DateTime(2026, 10, 4, 9);
    expect(loggingStreak(user, today), 0);
    for (final d in [1, 2, 3]) {
      meal(DateTime(2026, 10, d, 8), 100);
    }
    expect(loggingStreak(user, today), 3, reason: 'nothing logged yet today: streak still alive');
    meal(DateTime(2026, 10, 4, 8), 100);
    expect(loggingStreak(user, today), 4);
    expect(loggingStreak(user, DateTime(2026, 10, 6, 9)), 0, reason: 'a whole missed day breaks it');
  });

  test('weight logging (free) feeds both the trend and the goals', () {
    final at = DateTime(2026, 10, 4, 7);
    saveBody(user, (sex: Sex.female, birthYear: 1990, heightCm: 165, weightKg: 70,
        activity: Activity.light, goal: Goal.lose, imperial: true), now: at.subtract(const Duration(days: 1)));
    logWeight(user, 150, imperial: true, at: at);
    expect(weightsSince(user, DateTime(2026, 9, 1)).single.kg, closeTo(68.04, .01));
    expect(loadBody(user)!.weightKg, closeTo(68.04, .01));
  });
}
