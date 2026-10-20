import 'package:sqlite3/sqlite3.dart';

import 'nutri_db.dart' show hasHealth;

/// Medium: the profile's conditions and what they mean, from health.db (attached to nutri.db as `health`).
/// Rules only ever tighten: a limit lowers a target, never raises it.

typedef Condition = ({int id, String name});

List<Condition> allConditions(Database nutri) => [
      if (hasHealth(nutri))
        for (final r in nutri.select('SELECT id, key FROM health.conditions ORDER BY key'))
          (id: r['id'] as int, name: r['key'] as String)
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
  if (mine.isEmpty || !hasHealth(nutri)) return {};
  final limits = <String, ({double max, String condition})>{};
  for (final r in nutri.select(
      'SELECT c.key, r.nutrient, r.max_per_day FROM health.condition_rules r '
      'JOIN health.conditions c ON c.id = r.condition_id '
      'WHERE r.condition_id IN (${_ids(mine)}) AND r.max_per_day IS NOT NULL ORDER BY r.max_per_day DESC')) {
    // Descending, so the lowest max is written last and wins.
    limits[r['nutrient'] as String] = (max: (r['max_per_day'] as num).toDouble(), condition: r['key'] as String);
  }
  return limits;
}

/// nutri.db food ids the profile's conditions say to avoid, with the condition (limit and prefer are advisory).
Map<int, String> avoidedFoods(Database nutri, Database user) {
  final mine = myConditions(user);
  if (mine.isEmpty || !hasHealth(nutri)) return {};
  return {
    for (final r in nutri.select(
        "SELECT a.food_id, c.key FROM health.condition_foods a JOIN health.conditions c ON c.id = a.condition_id "
        "WHERE a.effect = 'avoid' AND a.condition_id IN (${_ids(mine)})"))
      r['food_id'] as int: r['key'] as String
  };
}

String _ids(List<Condition> cs) => cs.map((c) => c.id).join(',');

/// 'diabetes_t2' → 'Diabetes t2' when the app has no translated name for it.
String conditionFallbackName(String name) {
  final s = name.replaceAll('_', ' ');
  return s.length <= 3 ? s.toUpperCase() : s[0].toUpperCase() + s.substring(1);
}
