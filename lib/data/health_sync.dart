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

/// Today's steps; null when sync is off or the platform says nothing.
Future<int?> stepsToday(Database user) async {
  if (!healthSupported || !healthSyncOn(user)) return null;
  try {
    final now = DateTime.now();
    return await _health.getTotalStepsInInterval(DateTime(now.year, now.month, now.day), now);
  } on Object catch (e) {
    debugPrint('health steps: $e');
    return null;
  }
}

/// Today's burnt calories, summed by the platform (Health Connect drops the overlap between
/// apps); stored for the "burnt" ring on Today. True when they changed.
Future<bool> syncActiveKcal(Database user) async {
  if (!healthSupported || !healthSyncOn(user)) return false;
  try {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    Future<double?> sum(HealthDataType type) async {
      try {
        final points = await _health.getHealthIntervalDataFromTypes(
            startDate: start, endDate: now, types: [type], interval: 86400);
        return [
          for (final p in points)
            if (p.value case NumericHealthValue(:final numericValue)) numericValue.toDouble(),
        ].fold<double>(0, (a, b) => a + b);
      } on Object catch (e) {
        debugPrint('health $type: $e'); // e.g. total calories not granted yet
        return null;
      }
    }

    final active = await sum(HealthDataType.ACTIVE_ENERGY_BURNED) ?? 0;
    final total = Platform.isAndroid ? await sum(HealthDataType.TOTAL_CALORIES_BURNED) : null;
    final body = loadBody(user);
    final basal = body == null ? null : basalKcal(body, now: now);
    return storeActiveKcal(user, now, burntKcal(active: active, total: total, basalPerDay: basal, now: now));
  } on Object catch (e) {
    debugPrint('health calories: $e');
    return false;
  }
}

/// The ring's calories: active ones when an app writes them; else what the day's total holds beyond the
/// resting burn so far (Google Fit writes only totals, resting burn included). Without goals (no basal
/// burn known) only active calories count.
// shortcut: the resting burn is our Mifflin-St Jeor, not Health Connect's own; use its BasalMetabolicRate if they drift.
double burntKcal({required double active, double? total, double? basalPerDay, required DateTime now}) {
  if (total == null || basalPerDay == null) return active;
  final dayPart = now.difference(DateTime(now.year, now.month, now.day)).inMinutes / 1440;
  return max(active, total - basalPerDay * dayPart);
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
