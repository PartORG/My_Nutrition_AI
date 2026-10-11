import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/billing/billing.dart';
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

  test('weightNow: latest weight and its change over the window', () {
    expect(weightNow(user, DateTime(2026, 9, 1)), isNull);
    logWeight(user, 80, imperial: false, at: DateTime(2026, 8, 1)); // before the window
    expect(weightNow(user, DateTime(2026, 9, 1)), (kg: 80.0, change: null));
    logWeight(user, 79, imperial: false, at: DateTime(2026, 9, 10));
    logWeight(user, 77.5, imperial: false, at: DateTime(2026, 10, 1));
    expect(weightNow(user, DateTime(2026, 9, 1)), (kg: 77.5, change: -1.5));
  });

  test('year: monthly averages over logged days, best streak, most eaten', () {
    final today = DateTime(2026, 10, 4, 12);
    meal(DateTime(2026, 9, 29, 8), 1000);
    meal(DateTime(2026, 9, 30, 8), 2000); // September: two logged days, avg 1500
    meal(DateTime(2026, 10, 2, 8), 1200);
    meal(DateTime(2026, 10, 3, 8), 1800);
    meal(DateTime(2026, 10, 4, 8), 600);
    meal(DateTime(2026, 10, 4, 13), 600);
    final series = dailyTotals(user, today, 10); // 25 Sep – 4 Oct
    final months = monthlyAverages(series);
    expect([for (final m in months) (m.month, m.logged, m.avg['kcal'])],
        [(DateTime(2026, 9), 2, 1500), (DateTime(2026, 10), 3, 1400)]);
    expect(bestStreak(series), 3);
    expect(topFoods(user, DateTime(2026, 9, 1)).single, (label: 'x', times: 6));
  });

  test('history window per tier', () {
    expect([for (final t in Tier.values) t.historyDays], [30, 90, 240, 365]);
  });
}
