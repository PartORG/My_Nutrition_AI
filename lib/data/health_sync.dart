import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:sqlite3/sqlite3.dart';

import 'diary.dart' show activeKcalPref, pref, setPref, storeActiveKcal;
import 'journal.dart' show logReading;

/// Health Connect (Android) / Apple Health (iOS): the app only READS weight, steps and active calories.
/// Nothing is written there, and nothing leaves the phone. On per profile (prefs 'health_sync').
bool healthSyncOn(Database user) => pref(user, 'health_sync') == '1';

/// Android and iOS only; Health Connect must be installed (Android 13 and older: an app from Play).
bool get healthSupported => Platform.isAndroid || Platform.isIOS;

final _health = Health();
const _types = [HealthDataType.WEIGHT, HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];

/// Asks for read access to weight, steps and active calories; on success turns sync on and imports weights.
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
    await syncHealthWeights(user);
    return true;
  } on Object catch (e) {
    debugPrint('health connect: $e');
    return false;
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

/// Today's active calories, summed by the platform (Health Connect drops the overlap between
/// apps); stored for the "burnt" ring on Today. True when they changed.
Future<bool> syncActiveKcal(Database user) async {
  if (!healthSupported || !healthSyncOn(user)) return false;
  try {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final points = await _health.getHealthIntervalDataFromTypes(
        startDate: start, endDate: now, types: [HealthDataType.ACTIVE_ENERGY_BURNED], interval: 86400);
    final kcal = [
      for (final p in points)
        if (p.value case NumericHealthValue(:final numericValue)) numericValue.toDouble(),
    ].fold(0.0, (a, b) => a + b);
    return storeActiveKcal(user, now, kcal);
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
