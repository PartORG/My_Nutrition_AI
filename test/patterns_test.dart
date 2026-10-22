import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/journal.dart';
import 'package:myfoodmind/data/patterns.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late Database user;
  final now = DateTime(2026, 10, 29, 12); // a Thursday; the window is 1–28 October
  const goals = {'kcal': 2000.0, 'iron_mg': 18.0, 'sodium_mg': 2000.0};

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_patterns_');
    user = openUserDb('${tmp.path}/user.db');
  });
  tearDown(() {
    user.close();
    tmp.deleteSync(recursive: true);
  });

  void meal(DateTime at, String type, String food, double kcal, {double? iron = 2}) => user.execute(
      'INSERT INTO meal_log (eaten_at, meal_type, description, grams, kcal, protein_g, fat_g, carbs_g, iron_mg) '
      'VALUES (?, ?, ?, 100, ?, 10, 10, 10, ?)', [at.millisecondsSinceEpoch, type, food, kcal, iron]);
  Map<String, Pattern> byKind(List<Pattern> l) => {for (final p in l) p.kind: p};

  test('a week of logs at least; the window starts at the first log', () {
    for (var d = 24; d <= 28; d++) {
      meal(DateTime(2026, 10, d, 13), 'lunch', 'soup', 900);
      meal(DateTime(2026, 10, d, 19), 'dinner', 'pasta', 900);
    }
    expect(findPatterns(user, now: now, goals: goals), isEmpty, reason: 'five days');
  });

  test('skipped breakfast, late dinners, weekends, a recurring gap, logging gaps; symptoms with Medium only', () {
    // 18 whole days of lunch and dinner, never breakfast; dinner at 21:30 Monday to Wednesday; weekends twice
    // the kcal. 10 days have nothing.
    for (var d = 1; d <= 28; d++) {
      final day = DateTime(2026, 10, d);
      if (d % 3 == 0 && d < 30) continue; // 3, 6, … 27: 9 days off
      if (d == 28) continue; // and one more: 18 whole days
      final weekend = day.weekday >= DateTime.saturday;
      meal(DateTime(2026, 10, d, 13), 'lunch', 'soup', weekend ? 1400 : 700);
      meal(DateTime(2026, 10, d, day.weekday <= DateTime.wednesday ? 21 : 19, 30), 'dinner', 'pasta',
          weekend ? 1400 : 700);
    }
    // Milk, then bloating within the hour: 5 times of 6.
    for (final d in [2, 4, 5, 7, 8, 10]) {
      meal(DateTime(2026, 10, d, 16), 'snack', 'milk, whole', 120, iron: null);
      if (d != 10) logSymptom(user, 'Bloating', 2, at: DateTime(2026, 10, d, 17));
    }
    final found = findPatterns(user, now: now, goals: goals);
    final k = byKind(found);
    expect(k.keys, containsAll(['logging', 'skipped', 'late', 'weekend', 'gap']));
    expect(patternSentence(k['logging']!), 'whole days logged: 18 of the last 28 (the other patterns count only those)');
    expect(patternSentence(k['skipped']!), 'breakfast skipped on 18 of 18 days');
    expect(k['late']!.args['days'], 18);
    expect(k['weekend']!.args['change'], inInclusiveRange(95, 100), reason: 'twice the kcal, give or take the milk');
    expect(patternSentence(k['gap']!), 'iron under 80 % of the goal on 12 of 12 days',
        reason: 'only the days whose every meal knows its iron (the milk days do not)');
    expect(k.containsKey('symptom'), isFalse, reason: 'Medium only');
    expect(found.map((p) => p.strength), orderedEquals([...found.map((p) => p.strength)]..sort((a, b) => b.compareTo(a))));

    final s = byKind(findPatterns(user, now: now, goals: goals, symptoms: true))['symptom']!;
    expect(patternSentence(s), 'bloating logged within 6 h after milk, whole 5 of 6 times (counts only, not a cause)');
  });

  test('the context line: the 3 strongest, once a day, by tier', () {
    for (var d = 1; d <= 28; d++) {
      meal(DateTime(2026, 10, d, 13), 'lunch', 'soup', 800);
      meal(DateTime(2026, 10, d, 22), 'dinner', 'pasta', 800);
    }
    expect(patternsLine(user, now: now, goals: goals, basic: false, medium: false), isNull, reason: 'Free');
    final line = patternsLine(user, now: now, goals: goals, basic: true, medium: false)!;
    expect(line, startsWith('Patterns (last 4 weeks, from the logs): '));
    expect(line.split('; ').length, 3);
    meal(DateTime(2026, 10, 29, 8), 'breakfast', 'oats', 300);
    expect(patternsLine(user, now: now, goals: goals, basic: true, medium: false), line, reason: 'kept for the day');
  });
}
