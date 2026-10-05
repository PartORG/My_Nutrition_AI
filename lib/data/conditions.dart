import 'package:sqlite3/sqlite3.dart';

/// Medium: the profile's conditions and what they mean, from nutri.db rules.
/// Rules only ever tighten: a limit lowers a target, never raises it.

typedef Condition = ({int id, String name});

List<Condition> allConditions(Database nutri) => [
      for (final r in nutri.select('SELECT id, name FROM conditions ORDER BY name'))
        (id: r['id'] as int, name: r['name'] as String)
    ];

List<Condition> myConditions(Database user) => [
      for (final r in user.select('SELECT condition_id, name FROM user_conditions ORDER BY name'))
        (id: r['condition_id'] as int, name: r['name'] as String)
    ];

void setCondition(Database user, Condition c, bool on, {required DateTime now}) => on
    ? user.execute('INSERT OR IGNORE INTO user_conditions (condition_id, name, added_at) VALUES (?, ?, ?)',
        [c.id, c.name, now.millisecondsSinceEpoch])
    : user.execute('DELETE FROM user_conditions WHERE condition_id = ?', [c.id]);

/// The lowest daily max per nutrient over the profile's conditions, with the
/// condition that set it.
Map<String, ({double max, String condition})> conditionLimits(Database nutri, Database user) {
  final mine = myConditions(user);
  if (mine.isEmpty) return {};
  final limits = <String, ({double max, String condition})>{};
  for (final r in nutri.select(
      'SELECT c.name, r.nutrient, r.max_per_day FROM condition_rules r JOIN conditions c ON c.id = r.condition_id '
      'WHERE r.condition_id IN (${_ids(mine)}) ORDER BY r.max_per_day DESC')) {
    // Descending, so the lowest max is written last and wins.
    limits[r['nutrient'] as String] = (max: (r['max_per_day'] as num).toDouble(), condition: r['name'] as String);
  }
  return limits;
}

/// nutri.db food ids the profile's conditions say to avoid, with the condition.
Map<int, String> avoidedFoods(Database nutri, Database user) {
  final mine = myConditions(user);
  // Additive contract table: an older nutri.db may not have it yet.
  if (mine.isEmpty || nutri.select("SELECT 1 FROM sqlite_master WHERE name = 'condition_avoid'").isEmpty) {
    return {};
  }
  return {
    for (final r in nutri.select(
        'SELECT a.food_id, c.name FROM condition_avoid a JOIN conditions c ON c.id = a.condition_id '
        'WHERE a.condition_id IN (${_ids(mine)})'))
      r['food_id'] as int: r['name'] as String
  };
}

String _ids(List<Condition> cs) => cs.map((c) => c.id).join(',');

/// 'diabetes_t2' → 'Diabetes t2' when the app has no translated name for it.
String conditionFallbackName(String name) {
  final s = name.replaceAll('_', ' ');
  return s.length <= 3 ? s.toUpperCase() : s[0].toUpperCase() + s.substring(1);
}
