import 'package:sqlite3/sqlite3.dart';

import '../agent/agent_tools.dart' show Nutrients, nutrients;

typedef MealEntry = ({
  int id,
  DateTime at,
  String? type,
  String label,
  double? grams,
  double kcal,
  bool estimated,
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
        'SELECT id, eaten_at, meal_type, description, grams, kcal, estimated FROM meal_log '
        'WHERE eaten_at >= ? AND eaten_at < ? ORDER BY eaten_at', [from, to]))
      (
        id: r['id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(r['eaten_at'] as int),
        type: r['meal_type'] as String?,
        label: r['description'] as String,
        grams: (r['grams'] as num?)?.toDouble(),
        kcal: (r['kcal'] as num).toDouble(),
        estimated: r['estimated'] == 1,
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
void logWeight(Database user, double value, {required bool imperial, required DateTime at}) => user.execute(
    "INSERT INTO readings (logged_at, kind, value, unit) VALUES (?, 'weight', ?, ?)",
    [at.millisecondsSinceEpoch, value, imperial ? 'lb' : 'kg']);
