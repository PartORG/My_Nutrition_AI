import 'package:sqlite3/sqlite3.dart';

import '../agent/agent_tools.dart';
import 'detector.dart';

/// One line on the review screen. The user can rename (re-match), change the
/// amount or remove it before anything is used.
class ScanItem {
  ScanItem({required this.name, required this.food, required this.grams});
  String name;
  FoodChoice? food; // null = not in the database; logged only after the user picks a match
  double grams;
}

/// Detections → review items: one per label, "3 × banana" = 3 servings.
List<ScanItem> itemsFromDetections(AgentTools tools, List<Detection> found) {
  final counts = <String, int>{};
  for (final d in found) {
    counts.update(d.label, (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final MapEntry(key: label, value: n) in counts.entries)
      () {
        final food = matchFood(tools, label);
        return ScanItem(name: label, food: food, grams: n * (food?.servingG ?? 100));
      }()
  ];
}

/// Best nutri.db match for a name, marked ≈: a photo never knows the exact food.
/// The shortest name wins: a seen "banana" is the food, not "Overnight oats with banana".
FoodChoice? matchFood(AgentTools tools, String name) {
  final f = tools.searchFood(name, limit: 5).fold<FoodChoice?>(
      null, (best, c) => best == null || c.label.length < best.label.length ? c : best);
  return f == null
      ? null
      : (kind: f.kind, id: f.id, label: f.label, servingG: f.servingG, per100: f.per100, estimated: true);
}

/// "Log this meal": every item with a match, under [mealType]. Pressing the
/// button is the confirmation, as on the Log tab. Returns the items logged.
int logScan(AgentTools tools, List<ScanItem> items, String mealType) {
  var n = 0;
  for (final i in items) {
    if (i.food == null || i.grams <= 0) continue;
    tools.logFood(i.food!, i.grams, mealType);
    n++;
  }
  return n;
}

/// Names for "What can I cook?": the matched food names, else what was seen.
List<String> cookNames(List<ScanItem> items) => [for (final i in items) i.food?.label ?? i.name];

/// Episodic memory gets one line per scan (indexed by Memory.backfill); the photo itself is never kept.
void recordScan(Database user, String mode, List<ScanItem> items, {required DateTime at}) => user.execute(
    'INSERT INTO scans (scanned_at, mode, text) VALUES (?, ?, ?)',
    [at.millisecondsSinceEpoch, mode, [for (final i in items) i.food?.label ?? i.name].join(', ')]);
