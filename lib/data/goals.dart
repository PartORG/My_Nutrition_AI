import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../agent/agent_tools.dart' show nutrients;
import 'conditions.dart';
import 'diary.dart' show dayRange, panelTotals, pref, setPref;
import 'nutri_db.dart' show hasHealth;
import 'reminders.dart' show loadReminders;

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
  int? birthMonth, // 1-12; null: saved before v13, the year alone
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

/// Whole years on [now]. In the birth month the birthday counts as not yet passed: with the month alone,
/// that keeps a 17-year-old from ever getting the adult formulas.
int ageOn(Body b, DateTime now) =>
    now.year - b.birthYear - (b.birthMonth != null && now.month <= b.birthMonth! ? 1 : 0);

/// Under this BMI (WHO: underweight) a deficit is unsafe: "lose" gives the maintain targets.
const underweightBmi = 18.5;
bool underweight(double heightCm, double weightKg) => weightKg / pow(heightCm / 100, 2) < underweightBmi;

/// Mifflin-St Jeor resting kcal per day; null under 18.
double? basalKcal(Body b, {required DateTime now}) {
  final age = ageOn(b, now);
  if (age < adultAge) return null;
  final base = 10 * b.weightKg + 6.25 * b.heightCm - 5 * age;
  return switch (b.sex) {
    Sex.male => base + 5,
    Sex.female => base - 161,
    Sex.other => base - 78, // midpoint of the two
  };
}

/// Targets from the plan (docs/PLAN.md, Goals): Mifflin-St Jeor BMR × activity,
/// ±15% for the goal (no deficit when underweight), kcal floor; protein 1.2 g/kg, fat 30% of kcal, carbs the
/// rest; fiber 14 g per 1000 kcal; WHO limits for sugar (10% of kcal) and
/// sodium (2000 mg). Null under 18.
Targets? computeTargets(Body b, {required DateTime now}) {
  final bmr = basalKcal(b, now: now);
  if (bmr == null) return null;
  final change = b.goal == Goal.lose && underweight(b.heightCm, b.weightKg) ? 0.0 : b.goal.change;
  final kcal = max(bmr * b.activity.factor * (1 + change), kcalFloor[b.sex]!);
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

// ---- reference intakes (health.db, NASEM) ------------------------------------

/// Pregnancy and breastfeeding change the reference intakes: '', 'pregnancy' or 'lactation' (a profile pref).
const lifeStages = ['', 'pregnancy', 'lactation'];

String lifeStage(Database user) => switch (pref(user, 'life_stage')) {
      final s? when lifeStages.contains(s) => s,
      _ => '',
    };

void setLifeStage(Database user, String stage) => setPref(user, 'life_stage', stage);

/// NASEM's ULs for these cover supplements and added forms only (magnesium, niacin, folic acid, vitamin E): food
/// alone over them is no warning.
const _ulNotFromFood = {'magnesium_mg', 'vitamin_b3_mg', 'folate_ug', 'vitamin_e_mg'};

/// Daily goals from health.db (NASEM): the RDA, else the AI, for the body's sex, age and life stage. Adults only,
/// like [computeTargets]; 'other' takes the mean of the female and male values. Empty without health.db.
Targets referenceGoals(Database nutri, Body b, String stage, {required DateTime now}) => ageOn(b, now) < adultAge
    ? {}
    : _reference(nutri, b, stage, now, const ['rda', 'ai'], (vs) => vs.reduce((x, y) => x + y) / vs.length);

/// The tolerable upper intakes (NASEM UL) that food can pass; 'other' takes the lower of the two.
Targets upperLimits(Database nutri, Body b, String stage, {required DateTime now}) =>
    _reference(nutri, b, stage, now, const ['ul'], (vs) => vs.reduce(min))
      ..removeWhere((k, _) => _ulNotFromFood.contains(k));

/// Per nutrient, the first of [kinds] that has a row, [merge]d over the sexes asked. A life stage without rows at
/// this age (pregnant at 55) falls back to the plain values.
Targets _reference(Database nutri, Body b, String stage, DateTime now, List<String> kinds,
    double Function(List<double>) merge) {
  if (!hasHealth(nutri)) return {};
  final sexes = stage.isNotEmpty || b.sex == Sex.female ? ['female'] : b.sex == Sex.male ? ['male'] : ['female', 'male'];
  final age = ageOn(b, now);
  List<Row> rows(String stage) => nutri.select(
      "SELECT nutrient, kind, amount FROM health.reference_values WHERE source_id = 'nasem_dri' "
      "AND ? >= age_from AND ? < age_to AND life_stage = ? AND kind IN (${kinds.map((_) => '?').join(', ')}) "
      "AND sex IN ('any', ${sexes.map((_) => '?').join(', ')})", [age, age, stage, ...kinds, ...sexes]);
  final found = rows(stage);
  final by = <String, Map<String, List<double>>>{};
  for (final r in found.isEmpty && stage.isNotEmpty ? rows('') : found) {
    (by.putIfAbsent(r['nutrient'] as String, () => {})[r['kind'] as String] ??= []).add((r['amount'] as num).toDouble());
  }
  return {for (final MapEntry(key: n, value: k) in by.entries) n: merge(k[kinds.firstWhere(k.containsKey)]!)};
}

/// The day's ceilings: the ULs, and the targets that are limits ([limitKeys], the conditions' caps) where lower.
/// Empty without body data.
Targets dayLimits(Database user, Database nutri, {required DateTime now}) {
  final body = loadBody(user);
  if (body == null) return {};
  final t = currentTargets(user, nutri: nutri, now: now);
  final limits = upperLimits(nutri, body, lifeStage(user), now: now);
  for (final k in {...limitKeys, ...t.limited.keys}) {
    if (t.values[k] case final v? when v < (limits[k] ?? double.infinity)) limits[k] = v;
  }
  return limits;
}

/// Targets that are ceilings, not goals: less is fine.
const limitKeys = {'sugar_g', 'sodium_mg'};

/// [eaten] over [limits], as (nutrient, eaten, limit), the furthest over first. Vitamin A counts its preformed part
/// only (the UL is for retinol; vitamin_a_ug is RAE, carotenoids at 12 µg β-carotene per µg).
List<(String, double, double)> overLimits(Map<String, double> eaten, Targets limits) => [
      for (final MapEntry(key: k, value: limit) in limits.entries)
        if (switch (k) {
          'vitamin_a_ug' => max(0.0, (eaten[k] ?? 0) - (eaten['beta_carotene_ug'] ?? 0) / 12),
          _ => eaten[k] ?? 0,
        } case final v when v > limit)
          (k, v, limit)
    ]..sort((a, b) => (b.$2 / b.$3).compareTo(a.$2 / a.$3));

/// Under this share of the goal a nutrient is low (as the weekly review counts it).
const lowShare = .8;

/// Today's chip and the chat's context: what is over a limit (always), and what is under [lowShare] of its goal —
/// only after the usual dinner time (before it the day isn't over), the lowest share first, at most 5. Never low:
/// energy and its split (the goals line has them), ceilings, and totals some meal doesn't know (a label without it).
/// [micros] false (Free): the vitamins and minerals have no goals, so only protein and fibre can be low.
({List<(String, double, double)> low, List<(String, double, double)> over}) lowAndOver(Database user, Database nutri,
    {required DateTime now, bool micros = true}) {
  final (from, to) = dayRange(now);
  final p = panelTotals(user, nutri, from, to);
  if (p.meals == 0) return (low: const [], over: const []);
  final over = overLimits(p.totals, dayLimits(user, nutri, now: now));
  final dinner = loadReminders(user, now: now).firstWhere((r) => r.slot == 'dinner');
  if (now.hour * 60 + now.minute < dinner.hour * 60 + dinner.minute) return (low: const [], over: over);
  final t = currentTargets(user, nutri: nutri, now: now);
  final low = [
    for (final MapEntry(key: k, value: goal) in t.values.entries)
      if (!const {'kcal', 'fat_g', 'carbs_g'}.contains(k) && !limitKeys.contains(k) && !t.limited.containsKey(k) &&
          !p.partial.contains(k) && (micros || nutrients.contains(k)) && (p.totals[k] ?? 0) < goal * lowShare)
        (k, p.totals[k] ?? 0, goal)
  ]..sort((a, b) => (a.$2 / a.$3).compareTo(b.$2 / b.$3));
  return (low: low.take(5).toList(), over: over);
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
    birthMonth: r['birth_month'] as int?,
    heightCm: (r['height_cm'] as num).toDouble(),
    weightKg: weight,
    activity: Activity.fromDb(r['activity'] as String),
    goal: Goal.values.byName(r['goal'] as String),
    imperial: r['units'] == 'imperial',
  );
}

void saveBody(Database user, Body b, {required DateTime now}) => user.execute(
      'INSERT OR REPLACE INTO body (id, sex, birth_year, birth_month, height_cm, weight_kg, activity, goal, units, '
      'updated_at) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [b.sex.name, b.birthYear, b.birthMonth, b.heightCm, b.weightKg, b.activity.db, b.goal.name,
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

/// What the app uses: computed targets (macros from the formula, the rest from [referenceGoals]) with the user's
/// overrides on top, then capped by the profile's condition limits (rules only tighten, even a manual
/// target). [limited] maps a capped nutrient to the condition that capped it.
/// Empty when nothing is set (or under 18 with no manual targets or conditions).
/// [nutri] null = conditions unknown (tests without nutri.db).
({Targets values, Set<String> custom, Map<String, String> limited}) currentTargets(Database user,
    {required Database? nutri, required DateTime now}) {
  final body = loadBody(user);
  final computed = body == null ? null : computeTargets(body, now: now);
  final reference = body == null || nutri == null ? const <String, double>{} : referenceGoals(nutri, body, lifeStage(user), now: now);
  final overrides = loadOverrides(user);
  // The formula keeps the macros (personal kcal, protein per kg); health.db gives the rest.
  final values = {
    ...?computed,
    for (final e in reference.entries) if (!nutrients.contains(e.key)) e.key: e.value,
    ...overrides,
  };
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
