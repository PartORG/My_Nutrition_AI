import 'package:sqlite3/sqlite3.dart';

import '../agent/agent_tools.dart' show FoodChoice, Nutrients, nutrients;
import 'journal.dart';

typedef MealEntry = ({
  int id,
  DateTime at,
  String? type,
  String label,
  double? grams,
  double kcal,
  bool estimated,
  int? recipeId, // logged from a recipe: Today opens it again
});

/// Local-day window [start, end) for [day].
(int, int) _dayRange(DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  return (start.millisecondsSinceEpoch, DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch);
}

List<MealEntry> mealsOn(Database user, DateTime day) {
  final (from, to) = _dayRange(day);
  return [
    for (final r in user.select(
        'SELECT id, eaten_at, meal_type, description, grams, kcal, estimated, recipe_id FROM meal_log '
        'WHERE eaten_at >= ? AND eaten_at < ? ORDER BY eaten_at', [from, to]))
      (
        id: r['id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(r['eaten_at'] as int),
        type: r['meal_type'] as String?,
        label: r['description'] as String,
        grams: (r['grams'] as num?)?.toDouble(),
        kcal: (r['kcal'] as num).toDouble(),
        estimated: r['estimated'] == 1,
        recipeId: r['recipe_id'] as int?,
      )
  ];
}

Nutrients totalsOn(Database user, DateTime day) {
  final (from, to) = _dayRange(day);
  final r = user.select('SELECT ${[for (final n in nutrients) 'TOTAL($n) AS $n'].join(', ')} '
      'FROM meal_log WHERE eaten_at >= ? AND eaten_at < ?', [from, to]).single;
  return {for (final n in nutrients) n: (r[n] as num).toDouble()};
}

void deleteMeal(Database user, int id) => user.execute('DELETE FROM meal_log WHERE id = ?', [id]);

/// A new amount scales the logged nutrition (it is a per-gram snapshot); [type] moves it to another meal.
void updateMeal(Database user, int id, {double? grams, String? type}) {
  final old = user.select('SELECT grams FROM meal_log WHERE id = ?', [id]).single['grams'] as num?;
  if (grams != null && grams > 0 && old != null && old > 0) {
    final f = grams / old;
    user.execute('UPDATE meal_log SET grams = ?, ${[for (final n in nutrients) '$n = $n * $f'].join(', ')} '
        'WHERE id = ?', [grams, id]);
  }
  if (type != null) user.execute('UPDATE meal_log SET meal_type = ? WHERE id = ?', [type, id]);
}

/// What the user logs most in the last 30 days, then most recently: one tap to log again.
/// Values are from the latest log of each, per 100 g; the last amount is the serving.
List<FoodChoice> recentFoods(Database user, DateTime now, {int limit = 12}) => [
      for (final r in user.select(
          'SELECT description, grams, recipe_id, estimated, ${nutrients.join(', ')}, COUNT(*) AS n, '
          'MAX(eaten_at) AS last FROM meal_log WHERE eaten_at >= ? AND grams > 0 '
          'GROUP BY description ORDER BY n DESC, last DESC LIMIT ?',
          [now.subtract(const Duration(days: 30)).millisecondsSinceEpoch, limit]))
        (
          kind: r['recipe_id'] == null ? 'recent' : 'recipe',
          id: r['recipe_id'],
          label: r['description'] as String,
          servingG: (r['grams'] as num).toDouble(),
          per100: {for (final n in nutrients) n: ((r[n] as num?) ?? 0) * 100 / (r['grams'] as num)},
          estimated: r['estimated'] == 1,
        )
    ];

/// Meal types logged on [day], with their kcal: "Yesterday's breakfast · 420 kcal".
Map<String, double> mealTotalsOn(Database user, DateTime day) {
  final (from, to) = _dayRange(day);
  return {
    for (final r in user.select(
        'SELECT meal_type, TOTAL(kcal) AS kcal FROM meal_log WHERE eaten_at >= ? AND eaten_at < ? '
        'AND meal_type IS NOT NULL GROUP BY meal_type', [from, to]))
      r['meal_type'] as String: (r['kcal'] as num).toDouble()
  };
}

/// Logs [type] from [day] again at [at], same amounts. Returns the rows copied.
int repeatMeal(Database user, DateTime day, String type, DateTime at) {
  final (from, to) = _dayRange(day);
  user.execute(
      'INSERT INTO meal_log (eaten_at, meal_type, description, grams, ${nutrients.join(', ')}, estimated, recipe_id) '
      'SELECT ?, meal_type, description, grams, ${nutrients.join(', ')}, estimated, recipe_id FROM meal_log '
      'WHERE eaten_at >= ? AND eaten_at < ? AND meal_type = ? ORDER BY eaten_at',
      [at.millisecondsSinceEpoch, from, to, type]);
  return user.updatedRows;
}

// ---- Basic dashboard (M4) ---------------------------------------------------

typedef DayTotals = ({DateTime day, Nutrients totals, int entries});

/// One row per local day for the [days] days ending [last] (inclusive),
/// oldest first; days without logs have zeros.
List<DayTotals> dailyTotals(Database user, DateTime last, int days) {
  final first = DateTime(last.year, last.month, last.day - days + 1);
  final rows = user.select(
      "SELECT date(eaten_at / 1000, 'unixepoch', 'localtime') AS d, COUNT(*) AS n, "
      '${[for (final n in nutrients) 'TOTAL($n) AS $n'].join(', ')} '
      'FROM meal_log WHERE eaten_at >= ? AND eaten_at < ? GROUP BY d',
      [first.millisecondsSinceEpoch, DateTime(last.year, last.month, last.day + 1).millisecondsSinceEpoch]);
  final byDay = {for (final r in rows) r['d'] as String: r};
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return [
    for (var i = 0; i < days; i++)
      () {
        final day = DateTime(first.year, first.month, first.day + i);
        final r = byDay[key(day)];
        return (
          day: day,
          totals: {for (final n in nutrients) n: ((r?[n] as num?) ?? 0).toDouble()},
          entries: (r?['n'] as int?) ?? 0,
        );
      }()
  ];
}

/// Consecutive days with at least one log, ending today — or yesterday, so
/// the streak isn't "lost" in the morning before breakfast is logged.
int loggingStreak(Database user, DateTime today) {
  final days = dailyTotals(user, today, 400);
  var i = days.length - 1;
  if (days[i].entries == 0) i--;
  var streak = 0;
  for (; i >= 0 && days[i].entries > 0; i--) {
    streak++;
  }
  return streak;
}

/// Weight readings since [from], in kg, oldest first.
List<({DateTime at, double kg})> weightsSince(Database user, DateTime from) => [
      for (final r in user.select(
          "SELECT logged_at, value, unit FROM readings WHERE kind = 'weight' AND logged_at >= ? ORDER BY logged_at",
          [from.millisecondsSinceEpoch]))
        (
          at: DateTime.fromMillisecondsSinceEpoch(r['logged_at'] as int),
          kg: (r['value'] as num).toDouble() * (r['unit'] == 'lb' ? 0.45359237 : 1),
        )
    ];

/// Free: anyone can log their weight (goals use it); the trend is Basic.
void logWeight(Database user, double value, {required bool imperial, required DateTime at}) =>
    logReading(user, 'weight', value, imperial ? 'lb' : 'kg', at: at);
