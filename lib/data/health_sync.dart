import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:sqlite3/sqlite3.dart';

import 'diary.dart' show activeKcalPref, pref, setPref, storeActiveKcal;
import 'goals.dart' show basalKcal, loadBody;
import 'journal.dart' show logReading;

/// Health Connect (Android) / Apple Health (iOS): the app only READS weight, steps and burnt calories.
/// Nothing is written there, and nothing leaves the phone. On per profile (prefs 'health_sync').
bool healthSyncOn(Database user) => pref(user, 'health_sync') == '1';

/// Android and iOS only; Health Connect must be installed (Android 13 and older: an app from Play).
bool get healthSupported => Platform.isAndroid || Platform.isIOS;

final _health = Health();
// Total calories too: Google Fit writes those to Health Connect, never active ones. Android only (no such type on iOS).
final _types = [
  HealthDataType.WEIGHT,
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  if (Platform.isAndroid) HealthDataType.TOTAL_CALORIES_BURNED,
];

/// Bumped when [_types] grows, so a phone connected before is asked once for the new type.
const _accessVersion = '2';

/// Asks for read access to weight, steps and burnt calories; on success turns sync on and imports weights.
/// False = not granted or not available (Android: Health Connect missing → its Play page opens).
Future<bool> connectHealth(Database user) async {
  if (!healthSupported) return false;
  try {
    await _health.configure();
    if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
      await _health.installHealthConnect();
      return false;
    }
    final ok = await _health.requestAuthorization(_types, permissions: [for (final _ in _types) HealthDataAccess.READ]);
    if (!ok) return false;
    setPref(user, 'health_sync', '1');
    setPref(user, 'health_access', _accessVersion);
    await syncHealthWeights(user);
    return true;
  } on Object catch (e) {
    debugPrint('health connect: $e');
    return false;
  }
}

/// Connected before the app read total calories: asks once for that too (Health Connect shows only
/// what isn't granted yet). Without it the ring stays on active calories.
Future<void> askNewHealthAccess(Database user) async {
  if (!healthSupported || !healthSyncOn(user) || pref(user, 'health_access') == _accessVersion) return;
  setPref(user, 'health_access', _accessVersion);
  try {
    await _health.configure();
    await _health.requestAuthorization(_types, permissions: [for (final _ in _types) HealthDataAccess.READ]);
  } on Object catch (e) {
    debugPrint('health access: $e');
  }
}

/// Turns sync off and forgets today's active calories. On Android
/// the access is revoked too; iOS has no API for that (Settings › Health › Data Access).
Future<void> disconnectHealth(Database user) async {
  setPref(user, 'health_sync', '0');
  setPref(user, activeKcalPref, '');
  if (!healthSupported) return;
  try {
    await _health.revokePermissions();
  } on Object catch (e) {
    debugPrint('health revoke: $e');
  }
}

/// One record from the health app: which app wrote it, the time it covers and its amount (steps, kcal).
typedef HealthRecord = ({String source, DateTime from, DateTime to, double value});

/// Today's records of [type], each with the app that wrote it; empty when unreadable (e.g. not granted yet).
Future<List<HealthRecord>> _recordsToday(HealthDataType type, DateTime start, DateTime now) async {
  try {
    final points = await _health.getHealthDataFromTypes(types: [type], startTime: start, endTime: now);
    return [
      for (final p in points)
        if (p.value case NumericHealthValue(:final numericValue))
          (source: '${p.sourceName}|${p.sourceId}', from: p.dateFrom, to: p.dateTo, value: numericValue.toDouble()),
    ];
  } on Object catch (e) {
    debugPrint('health $type: $e');
    return const [];
  }
}

/// Each app's own records cut to [from, to] (a record cut in two counts in proportion), by app.
Map<String, List<HealthRecord>> _bySource(List<HealthRecord> records, DateTime from, DateTime to) {
  final out = <String, List<HealthRecord>>{};
  for (final r in records) {
    final a = r.from.isBefore(from) ? from : r.from, b = r.to.isAfter(to) ? to : r.to;
    final whole = r.to.difference(r.from).inSeconds;
    if (whole > 0 && !b.isAfter(a)) continue; // outside the day
    final share = whole <= 0 ? 1.0 : b.difference(a).inSeconds / whole;
    (out[r.source] ??= []).add((source: r.source, from: a, to: b, value: r.value * share));
  }
  return out;
}

/// The largest app's own total. Health Connect's combined total counts each minute from one app only (by the
/// priority list in Health Connect), so an app ranked above Google Fit that counted fewer steps hides Fit's;
/// one app's own records don't overlap, so its total counts nothing twice.
double largestSourceTotal(List<HealthRecord> records, DateTime from, DateTime to) => _bySource(records, from, to)
    .values
    .map((rs) => rs.fold(0.0, (sum, r) => sum + r.value))
    .fold(0.0, max);

/// Burnt calories from total-calorie records (Google Fit writes only those, resting burn included, and in batches
/// that trail the clock): per app, its total minus the resting burn for the time its records cover, not for the whole
/// day so far (which, hours behind, went below zero and showed nothing); the largest app.
double activeFromTotals(List<HealthRecord> records, double basalPerDay, DateTime from, DateTime to) {
  var best = 0.0;
  for (final rs in _bySource(records, from, to).values) {
    rs.sort((a, b) => a.from.compareTo(b.from));
    var covered = 0, end = from; // seconds covered by the union of the app's records
    for (final r in rs) {
      final a = r.from.isAfter(end) ? r.from : end;
      if (r.to.isAfter(a)) covered += r.to.difference(a).inSeconds;
      if (r.to.isAfter(end)) end = r.to;
    }
    final kcal = rs.fold(0.0, (sum, r) => sum + r.value);
    best = max(best, kcal - basalPerDay * covered / 86400);
  }
  return best;
}

/// Today's steps: the larger of Health Connect's combined total and the largest app's own ([largestSourceTotal]);
/// null when sync is off or nothing could be read.
Future<int?> stepsToday(Database user) async {
  if (!healthSupported || !healthSyncOn(user)) return null;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  int? combined;
  try {
    combined = await _health.getTotalStepsInInterval(start, now);
  } on Object catch (e) {
    debugPrint('health steps: $e');
  }
  final records = await _recordsToday(HealthDataType.STEPS, start, now);
  if (combined == null && records.isEmpty) return null;
  return max(combined ?? 0, largestSourceTotal(records, start, now).round());
}

/// Today's burnt calories for the "burnt" ring on Today: active calories where an app writes them, else what the
/// total-calorie records hold beyond the resting burn ([activeFromTotals]; without goals no resting burn is known,
/// so only active calories count). True when they changed.
Future<bool> syncActiveKcal(Database user) async {
  if (!healthSupported || !healthSyncOn(user)) return false;
  try {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final active = largestSourceTotal(await _recordsToday(HealthDataType.ACTIVE_ENERGY_BURNED, start, now), start, now);
    final body = loadBody(user);
    final basal = body == null ? null : basalKcal(body, now: now);
    final totals = Platform.isAndroid && basal != null
        ? activeFromTotals(await _recordsToday(HealthDataType.TOTAL_CALORIES_BURNED, start, now), basal, start, now)
        : 0.0;
    return storeActiveKcal(user, now, max(active, totals));
  } on Object catch (e) {
    debugPrint('health calories: $e');
    return false;
  }
}

/// Weights of the last 90 days from the health app into the journal (goals use the latest).
Future<int> syncHealthWeights(Database user) async {
  if (!healthSupported || !healthSyncOn(user)) return 0;
  try {
    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT], startTime: now.subtract(const Duration(days: 90)), endTime: now);
    return importWeights(user, [
      for (final p in points)
        if (p.value case NumericHealthValue(:final numericValue)) (at: p.dateFrom, kg: numericValue.toDouble()),
    ]);
  } on Object catch (e) {
    debugPrint('health weights: $e');
    return 0;
  }
}

/// Adds the weights not already in the journal (same minute = the same reading). Returns how many.
int importWeights(Database user, List<({DateTime at, double kg})> points) {
  var n = 0;
  for (final p in points) {
    if (p.kg < 20 || p.kg > 400) continue; // a scale glitch, not a weight
    final minute = p.at.millisecondsSinceEpoch ~/ 60000;
    if (user.select("SELECT 1 FROM readings WHERE kind = 'weight' AND logged_at / 60000 = ?", [minute]).isNotEmpty) {
      continue;
    }
    logReading(user, 'weight', double.parse(p.kg.toStringAsFixed(1)), 'kg', at: p.at);
    n++;
  }
  return n;
}
