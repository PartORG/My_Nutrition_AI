import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqlite3/sqlite3.dart';

import 'agent/agent_tools.dart' show nutrients;
import 'data/conditions.dart';
import 'data/diary.dart';
import 'data/journal.dart';
import 'l10n/app_localizations.dart';

/// Medium: the doctor export. What the user logged, as logged — the report
/// states values and the user's own limits, never what they mean.

/// The [days] local days ending today: [from, to).
(DateTime, DateTime) reportRange(DateTime now, int days) =>
    (DateTime(now.year, now.month, now.day - days + 1), DateTime(now.year, now.month, now.day + 1));

/// Every meal, reading and symptom in the range, oldest first, one per row.
String reportCsv(Database user, {required DateTime now, required int days}) {
  final (from, to) = reportRange(now, days);
  final rows = <(DateTime, List<Object?>)>[
    for (final r in user.select(
        'SELECT * FROM meal_log WHERE eaten_at >= ? AND eaten_at < ?',
        [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]))
      (
        DateTime.fromMillisecondsSinceEpoch(r['eaten_at'] as int),
        ['meal', r['meal_type'], r['description'], null, null, null, r['grams'], for (final n in nutrients) r[n],
            r['estimated'] == 1 ? 'yes' : 'no'],
      ),
    for (final r in readingsBetween(user, from, to))
      (r.at, ['reading', r.kind, null, r.value, r.value2, r.unit]),
    for (final s in symptomsBetween(user, from, to))
      (s.at, ['symptom', null, s.symptom, s.severity, null, s.severity == null ? null : '1-5']),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final header = ['date', 'time', 'record', 'type', 'item', 'value', 'value2', 'unit', 'grams', ...nutrients,
      'estimated'];
  final date = DateFormat('yyyy-MM-dd'), time = DateFormat('HH:mm');
  return [
    header.join(','),
    for (final (at, cells) in rows)
      [date.format(at), time.format(at), ...cells, ...List.filled(header.length - 2 - cells.length, null)]
          .map(_csvCell)
          .join(','),
  ].join('\r\n');
}

String _csvCell(Object? v) {
  if (v == null) return '';
  if (v is num) return v is double ? exactNumber(double.parse(v.toStringAsFixed(2))) : '$v';
  var s = '$v';
  // A doctor opens this in a spreadsheet: text the user typed must not run as a formula.
  if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
  return RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// A readable report: conditions and their limits, daily nutrition, readings,
/// symptoms. [regular]/[bold] embed Noto Sans so any script the user typed prints.
Future<Uint8List> reportPdf(
  Database user,
  Database nutri, {
  required String name,
  required DateTime now,
  required int days,
  required AppLocalizations l,
  required pw.Font regular,
  required pw.Font bold,
  required String Function(String condition) conditionName,
  required Map<String, String> nutrientNames,
}) {
  final (from, to) = reportRange(now, days);
  final dateFmt = DateFormat('d MMM yyyy'), dayFmt = DateFormat('EEE d MMM'), atFmt = DateFormat('d MMM HH:mm');
  final conditions = myConditions(user);
  final limits = conditionLimits(nutri, user);
  final logged = dailyTotals(user, now, days).where((d) => d.entries > 0).toList();
  final readings = readingsBetween(user, from, to);
  final symptoms = symptomsBetween(user, from, to);
  final kindNames = {'glucose': l.glucose, 'blood_pressure': l.bloodPressure, 'weight': l.weightTrend};
  const shown = ['kcal', 'protein_g', 'carbs_g', 'sugar_g', 'fat_g', 'fiber_g', 'sodium_mg'];

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 13)),
      );
  pw.Widget table(List<String> header, List<List<String>> rows) => rows.isEmpty
      ? pw.Text(l.reportNone)
      : pw.TableHelper.fromTextArray(
          headers: header,
          data: rows,
          headerStyle: pw.TextStyle(font: bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
        );

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    footer: (c) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
    ),
    build: (_) => [
      pw.Text(l.reportTitle(name), style: pw.TextStyle(font: bold, fontSize: 18)),
      pw.Text('${dateFmt.format(from)} – ${dateFmt.format(to.subtract(const Duration(days: 1)))} · '
          '${l.reportCreated(dateFmt.format(now))}'),
      pw.SizedBox(height: 6),
      pw.Text(l.reportDisclaimer, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      heading(l.conditionsTitle),
      pw.Text(conditions.isEmpty ? l.reportNone : conditions.map((c) => conditionName(c.name)).join(', ')),
      for (final MapEntry(key: k, value: v) in limits.entries)
        pw.Text(l.limitLine(nutrientNames[k]!, '${exactNumber(v.max)} ${_unit(k)}', conditionName(v.condition))),
      heading(l.reportDailyNutrition(logged.length)),
      table(
        [l.reportDate, for (final k in shown) '${nutrientNames[k]!} (${_unit(k)})', l.reportItems],
        [
          for (final d in logged)
            [dayFmt.format(d.day), for (final k in shown) '${d.totals[k]!.round()}', '${d.entries}']
        ],
      ),
      heading(l.readingsTitle),
      table([l.reportDate, l.reportMeasurement, l.reportValue],
          [for (final r in readings) [atFmt.format(r.at), kindNames[r.kind] ?? r.kind, readingText(r)]]),
      heading(l.symptomsTitle),
      table([l.reportDate, l.symptom, l.severity],
          [for (final s in symptoms) [atFmt.format(s.at), s.symptom, s.severity == null ? '' : '${s.severity}/5']]),
    ],
  ));
  return doc.save();
}

String _unit(String nutrient) => switch (nutrient) { 'kcal' => 'kcal', 'sodium_mg' => 'mg', _ => 'g' };
