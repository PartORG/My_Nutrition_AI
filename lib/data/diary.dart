import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

import '../agent/agent_tools.dart' show FoodChoice, Nutrients, micronutrients, nutrients;
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

/// Micronutrients eaten on [day], from the meals that know them; [known] = how many of the
/// day's meals had values (the rest add nothing).
({Nutrients totals, int known, int meals}) microTotalsOn(Database user, DateTime day) {
  final (from, to) = _dayRange(day);
  final r = user.select(
      'SELECT COUNT(*) AS meals, COUNT(iron_mg) AS known, ${[for (final m in micronutrients) 'TOTAL($m) AS $m'].join(', ')} '
      'FROM meal_log WHERE eaten_at >= ? AND eaten_at < ?', [from, to]).single;
  return (
    totals: {for (final m in micronutrients) m: (r[m] as num).toDouble()},
    known: r['known'] as int,
    meals: r['meals'] as int,
  );
}

void deleteMeal(Database user, int id) => user.execute('DELETE FROM meal_log WHERE id = ?', [id]);

/// The newest meal_log id: taken before a log, it lets Undo remove exactly what that log added.
int lastMealId(Database user) => user.select('SELECT MAX(id) AS id FROM meal_log').single['id'] as int? ?? 0;

/// Undo: deletes the meals logged after [lastMealId] returned [id].
// shortcut: assumes nothing else is logged between the log and its Undo (a snackbar's few seconds).
void undoMealsAfter(Database user, int id) => user.execute('DELETE FROM meal_log WHERE id > ?', [id]);

/// A new amount scales the logged nutrition (it is a per-gram snapshot); [type] moves it to another meal.
void updateMeal(Database user, int id, {double? grams, String? type}) {
  final old = user.select('SELECT grams FROM meal_log WHERE id = ?', [id]).single['grams'] as num?;
  if (grams != null && grams > 0 && old != null && old > 0) {
    final f = grams / old;
    user.execute('UPDATE meal_log SET grams = ?, ${[for (final n in [...nutrients, ...micronutrients]) '$n = $n * $f'].join(', ')} '
        'WHERE id = ?', [grams, id]);
  }
  if (type != null) user.execute('UPDATE meal_log SET meal_type = ? WHERE id = ?', [type, id]);
}

/// The right food for an entry the agent (or search) got wrong: same amount, time and meal.
void replaceMeal(Database user, int id, FoodChoice food) {
  final old = user.select('SELECT grams FROM meal_log WHERE id = ?', [id]).single['grams'] as num?;
  final g = old?.toDouble() ?? food.servingG ?? 100; // a quick add had no grams
  final cols = [...nutrients, ...micronutrients];
  user.execute(
      'UPDATE meal_log SET description = ?, grams = ?, estimated = ?, recipe_id = ?, '
      '${[for (final c in cols) '$c = ?'].join(', ')} WHERE id = ?',
      [
        food.label, g, food.estimated ? 1 : 0, food.kind == 'recipe' ? food.id : null,
        for (final n in nutrients) (food.per100[n] ?? 0) * g / 100,
        for (final m in micronutrients) switch (food.per100[m]) { final v? => v * g / 100, null => null },
        id,
      ]);
}

/// Meals logged before nutri.db had vitamins and minerals for their food get them from the food of the
/// same name (a food or a dish), once per [dataVersion]. Recipes already had them; products and quick adds stay unknown.
int fillMissingMicros(Database user, Database nutri, int dataVersion) {
  if (pref(user, 'micros_filled') == '$dataVersion') return 0;
  final rows = user.select('SELECT id, description, grams FROM meal_log WHERE iron_mg IS NULL AND grams > 0 AND recipe_id IS NULL');
  final names = {for (final r in rows) r['description'] as String}.toList();
  final marks = List.filled(names.length, '?').join(',');
  final foods = names.isEmpty
      ? const <String, Row>{}
      : {
          // Dishes too: logged before they had vitamins (a dish and a food may share a name; the food wins).
          for (final table in ['dishes', 'foods'])
            for (final f in nutri.select(
                'SELECT name, ${micronutrients.join(', ')} FROM $table WHERE iron_mg IS NOT NULL AND name IN ($marks)',
                names))
              f['name'] as String: f
        };
  var n = 0;
  for (final r in rows) {
    final f = foods[r['description']];
    if (f == null) continue;
    final share = (r['grams'] as num) / 100;
    user.execute('UPDATE meal_log SET ${[for (final m in micronutrients) '$m = ?'].join(', ')} WHERE id = ?',
        [for (final m in micronutrients) switch (f[m]) { final num v => v * share, _ => null }, r['id']]);
    n++;
  }
  setPref(user, 'micros_filled', '$dataVersion');
  return n;
}

/// What the user logs most in the last 30 days, then most recently: one tap to log again.
/// Values are from the latest log of each, per 100 g; the last amount is the serving.
List<FoodChoice> recentFoods(Database user, DateTime now, {int limit = 12}) => [
      for (final r in user.select(
          'SELECT description, grams, recipe_id, estimated, ${[...nutrients, ...micronutrients].join(', ')}, COUNT(*) AS n, '
          'MAX(eaten_at) AS last FROM meal_log WHERE eaten_at >= ? AND grams > 0 '
          'GROUP BY description ORDER BY n DESC, last DESC LIMIT ?',
          [now.subtract(const Duration(days: 30)).millisecondsSinceEpoch, limit]))
        (
          kind: r['recipe_id'] == null ? 'recent' : 'recipe',
          id: r['recipe_id'],
          label: r['description'] as String,
          servingG: (r['grams'] as num).toDouble(),
          per100: {
            for (final n in nutrients) n: ((r[n] as num?) ?? 0) * 100 / (r['grams'] as num),
            for (final m in micronutrients)
              if (r[m] case final num v) m: v * 100 / (r['grams'] as num),
          },
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
      'INSERT INTO meal_log (eaten_at, meal_type, description, grams, ${[...nutrients, ...micronutrients].join(', ')}, estimated, recipe_id) '
      'SELECT ?, meal_type, description, grams, ${[...nutrients, ...micronutrients].join(', ')}, estimated, recipe_id FROM meal_log '
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

/// Longest run of consecutive logged days in [series].
int bestStreak(List<DayTotals> series) {
  var best = 0, run = 0;
  for (final d in series) {
    run = d.entries > 0 ? run + 1 : 0;
    if (run > best) best = run;
  }
  return best;
}

typedef MonthStats = ({DateTime month, Nutrients avg, int logged});

/// One row per calendar month in [series] (oldest first): daily averages over the logged days.
List<MonthStats> monthlyAverages(List<DayTotals> series) {
  final byMonth = <DateTime, List<DayTotals>>{};
  for (final d in series) {
    (byMonth[DateTime(d.day.year, d.day.month)] ??= []).add(d);
  }
  return [
    for (final MapEntry(key: month, value: days) in byMonth.entries)
      () {
        final logged = days.where((d) => d.entries > 0).toList();
        return (
          month: month,
          logged: logged.length,
          avg: {for (final n in nutrients) n: logged.isEmpty ? 0.0 : logged.fold(0.0, (s, d) => s + d.totals[n]!) / logged.length},
        );
      }()
  ];
}

/// What was logged most often since [from]: foods and recipes alike.
List<({String label, int times})> topFoods(Database user, DateTime from, {int limit = 5}) => [
      for (final r in user.select(
          'SELECT description, COUNT(*) AS n FROM meal_log WHERE eaten_at >= ? GROUP BY description '
          'ORDER BY n DESC, MAX(eaten_at) DESC LIMIT ?', [from.millisecondsSinceEpoch, limit]))
        (label: r['description'] as String, times: r['n'] as int)
    ];

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

/// The latest weight in kg and how much it changed since [from] (null with under two readings there);
/// null with no readings.
({double kg, double? change})? weightNow(Database user, DateTime from) {
  final latest = user.select("SELECT value, unit FROM readings WHERE kind = 'weight' ORDER BY logged_at DESC LIMIT 1")
      .firstOrNull;
  if (latest == null) return null;
  final w = weightsSince(user, from);
  return (
    kg: (latest['value'] as num).toDouble() * (latest['unit'] == 'lb' ? 0.45359237 : 1),
    change: w.length < 2 ? null : w.last.kg - w.first.kg,
  );
}

/// The trend weight under each reading: an exponential moving average that moves 10 % of the way
/// to the scale per day (gaps count as days), so a heavy morning of water barely shifts it.
List<({DateTime at, double kg, double trend})> weightTrend(List<({DateTime at, double kg})> readings) {
  final out = <({DateTime at, double kg, double trend})>[];
  for (final r in readings) {
    final prev = out.lastOrNull;
    final days = prev == null ? 0 : r.at.difference(prev.at).inHours / 24;
    final alpha = 1 - math.pow(.9, days.clamp(0, 30));
    out.add((at: r.at, kg: r.kg, trend: prev == null ? r.kg : prev.trend + alpha * (r.kg - prev.trend)));
  }
  return out;
}

/// The trend's change per week over [points] (first to last), or null under a week of data.
double? trendPerWeek(List<({DateTime at, double kg, double trend})> points) {
  if (points.length < 2) return null;
  final days = points.last.at.difference(points.first.at).inHours / 24;
  return days < 7 ? null : (points.last.trend - points.first.trend) / days * 7;
}

/// Anyone can log their weight (goals use it) and see the trend.
/// One a day: logging again that day replaces the reading, so a typo can be corrected
/// (a second reading minutes later would barely move the trend).
void logWeight(Database user, double value, {required bool imperial, required DateTime at}) {
  final (from, to) = _dayRange(at);
  user.execute("DELETE FROM readings WHERE kind = 'weight' AND logged_at >= ? AND logged_at < ?", [from, to]);
  logReading(user, 'weight', value, imperial ? 'lb' : 'kg', at: at);
}

/// A weight a person can have: anything else is a typo (7.24, 724).
bool plausibleWeight(double value, {required bool imperial}) =>
    imperial ? value >= 44 && value <= 770 : value >= 20 && value <= 350;

// ---- per-profile preferences --------------------------------------------------

String? pref(Database user, String key) =>
    user.select('SELECT value FROM prefs WHERE key = ?', [key]).firstOrNull?['value'] as String?;

void setPref(Database user, String key, String value) =>
    user.execute('INSERT OR REPLACE INTO prefs (key, value) VALUES (?, ?)', [key, value]);

// ---- active calories (Health Connect / Apple Health) ---------------------------

/// Today's active calories, as "2026-10-17|320": shown on Today next to the goal, never added to it
/// (the activity level already counts a typical day's exercise).
const activeKcalPref = 'active_kcal';

/// A day's target for the "burnt" ring on Today.
const activeKcalTarget = 300.0;

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// The active calories burned on [day]; 0 for any day but the stored one.
double activeKcalOn(Database user, DateTime day) {
  final parts = pref(user, activeKcalPref)?.split('|');
  return parts != null && parts.length == 2 && parts[0] == _dayKey(day) ? double.tryParse(parts[1]) ?? 0 : 0;
}

/// Stores [kcal] as [now]'s active calories (rounded); true when that changed the value.
bool storeActiveKcal(Database user, DateTime now, double kcal) {
  if (kcal.round() == activeKcalOn(user, now).round()) return false;
  setPref(user, activeKcalPref, '${_dayKey(now)}|${kcal.round()}');
  return true;
}

// ---- water ------------------------------------------------------------------------

/// One glass, the "+" on Today.
const glassMl = 250.0;

double waterOn(Database user, DateTime day) {
  final (from, to) = _dayRange(day);
  return (user.select('SELECT TOTAL(ml) AS ml FROM water_log WHERE drunk_at >= ? AND drunk_at < ?', [from, to])
          .single['ml'] as num)
      .toDouble();
}

void logWater(Database user, double ml, DateTime at) =>
    user.execute('INSERT INTO water_log (drunk_at, ml) VALUES (?, ?)', [at.millisecondsSinceEpoch, ml]);

/// Takes back the last glass logged on [day] (a mistaken tap).
void undoWater(Database user, DateTime day) {
  final (from, to) = _dayRange(day);
  user.execute('DELETE FROM water_log WHERE id = (SELECT id FROM water_log WHERE drunk_at >= ? AND drunk_at < ? '
      'ORDER BY drunk_at DESC LIMIT 1)', [from, to]);
}

/// The user's own goal, else 30 ml per kg of body weight (EFSA-style rule of thumb), else 2 litres.
double waterGoal(Database user) {
  final own = double.tryParse(pref(user, 'water_goal_ml') ?? '');
  if (own != null && own > 0) return own;
  final kg = user.select('SELECT weight_kg FROM body').firstOrNull?['weight_kg'] as num?;
  return kg == null ? 2000 : (kg * 30 / 250).round() * 250.0; // whole glasses
}

// ---- fasting ----------------------------------------------------------------------

typedef Fast = ({int id, DateTime start, int targetHours});

/// The running fast, if any.
Fast? currentFast(Database user) => [
      for (final r in user.select('SELECT * FROM fasts WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1'))
        (id: r['id'] as int, start: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
            targetHours: r['target_hours'] as int)
    ].firstOrNull;

/// Starts now, or at the last meal ("I stopped eating at 20:00").
void startFast(Database user, DateTime start, int targetHours) {
  user.execute('UPDATE fasts SET ended_at = ? WHERE ended_at IS NULL', [start.millisecondsSinceEpoch]);
  user.execute('INSERT INTO fasts (started_at, target_hours) VALUES (?, ?)', [start.millisecondsSinceEpoch, targetHours]);
}

void endFast(Database user, DateTime at) =>
    user.execute('UPDATE fasts SET ended_at = ? WHERE ended_at IS NULL', [at.millisecondsSinceEpoch]);

/// When the user last logged food; null = never.
DateTime? lastMealAt(Database user) {
  final at = user.select('SELECT MAX(eaten_at) AS at FROM meal_log').single['at'] as int?;
  return at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
}

// ---- weekly review ------------------------------------------------------------------

typedef WeekReview = ({
  int logged, // days with any log, of 7
  double? avgKcal, double? kcalGoal,
  int lowProtein, int lowFiber, // logged days under 80% of the goal
  int overSugar, int overSodium, // logged days over the limit
  double avgWater, double waterGoal,
  String? topFood,
  String? focus, // the weakest point: 'protein_g', 'fiber_g', 'sugar_g', 'sodium_mg'; null = nothing stands out
});

/// The 7 days ending [now], from the logs only (no model): what went well and what to work on.
WeekReview weeklyReview(Database user, Nutrients targets, DateTime now) {
  final days = dailyTotals(user, now, 7).where((d) => d.entries > 0).toList();
  int count(bool Function(Nutrients t) f) => days.where((d) => f(d.totals)).length;
  int under(String k) => targets[k] == null ? 0 : count((t) => t[k]! < targets[k]! * .8);
  int over(String k) => targets[k] == null ? 0 : count((t) => t[k]! > targets[k]!);
  final first = DateTime(now.year, now.month, now.day - 6);
  final water = [for (var i = 0; i < 7; i++) waterOn(user, DateTime(first.year, first.month, first.day + i))];
  final top = user.select(
      'SELECT description, COUNT(*) AS n FROM meal_log WHERE eaten_at >= ? GROUP BY description '
      'HAVING n >= 2 ORDER BY n DESC LIMIT 1', [first.millisecondsSinceEpoch]).firstOrNull?['description'] as String?;
  final misses = {
    'protein_g': under('protein_g'), 'fiber_g': under('fiber_g'), 'sugar_g': over('sugar_g'), 'sodium_mg': over('sodium_mg'),
  };
  final worst = misses.entries.reduce((a, b) => b.value > a.value ? b : a);
  return (
    logged: days.length,
    avgKcal: days.isEmpty ? null : days.fold(0.0, (s, d) => s + d.totals['kcal']!) / days.length,
    kcalGoal: targets['kcal'],
    lowProtein: misses['protein_g']!, lowFiber: misses['fiber_g']!,
    overSugar: misses['sugar_g']!, overSodium: misses['sodium_mg']!,
    avgWater: water.fold(0.0, (s, v) => s + v) / 7, waterGoal: waterGoal(user),
    topFood: top,
    focus: worst.value >= 2 ? worst.key : null, // twice in a week, not a one-off
  );
}
