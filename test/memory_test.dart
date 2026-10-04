import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

/// Deterministic stand-in for EmbeddingGemma: bag of words hashed into 64 dims,
/// so texts sharing words are close and unrelated texts are not.
Future<List<List<double>>> fakeEmbed(List<String> texts) async => [
      for (final t in texts)
        () {
          final v = List<double>.filled(64, 0);
          for (final w in RegExp(r'[a-z]+').allMatches(t.toLowerCase())) {
            if (w[0]!.length > 2) v[w[0]!.hashCode % 64] += 1;
          }
          return v;
        }()
    ];

void main() {
  late Directory tmp;
  late Database user, vectors;
  late Memory memory;
  final now = DateTime(2026, 10, 4, 19, 5);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_mem_');
    user = openUserDb('${tmp.path}/user.db');
    vectors = openVectorsDb('${tmp.path}/vectors.db');
    // The bag-of-words fake scores lower than EmbeddingGemma, hence 0.3.
    memory = Memory(user, vectors, fakeEmbed, clock: () => now, minScore: 0.3);
  });
  tearDown(() {
    user.close();
    vectors.close();
    tmp.deleteSync(recursive: true);
  });

  int ms(DateTime t) => t.millisecondsSinceEpoch;
  void chat(String role, String text, DateTime at) => user.execute(
      'INSERT INTO chat_messages (role, text, created_at) VALUES (?, ?, ?)', [role, text, ms(at)]);
  void meal(String description, double? grams, double kcal, DateTime at, [String? type]) => user.execute(
      'INSERT INTO meal_log (eaten_at, meal_type, description, grams, kcal, protein_g, fat_g, carbs_g) '
      'VALUES (?, ?, ?, ?, ?, 10, 5, 20)', [ms(at), type, description, grams, kcal]);

  test('backfill indexes user messages and meals once, never model replies', () async {
    final yesterday = now.subtract(const Duration(days: 1));
    chat('user', 'the lentil soup was too spicy for the kids', yesterday);
    chat('model', 'Sorry to hear that!', yesterday);
    meal('lasagna', 350, 473, yesterday, 'dinner');
    meal('coffee', null, 5, yesterday);
    expect(await memory.backfill(), 3);
    expect(await memory.backfill(), 0, reason: 'already indexed');
    final texts = [for (final r in vectors.select('SELECT text FROM events ORDER BY id')) r['text']];
    expect(texts, ['the lentil soup was too spicy for the kids', 'logged dinner: lasagna 350 g', 'logged coffee']);
  });

  test('recall finds the related past event, skips the live chat and noise', () async {
    final lastWeek = now.subtract(const Duration(days: 6));
    chat('user', 'the lentil soup was too spicy for the kids', lastWeek);
    chat('user', 'I bought a new blender', lastWeek);
    chat('user', 'is the lentil soup spicy?', now); // the live message itself
    await memory.backfill();
    final q = await memory.index('chat', 999, now, 'can I make that lentil soup less spicy?');
    final hits = memory.recall(q, before: now);
    expect(hits.map((h) => h.text).toList(), ['the lentil soup was too spicy for the kids']);
    expect(hits.single.score, greaterThanOrEqualTo(memory.minScore));
  });

  test('context carries today, allergies, facts, habits and recalls', () async {
    user.execute("INSERT INTO user_allergens VALUES ('peanuts', 0)");
    user.execute("INSERT INTO memory_facts (text, created_at) VALUES ('has an air fryer', 0)");
    for (var d = 1; d <= 3; d++) {
      meal('egg', 100, 143, DateTime(2026, 10, 4 - d, 8), 'breakfast');
    }
    meal('banana', 118, 105, DateTime(2026, 10, 4, 10), 'snack');
    meal('banana', 118, 105, DateTime(2026, 10, 3, 10), 'snack');
    final ctx = memory.context(recalls: [
      (at: DateTime(2026, 9, 28), kind: 'chat', text: 'soup too spicy', score: .9),
    ]);
    expect(ctx, contains('Now: Sun 4 Oct, 19:05.'));
    expect(ctx, contains('Eaten today: 105 kcal, 10 g protein, 20 g carbs'));
    expect(ctx, contains('Allergies: peanuts.'));
    expect(ctx, contains('About the user: has an air fryer.'));
    expect(ctx, contains('often eats egg (3x), banana (2x)'));
    expect(ctx, contains('usual times: breakfast ~8:00'));
    expect(ctx, contains('28 Sep chat: "soup too spicy"'));
  });

  test('context shows goals and what is left, for any subset of targets', () {
    meal('banana', 118, 105, now.subtract(const Duration(hours: 2)));
    expect(memory.context(), contains('Daily goals: not set'));
    user.execute("INSERT INTO goal_overrides VALUES ('kcal', 2000)"); // e.g. under 18: manual only
    expect(memory.context(), contains('Daily goals: 2000 kcal. Left today: 1895 kcal.'));
    user.execute("INSERT INTO body VALUES (1, 'male', 1996, 180, 80, 'moderate', 'maintain', 'metric', 0)");
    expect(memory.context(), contains('Daily goals: 2000 kcal, 96 g protein, 387 g carbs, 69 g sugar. '
        'Left today: 1895 kcal, 86 g protein, 367 g carbs, 69 g sugar.'));
  });

  test('forgetting conversations sticks; meals stay remembered', () async {
    final hour = now.subtract(const Duration(hours: 1));
    chat('user', 'hello there friend', hour);
    meal('lasagna', 350, 473, hour, 'dinner');
    await memory.backfill();
    memory.forgetConversations();
    expect(user.select('SELECT 1 FROM chat_messages'), isEmpty);
    expect([for (final r in vectors.select('SELECT kind FROM events')) r['kind']], ['meal']);
    expect(await memory.backfill(), 0, reason: 'nothing to rebuild the chat from');
  });
}
