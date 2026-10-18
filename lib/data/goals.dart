import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'conditions.dart';

/// Daily targets per nutrient (same keys as nutri.db columns).
typedef Targets = Map<String, double>;

enum Sex { female, male, other }

enum Activity {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const Activity(this.factor);
  final double factor;

  String get db => this == veryActive ? 'very_active' : name;
  static Activity fromDb(String s) => s == 'very_active' ? veryActive : Activity.values.byName(s);
}

enum Goal {
  lose(-.15),
  maintain(0),
  gain(.15);

  const Goal(this.change);
  final double change;
}

typedef Body = ({
  Sex sex,
  int birthYear,
  double heightCm,
  double weightKg,
  Activity activity,
  Goal goal,
  bool imperial,
});

/// Under 18 the adult formulas are wrong: targets are manual only.
const adultAge = 18;

/// Lower kcal bound, so a "lose" goal never prescribes starving.
const kcalFloor = {Sex.female: 1200.0, Sex.male: 1500.0, Sex.other: 1350.0};

/// Mifflin-St Jeor resting kcal per day; null under 18.
double? basalKcal(Body b, {required DateTime now}) {
  final age = now.year - b.birthYear;
  if (age < adultAge) return null;
  final base = 10 * b.weightKg + 6.25 * b.heightCm - 5 * age;
  return switch (b.sex) {
    Sex.male => base + 5,
    Sex.female => base - 161,
    Sex.other => base - 78, // midpoint of the two
  };
}

/// Targets from the plan (docs/PLAN.md, Goals): Mifflin-St Jeor BMR × activity,
/// ±15% for the goal, kcal floor; protein 1.2 g/kg, fat 30% of kcal, carbs the
/// rest; fiber 14 g per 1000 kcal; WHO limits for sugar (10% of kcal) and
/// sodium (2000 mg). Null under 18.
Targets? computeTargets(Body b, {required DateTime now}) {
  final bmr = basalKcal(b, now: now);
  if (bmr == null) return null;
  final kcal = max(bmr * b.activity.factor * (1 + b.goal.change), kcalFloor[b.sex]!);
  final protein = 1.2 * b.weightKg;
  final fat = kcal * .30 / 9;
  return {
    'kcal': kcal,
    'protein_g': protein,
    'fat_g': fat,
    'carbs_g': max(0, (kcal - protein * 4 - fat * 9) / 4),
    'fiber_g': 14 * kcal / 1000,
    'sugar_g': kcal * .10 / 4,
    'sodium_mg': 2000,
  };
}

// ---- storage (user.db v2) -------------------------------------------------

Body? loadBody(Database user) {
  final r = user.select('SELECT * FROM body WHERE id = 1').firstOrNull;
  if (r == null || r['sex'] == null || r['birth_year'] == null || r['height_cm'] == null ||
      r['weight_kg'] == null || r['activity'] == null || r['goal'] == null) {
    return null;
  }
  // A newer weight reading wins over the onboarding weight.
  final reading = user.select(
      "SELECT value, unit FROM readings WHERE kind = 'weight' AND logged_at > ? ORDER BY logged_at DESC LIMIT 1",
      [r['updated_at']]).firstOrNull;
  final weight = reading == null
      ? (r['weight_kg'] as num).toDouble()
      : (reading['value'] as num).toDouble() * (reading['unit'] == 'lb' ? lbToKg : 1);
  return (
    sex: Sex.values.byName(r['sex'] as String),
    birthYear: r['birth_year'] as int,
    heightCm: (r['height_cm'] as num).toDouble(),
    weightKg: weight,
    activity: Activity.fromDb(r['activity'] as String),
    goal: Goal.values.byName(r['goal'] as String),
    imperial: r['units'] == 'imperial',
  );
}

void saveBody(Database user, Body b, {required DateTime now}) => user.execute(
      'INSERT OR REPLACE INTO body (id, sex, birth_year, height_cm, weight_kg, activity, goal, units, updated_at) '
      'VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)',
      [b.sex.name, b.birthYear, b.heightCm, b.weightKg, b.activity.db, b.goal.name,
          b.imperial ? 'imperial' : 'metric', now.millisecondsSinceEpoch],
    );

Map<String, double> loadOverrides(Database user) => {
      for (final r in user.select('SELECT nutrient, value FROM goal_overrides'))
        r['nutrient'] as String: (r['value'] as num).toDouble()
    };

/// [value] null removes the override (back to the computed target).
void setOverride(Database user, String nutrient, double? value) => value == null
    ? user.execute('DELETE FROM goal_overrides WHERE nutrient = ?', [nutrient])
    : user.execute('INSERT OR REPLACE INTO goal_overrides (nutrient, value) VALUES (?, ?)', [nutrient, value]);

/// What the app uses: computed targets with the user's overrides on top, then
/// capped by the profile's condition limits (rules only tighten, even a manual
/// target). [limited] maps a capped nutrient to the condition that capped it.
/// Empty when nothing is set (or under 18 with no manual targets or conditions).
/// [nutri] null = conditions unknown (tests without nutri.db).
({Targets values, Set<String> custom, Map<String, String> limited}) currentTargets(Database user,
    {required Database? nutri, required DateTime now}) {
  final body = loadBody(user);
  final computed = body == null ? null : computeTargets(body, now: now);
  final overrides = loadOverrides(user);
  final values = {...?computed, ...overrides};
  final limited = <String, String>{};
  if (nutri != null) {
    for (final MapEntry(key: k, value: l) in conditionLimits(nutri, user).entries) {
      if (values[k] == null || l.max < values[k]!) {
        values[k] = l.max;
        limited[k] = l.condition;
      }
    }
  }
  return (values: values, custom: overrides.keys.toSet(), limited: limited);
}

// ---- units ------------------------------------------------------------------

const lbToKg = 0.45359237;
const inchToCm = 2.54;

double kgToLb(double kg) => kg / lbToKg;
({int feet, double inches}) cmToFeetInches(double cm) {
  final totalIn = cm / inchToCm;
  return (feet: totalIn ~/ 12, inches: totalIn % 12);
}

double feetInchesToCm(int feet, double inches) => (feet * 12 + inches) * inchToCm;
