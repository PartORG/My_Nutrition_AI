import 'package:sqlite3/sqlite3.dart';

/// Medium: symptoms and readings (user.db v1 tables). Recorded exactly as the
/// user gave them; nothing here interprets a value.

typedef Symptom = ({int id, DateTime at, String symptom, int? severity});
typedef Reading = ({int id, DateTime at, String kind, double value, double? value2, String unit});

const readingKinds = ['glucose', 'blood_pressure', 'weight'];

/// mmol/L → mg/dL, so one chart can hold readings in either unit.
const glucoseMgPerMmol = 18.016;

void logSymptom(Database user, String symptom, int? severity, {required DateTime at}) => user.execute(
    'INSERT INTO symptoms (logged_at, symptom, severity) VALUES (?, ?, ?)',
    [at.millisecondsSinceEpoch, symptom.trim().toLowerCase(), severity]);

void logReading(Database user, String kind, double value, String unit, {double? value2, required DateTime at}) =>
    user.execute('INSERT INTO readings (logged_at, kind, value, value2, unit) VALUES (?, ?, ?, ?, ?)',
        [at.millisecondsSinceEpoch, kind, value, value2, unit]);

void deleteSymptom(Database user, int id) => user.execute('DELETE FROM symptoms WHERE id = ?', [id]);
void deleteReading(Database user, int id) => user.execute('DELETE FROM readings WHERE id = ?', [id]);

/// [from, to), oldest first.
List<Symptom> symptomsBetween(Database user, DateTime from, DateTime to) => [
      for (final r in user.select(
          'SELECT * FROM symptoms WHERE logged_at >= ? AND logged_at < ? ORDER BY logged_at',
          [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]))
        (
          id: r['id'] as int,
          at: DateTime.fromMillisecondsSinceEpoch(r['logged_at'] as int),
          symptom: r['symptom'] as String,
          severity: r['severity'] as int?,
        )
    ];

/// [from, to), oldest first; all kinds unless [kind] is given.
List<Reading> readingsBetween(Database user, DateTime from, DateTime to, {String? kind}) => [
      for (final r in user.select(
          'SELECT * FROM readings WHERE logged_at >= ? AND logged_at < ? AND (? IS NULL OR kind = ?) ORDER BY logged_at',
          [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, kind, kind]))
        (
          id: r['id'] as int,
          at: DateTime.fromMillisecondsSinceEpoch(r['logged_at'] as int),
          kind: r['kind'] as String,
          value: (r['value'] as num).toDouble(),
          value2: (r['value2'] as num?)?.toDouble(),
          unit: r['unit'] as String,
        )
    ];

/// "72.5" stays 72.5, "120" stays 120: values are shown exactly as logged.
String exactNumber(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// "120/80 mmHg", "5.6 mmol/L".
String readingText(Reading r) =>
    '${exactNumber(r.value)}${r.value2 == null ? '' : '/${exactNumber(r.value2!)}'} ${r.unit}';
