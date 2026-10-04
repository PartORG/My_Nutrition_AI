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
