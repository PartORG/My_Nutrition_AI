import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'diary.dart' show pref, setPref, trendPerWeek, weightTrend, weightsSince;
import 'goals.dart';

/// Behaviour patterns (docs/PLAN.md "All nutrients, patterns", 7–8): counted from the logs of the last [patternDays]
/// whole days, no model. Records, never interprets: each one is numbers the user can check.
const patternDays = 28;

/// What counts as late: food at or after this hour.
const lateHour = 21;

/// A symptom "follows" a food logged up to this many hours before it.
const symptomHours = 6;

/// [kind]: logging, skipped, late, weekend, gap, weight, symptom. [strength] 0–1 ranks them for the chat's context.
/// [args] are the numbers its sentence needs ([patternSentence], the app's own texts).
typedef Pattern = ({String kind, double strength, Map<String, Object> args});

/// Every pattern the logs show, strongest first. Needs a week of logs since the first one. [symptoms]: the seventh
/// (Medium), symptoms after foods, at least 5 times and at least half the times it was eaten, as counts.
List<Pattern> findPatterns(Database user, {required DateTime now, Targets goals = const {}, bool symptoms = false}) {
  final today = DateTime(now.year, now.month, now.day);
  final firstLog = user.select('SELECT MIN(eaten_at) AS t FROM meal_log').single['t'] as int?;
  if (firstLog == null) return [];
  final f = DateTime.fromMillisecondsSinceEpoch(firstLog);
  // From the first log on: a new user's empty weeks are not "logging gaps".
  var start = DateTime(today.year, today.month, today.day - patternDays);
  if (DateTime(f.year, f.month, f.day).isAfter(start)) start = DateTime(f.year, f.month, f.day);
  final days = [for (var d = start; d.isBefore(today); d = DateTime(d.year, d.month, d.day + 1)) d];
  if (days.length < 7) return [];

  final keys = [for (final k in goals.keys) if (!const {'kcal', 'fat_g', 'carbs_g'}.contains(k) && !limitKeys.contains(k)) k];
  final rows = {
    for (final r in user.select(
        "SELECT date(eaten_at / 1000, 'unixepoch', 'localtime') AS d, COUNT(*) AS n, "
        "group_concat(DISTINCT meal_type) AS types, TOTAL(kcal) AS kcal, "
        "MAX(CAST(strftime('%H', eaten_at / 1000, 'unixepoch', 'localtime') AS INT)) AS last_hour"
        '${[for (final k in keys) ', TOTAL($k) AS $k, COUNT($k) AS n_$k'].join()} '
        'FROM meal_log WHERE eaten_at >= ? AND eaten_at < ? GROUP BY d',
        [start.millisecondsSinceEpoch, today.millisecondsSinceEpoch]))
      r['d'] as String: r
  };
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Set<String> types(Row r) => {...((r['types'] as String?) ?? '').split(',')}..remove('');
  // A whole day: two meals or more, and half the kcal goal when there is one. A half-logged day is not a low day.
  bool whole(Row? r) =>
      r != null && types(r).length >= 2 && (goals['kcal'] == null || (r['kcal'] as num) >= goals['kcal']! * .5);
  final full = [for (final d in days) if (whole(rows[key(d)])) (day: d, row: rows[key(d)]!)];
  final out = <Pattern>[];

  // 5. Logging gaps: said first, so the rest is read as "of the whole days".
  if (full.length < days.length * .7) {
    out.add((kind: 'logging', strength: 1 - full.length / days.length, args: {'n': full.length, 'days': days.length}));
  }
  if (full.length >= 4) {
    final n = full.length;
    // 1. Skipped meals.
    for (final meal in ['breakfast', 'lunch', 'dinner']) {
      final skipped = full.where((d) => !types(d.row).contains(meal)).length;
      if (skipped >= 3 && skipped >= n * .4) {
        out.add((kind: 'skipped', strength: skipped / n, args: {'meal': meal, 'n': skipped, 'days': n}));
      }
    }
    // 2. Late eating.
    final late = full.where((d) => (d.row['last_hour'] as int) >= lateHour).length;
    if (late >= 3 && late >= n * .3) {
      out.add((kind: 'late', strength: late / n, args: {'n': late, 'days': n, 'hour': lateHour}));
    }
    // 3. Weekdays vs weekends.
    double avg(Iterable<({DateTime day, Row row})> l) => l.fold(0.0, (s, d) => s + (d.row['kcal'] as num)) / l.length;
    final weekend = full.where((d) => d.day.weekday >= DateTime.saturday);
    final weekday = full.where((d) => d.day.weekday < DateTime.saturday);
    if (weekend.length >= 2 && weekday.length >= 3) {
      final change = avg(weekend) / avg(weekday) - 1;
      if (change.abs() >= .15) {
        out.add((kind: 'weekend', strength: min(1, change.abs() / .5),
            args: {'weekend': avg(weekend).round(), 'weekday': avg(weekday).round(), 'change': (change * 100).round()}));
      }
    }
    // 4. Gaps that keep coming back: under the low share on most whole days that know the nutrient.
    for (final k in keys) {
      final known = full.where((d) => d.row['n_$k'] == d.row['n']).toList();
      final low = known.where((d) => (d.row[k] as num) < goals[k]! * lowShare).length;
      if (known.length >= 4 && low >= known.length * .6) {
        out.add((kind: 'gap', strength: low / known.length, args: {'nutrient': k, 'n': low, 'days': known.length}));
      }
    }
    // 6. Weight against intake: the numbers side by side, no verdict.
    final points = weightTrend(weightsSince(user, start));
    if (trendPerWeek(points) case final perWeek? when points.length >= 3) {
      out.add((kind: 'weight', strength: min(.8, perWeek.abs() / .5),
          args: {'change': (perWeek * 10).round() / 10, 'kcal': avg(full).round(), 'goal': ?goals['kcal']?.round()}));
    }
  }
  // 7. Symptoms after foods: how often a logged food was followed by a symptom within [symptomHours]. Counts only.
  if (symptoms) {
    final from = start.millisecondsSinceEpoch, h = symptomHours * 3600000;
    for (final r in user.select(
        'SELECT m.description AS food, lower(s.symptom) AS symptom, COUNT(DISTINCT m.id) AS n FROM meal_log m '
        'JOIN symptoms s ON s.logged_at > m.eaten_at AND s.logged_at <= m.eaten_at + ? '
        'WHERE m.eaten_at >= ? GROUP BY food, lower(s.symptom) HAVING n >= 5 ORDER BY n DESC', [h, from])) {
      // Meals too recent to have been followed yet don't count as "not followed".
      final times = user.select('SELECT COUNT(*) AS n FROM meal_log WHERE description = ? AND eaten_at >= ? AND eaten_at < ?',
          [r['food'], from, now.millisecondsSinceEpoch - h]).single['n'] as int;
      final n = r['n'] as int;
      // A food eaten every day comes before any symptom: only one followed at least half the times counts.
      if (n < times * .5) continue;
      out.add((kind: 'symptom', strength: n / max(n, times),
          args: {'symptom': r['symptom'] as String, 'food': r['food'] as String, 'n': n, 'times': max(n, times),
              'hours': symptomHours}));
    }
  }
  return out..sort((a, b) => b.strength.compareTo(a.strength));
}

/// One pattern for the model, in English: the numbers, never a cause.
String patternSentence(Pattern p) {
  final a = p.args;
  String name(String key) => key.substring(0, key.lastIndexOf('_')).replaceAll('_', ' ');
  return switch (p.kind) {
    'logging' => 'whole days logged: ${a['n']} of the last ${a['days']} (the other patterns count only those)',
    'skipped' => '${a['meal']} skipped on ${a['n']} of ${a['days']} days',
    'late' => 'ate after ${a['hour']}:00 on ${a['n']} of ${a['days']} days',
    'weekend' => 'weekends ${a['weekend']} kcal a day, weekdays ${a['weekday']} kcal '
        '(${(a['change'] as int) > 0 ? '+' : ''}${a['change']} %)',
    'gap' => '${name(a['nutrient'] as String)} under ${(lowShare * 100).round()} % of the goal on ${a['n']} of '
        '${a['days']} days',
    'weight' => 'weight trend ${a['change']} kg a week while eating ${a['kcal']} kcal a day on average'
        '${a['goal'] == null ? '' : ' (goal ${a['goal']})'}',
    _ => '${a['symptom']} logged within ${a['hours']} h after ${a['food']} ${a['n']} of ${a['times']} times '
        '(counts only, not a cause)',
  };
}

/// The context block's line: the 3 strongest, computed once a day (the day's first message) and kept in prefs.
/// [basic] patterns 1–6, [medium] the symptoms too; null when there are none or the tier has none.
String? patternsLine(Database user, {required DateTime now, required Targets goals, required bool basic,
    required bool medium}) {
  if (!basic) return null;
  final stamp = '${now.year}-${now.month}-${now.day}|${medium ? 'm' : 'b'}|';
  final cached = pref(user, 'patterns_line');
  if (cached != null && cached.startsWith(stamp)) {
    final line = cached.substring(stamp.length);
    return line.isEmpty ? null : line;
  }
  final top = findPatterns(user, now: now, goals: goals, symptoms: medium).take(3);
  final line = top.isEmpty ? '' : 'Patterns (last 4 weeks, from the logs): ${top.map(patternSentence).join('; ')}.';
  setPref(user, 'patterns_line', '$stamp$line');
  return line.isEmpty ? null : line;
}
