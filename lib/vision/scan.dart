import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:sqlite3/sqlite3.dart';

import '../agent/agent_tools.dart';
import 'detector.dart';

/// One line on the review screen. The user can rename (re-match), change the
/// amount or remove it before anything is used.
class ScanItem {
  ScanItem({required this.name, required this.food, required this.grams, this.cooking, this.sure = true});
  String name;
  FoodChoice? food; // null = not in the database; logged only after the user picks a match
  double grams;

  /// How Gemma thinks it was cooked ("fried"); null = not said.
  final String? cooking;

  /// False: only one of Gemma's two looks saw it, or no database row fitted. The review screen says "check this".
  bool sure;

  /// The user picked another food for it on the review screen: remembered for the next photo.
  bool corrected = false;
}

/// Detections → review items: one per label, "3 × banana" = 3 servings. A label in [rows] gets its reviewed
/// nutri.db row (search ranks a gummy first for "strawberry"); "-" there (water) logs nothing.
List<ScanItem> itemsFromDetections(AgentTools tools, List<Detection> found, {Map<String, String> rows = const {}}) {
  final counts = <String, int>{};
  for (final d in found) {
    if (rows[d.label] != '-') counts.update(d.label, (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final MapEntry(key: label, value: n) in counts.entries)
      () {
        final row = rows[label];
        final food = (row == null ? null : tools.named(row)) ?? matchFood(tools, label);
        return ScanItem(name: label, food: food, grams: n * (food?.servingG ?? 100));
      }()
  ];
}

/// What Gemma saw on a photo: a food name, its estimated portion, and how it was cooked.
typedef SeenFood = ({String name, double? grams, String? cooking});

const _photoPrompt = 'Look at the whole photo and list every food and drink you can see, one per line, as: '
    'grams | name | cooking\n'
    'grams = your estimate of the portion shown; name = a short generic English food name; cooking = one of raw, '
    'boiled, steamed, grilled, baked, roasted, fried, stewed, unknown. E.g. "150 | boiled rice | boiled" or '
    '"120 | chicken breast | grilled". For portions: a dinner plate is about 26 cm across, a fork about 19 cm long, '
    'a slice of bread about 30 g. A cooked dish is one line; separate items (fruit, vegetables, cheese, bread, eggs, '
    'sauces, packages in a fridge or on a table) each get their own line. Write nothing else. If there is no food, '
    'write: none';

/// Photo mode: Gemma 4 looks at the whole photo [png] and at a closer [crop] of it (small items show; what both
/// looks see is surer), the names are looked up in nutri.db (the user's own corrections and usual foods first),
/// and Gemma then picks among the closest rows, the photo still in front of it. Pictures go only into the model's
/// main conversation, which ends the chat's: call [Agent.release] first. Nothing is stored.
Future<List<ScanItem>> scanPhoto(InferenceModel model, AgentTools tools, Uint8List png, {Uint8List? crop}) async {
  Future<InferenceModelSession> open() =>
      model.createSession(temperature: 0, topK: 1, enableVisionModality: true, maxOutputTokens: 200);
  List<SeenFood>? close;
  if (crop != null) {
    final session = await open();
    try {
      await session.addQueryChunk(Message.withImage(text: _photoPrompt, imageBytes: crop, isUser: true));
      close = parseSeenFoods(await session.getResponse());
    } finally {
      await session.close();
    }
  }
  final session = await open();
  try {
    await session.addQueryChunk(Message.withImage(text: _photoPrompt, imageBytes: png, isUser: true));
    final items = itemsFromLooks(tools, mergeLooks(parseSeenFoods(await session.getResponse()), close));
    final question = pickQuestion(items);
    if (question != null) {
      await session.addQueryChunk(Message.text(text: question.text, isUser: true));
      applyPicks(items, question.options, parsePicks(await session.getResponse()));
    }
    return [for (final i in items) i.item];
  } finally {
    await session.close();
  }
}

/// "150 | boiled rice | boiled" lines → foods; a missing or silly amount → null (a serving).
List<SeenFood> parseSeenFoods(String reply) {
  final seen = <SeenFood>[];
  for (final line in reply.split('\n')) {
    final parts = line.replaceFirst(RegExp(r'^[\s*•-]+'), '').split('|');
    // "grams | name | cooking", or the older "grams | name", or just a name.
    final name = (parts.length >= 3 ? parts[1] : parts.last).trim().toLowerCase();
    if (name.isEmpty || name == 'none') continue;
    final number = parts.length < 2 ? null : RegExp(r'\d+([.,]\d+)?').firstMatch(parts.first)?[0];
    final g = double.tryParse(number?.replaceAll(',', '.') ?? '');
    final cooking = parts.length >= 3 ? parts[2].trim().toLowerCase() : '';
    seen.add((
      name: name,
      grams: g != null && g > 0 && g <= 2000 ? g : null,
      cooking: cooking.isEmpty || cooking == 'unknown' ? null : cooking,
    ));
  }
  return seen.take(12).toList();
}

/// Words that say how food was made, not what it is: "boiled rice" and "white rice" are both rice.
const _prepWords = {
  'raw', 'boiled', 'steamed', 'grilled', 'baked', 'roasted', 'fried', 'stewed', 'cooked', 'fresh', 'sliced',
  'chopped', 'diced', 'mashed', 'plain', 'white', 'whole', 'pan', 'deep', 'some', 'a', 'of',
};

/// Gemma's two looks name one food in two ways ("boiled rice", "rice"): the same when the words that say
/// what it is (not how it was made) are the same, or one name holds the other.
bool sameFood(String a, String b) {
  Set<String> core(String s) =>
      {for (final w in s.toLowerCase().split(RegExp(r'[^a-zà-ÿ]+'))) if (w.isNotEmpty && !_prepWords.contains(w)) w};
  bool word(String v, String w) => v == w || v == '${w}s' || w == '${v}s' || v == '${w}es' || w == '${v}es';
  bool holds(Set<String> x, Set<String> y) => y.every((w) => x.any((v) => word(v, w)));
  final x = core(a), y = core(b);
  if (x.isEmpty || y.isEmpty) return a.trim().toLowerCase() == b.trim().toLowerCase();
  return holds(x, y) || holds(y, x);
}

/// The whole photo's foods, each sure when the closer look saw it too; foods only the closer look found are
/// added, unsure and without grams (a zoomed picture misleads portions). No closer look: all as sure as before.
List<({SeenFood food, bool sure})> mergeLooks(List<SeenFood> whole, List<SeenFood>? close) => [
      for (final f in whole) (food: f, sure: close == null || close.any((c) => sameFood(f.name, c.name))),
      if (close != null)
        for (final c in close)
          if (!whole.any((f) => sameFood(f.name, c.name))) (food: (name: c.name, grams: null, cooking: c.cooking), sure: false),
    ].take(12).toList();

/// The closer look: around the foods the detector found (a little margin), or the middle of the frame when it
/// found none or they fill most of it. Normalized 0..1, like [Detection.box].
Rect closerLook(List<Rect> found) {
  const middle = Rect.fromLTRB(.2, .2, .8, .8);
  if (found.isEmpty) return middle;
  final all = found.reduce((a, b) => a.expandToInclude(b)).inflate(.05);
  final box = Rect.fromLTRB(all.left.clamp(0, 1), all.top.clamp(0, 1), all.right.clamp(0, 1), all.bottom.clamp(0, 1));
  return box.width * box.height > .6 ? middle : box;
}

/// A seen food with the nutri.db rows it may be, best first: the row the user chose for this name before,
/// then the rows they log most, then the shortest name ("banana" is the food, not "Overnight oats with banana").
/// [servingGrams]: Gemma gave no amount, so the grams are the row's serving and follow a changed row.
typedef ScanMatch = ({ScanItem item, List<FoodChoice> options, bool corrected, bool servingGrams});

List<ScanMatch> itemsFromLooks(AgentTools tools, List<({SeenFood food, bool sure})> looks) => [
      for (final (:food, :sure) in looks)
        () {
          final corrected = correctionFor(tools, food.name);
          final options = corrected != null ? [corrected] : matchOptions(tools, food.name);
          final best = options.firstOrNull;
          return (
            item: ScanItem(name: food.name, food: best, grams: food.grams ?? best?.servingG ?? 100,
                cooking: food.cooking, sure: sure),
            options: options,
            corrected: corrected != null,
            servingGrams: food.grams == null,
          );
        }()
    ];

/// Up to [n] nutri.db rows for [name], marked ≈ (a photo never knows the exact food), usual ones first.
List<FoodChoice> matchOptions(AgentTools tools, String name, {int n = 5}) {
  final found = <String, FoodChoice>{};
  for (final f in tools.searchFood(name, limit: 5)) { // + up to 5 dishes, 5 recipes, 8 products
    found.putIfAbsent(f.label.toLowerCase(), () => f);
  }
  final logged = loggedCounts(tools.user, [for (final f in found.values) f.label]);
  // Ties keep search order (sort isn't stable).
  final options = found.values.indexed.toList()
    ..sort((a, b) => switch ((logged[b.$2.label] ?? 0) - (logged[a.$2.label] ?? 0)) {
          0 => switch (a.$2.label.length - b.$2.label.length) { 0 => a.$1 - b.$1, final d => d },
          final d => d,
        });
  return [
    for (final (_, f) in options.take(n))
      (kind: f.kind, id: f.id, label: f.label, servingG: f.servingG, per100: f.per100, estimated: true),
  ];
}

/// How often each of [labels] was logged (meal_log keeps the food's name).
Map<String, int> loggedCounts(Database user, List<String> labels) => labels.isEmpty
    ? const {}
    : {
        for (final r in user.select(
            'SELECT description, COUNT(*) AS n FROM meal_log WHERE description IN '
            '(${List.filled(labels.length, '?').join(', ')}) GROUP BY description',
            labels))
          r['description'] as String: r['n'] as int,
      };

/// The second question, when some foods have several possible rows: Gemma picks one by letter, the photo still
/// in its context. Null when there is nothing to choose. [options] numbers the foods asked about.
({String text, Map<int, ScanMatch> options})? pickQuestion(List<ScanMatch> items) {
  final asked = [
    for (final m in items)
      if (!m.corrected && m.options.length > 1) m
  ];
  if (asked.isEmpty) return null;
  final text = StringBuffer('Now match each food to the closest entry of a food database. Answer one line per food: '
      'its number and the letter of the entry, e.g. "1 b". If no entry fits, write "1 none". Write nothing else.\n');
  for (final (n, m) in asked.indexed) {
    text.writeln('${n + 1}. ${m.item.name}');
    for (final (k, o) in m.options.indexed) {
      text.writeln('   ${String.fromCharCode(97 + k)}) ${o.label}');
    }
  }
  return (text: text.toString(), options: {for (final (n, m) in asked.indexed) n + 1: m});
}

/// "1 b" / "2. a)" / "3 none" lines → food number → letter index (-1 = none fits).
Map<int, int> parsePicks(String reply) => {
      for (final m in RegExp(r'^\s*(\d+)\W*(none|[a-z])\b', caseSensitive: false, multiLine: true).allMatches(reply))
        int.parse(m[1]!): m[2]!.toLowerCase() == 'none' ? -1 : m[2]!.toLowerCase().codeUnitAt(0) - 97,
    };

/// Gemma's picks onto the items; one it found nothing for keeps the best guess, marked to check.
void applyPicks(List<ScanMatch> items, Map<int, ScanMatch> asked, Map<int, int> picks) {
  for (final MapEntry(key: n, value: m) in asked.entries) {
    final pick = picks[n];
    if (pick == null) continue; // no answer: the best guess stands
    if (pick < 0 || pick >= m.options.length) {
      m.item.sure = false;
      continue;
    }
    final food = m.options[pick];
    m.item
      ..food = food
      ..grams = m.servingGrams ? food.servingG ?? m.item.grams : m.item.grams;
  }
}

/// Cooked in fat, so oil or butter is likely and the photo can't show how much.
bool cookedInFat(String? cooking) => const {'fried', 'roasted', 'sauteed', 'sautéed', 'pan-fried', 'deep-fried'}.contains(cooking);

/// The row the user chose for [seen] on an earlier review screen; null = none, or no longer in nutri.db.
FoodChoice? correctionFor(AgentTools tools, String seen) {
  final r = tools.user.select('SELECT kind, food_id, label FROM food_corrections WHERE seen = ?', [seen.trim().toLowerCase()])
      .firstOrNull;
  if (r == null) return null;
  final f = tools
      .searchFood(r['label'] as String, limit: 20)
      .where((f) => f.kind == r['kind'] && '${f.id}' == r['food_id'])
      .firstOrNull;
  return f == null ? null : (kind: f.kind, id: f.id, label: f.label, servingG: f.servingG, per100: f.per100, estimated: true);
}

/// "Change" on the review screen, kept when the meal is logged: the next photo of [seen] starts from [food].
void rememberCorrection(Database user, String seen, FoodChoice food, {required DateTime at}) => user.execute(
    'INSERT OR REPLACE INTO food_corrections (seen, kind, food_id, label, updated_at) VALUES (?, ?, ?, ?, ?)',
    [seen.trim().toLowerCase(), food.kind, '${food.id}', food.label, at.millisecondsSinceEpoch]);

/// Gemma's foods → review items, matched in nutri.db (corrections and usual foods first), no second question.
List<ScanItem> itemsFromSeen(AgentTools tools, List<SeenFood> seen) =>
    [for (final m in itemsFromLooks(tools, mergeLooks(seen, null))) m.item];

/// Best nutri.db match for a name, marked ≈: a photo never knows the exact food. Usual foods first, then the
/// shortest name: a seen "banana" is the food, not "Overnight oats with banana".
FoodChoice? matchFood(AgentTools tools, String name) => matchOptions(tools, name, n: 1).firstOrNull;

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
