import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
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

/// What Gemma saw on a photo: a food name and its estimated portion.
typedef SeenFood = ({String name, double? grams});

const _photoPrompt = 'Look at the whole photo and list every food and drink you can see, one per line, as: grams | name\n'
    'grams = your estimate of the portion shown; name = a short generic English food name, '
    'e.g. "150 | boiled rice" or "120 | grilled chicken breast". A cooked dish is one line; separate items '
    '(fruit, vegetables, cheese, bread, eggs, packages in a fridge or on a table) each get their own line. '
    'Write nothing else. If there is no food, write: none';

/// Photo mode: Gemma 4 looks at [png] and names the foods. Its own session,
/// so the chat's conversation is untouched; inference waits while the chat generates.
Future<List<SeenFood>> nameFoods(InferenceModel model, Uint8List png) async {
  final session = await model.openSession(temperature: 0, topK: 1, enableVisionModality: true, maxOutputTokens: 160);
  try {
    await session.addQueryChunk(Message.withImage(text: _photoPrompt, imageBytes: png, isUser: true));
    return parseSeenFoods(await session.getResponse());
  } finally {
    await session.close();
  }
}

/// "150 | boiled rice" lines → foods; a missing or silly amount → null (a serving).
List<SeenFood> parseSeenFoods(String reply) {
  final seen = <SeenFood>[];
  for (final line in reply.split('\n')) {
    final parts = line.replaceFirst(RegExp(r'^[\s*•-]+'), '').split('|');
    final name = parts.last.trim().toLowerCase();
    if (name.isEmpty || name == 'none') continue;
    final number = parts.length < 2 ? null : RegExp(r'\d+([.,]\d+)?').firstMatch(parts.first)?[0];
    final g = double.tryParse(number?.replaceAll(',', '.') ?? '');
    seen.add((name: name, grams: g != null && g > 0 && g <= 2000 ? g : null));
  }
  return seen.take(12).toList();
}

/// Gemma's foods → review items, matched in nutri.db like typed text.
List<ScanItem> itemsFromSeen(AgentTools tools, List<SeenFood> seen) => [
      for (final s in seen)
        () {
          final food = matchFood(tools, s.name);
          return ScanItem(name: s.name, food: food, grams: s.grams ?? food?.servingG ?? 100);
        }()
    ];

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
