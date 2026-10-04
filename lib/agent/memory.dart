import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/migrate.dart';

/// Turns texts into vectors (EmbeddingGemma on device, a fake in tests).
typedef Embed = Future<List<List<double>>> Function(List<String> texts);

typedef Recall = ({DateTime at, String kind, String text, double score});

/// `vectors/<id>.db` — episodic memory index. Not backed up: everything in it
/// is derived from user.db and [Memory.backfill] rebuilds it.
const vectorsDbMigrations = <String>[
  '''
  CREATE TABLE events (
    id        INTEGER PRIMARY KEY,
    kind      TEXT NOT NULL,      -- 'chat' | 'meal' | 'scan'
    ref_id    INTEGER NOT NULL,   -- row id in user.db
    at        INTEGER NOT NULL,
    text      TEXT NOT NULL,
    embedding BLOB NOT NULL,      -- float32, unit length
    UNIQUE (kind, ref_id)
  );
  ''',
];

Database openVectorsDb(String path) {
  final db = sqlite3.open(path);
  migrate(db, vectorsDbMigrations);
  return db;
}

/// The four memories: working (the live conversation, kept by the agent),
/// semantic (memory_facts), episodic (vectors.db) and habits (SQL over logs).
class Memory {
  Memory(this.user, this.vectors, this.embed, {DateTime Function()? clock, this.minScore = 0.55})
      : _now = clock ?? DateTime.now;

  final Database user, vectors;
  final Embed embed;
  final DateTime Function() _now;

  /// Below this cosine a past event is noise, not a memory. 0.55 is a guess
  /// for EmbeddingGemma; tune it on real chats.
  final double minScore;

  // ---- episodic -------------------------------------------------------------

  /// Embeds and indexes every user message and logged meal that isn't indexed
  /// yet. Cheap when up to date; rebuilds everything after a backup restore.
  Future<int> backfill() async {
    final rows = [
      for (final r in user.select(
          "SELECT 'chat' AS kind, id, created_at AS at, text FROM chat_messages WHERE role = 'user' "
          "UNION ALL SELECT 'meal', id, eaten_at, "
          // COALESCE: in SQL 'text' || NULL is NULL, which would blank the line.
          "  'logged ' || COALESCE(meal_type || ': ', '') || description "
          "  || COALESCE(' ' || CAST(ROUND(grams) AS INT) || ' g', '') "
          'FROM meal_log'))
        if (vectors.select('SELECT 1 FROM events WHERE kind = ? AND ref_id = ?',
                [r['kind'], r['id']]).isEmpty)
          (kind: r['kind'] as String, id: r['id'] as int, at: r['at'] as int, text: r['text'] as String)
    ];
    // ponytail: one embed call per batch of 16; ~0.6 s per text on the phone.
    for (var i = 0; i < rows.length; i += 16) {
      final batch = rows.skip(i).take(16).toList();
      final vecs = await embed([for (final r in batch) r.text]);
      for (final (j, r) in batch.indexed) {
        _insert(r.kind, r.id, r.at, r.text, vecs[j]);
      }
    }
    return rows.length;
  }

  /// Indexes one event and returns its vector, so a new chat message's vector
  /// is computed once and reused for [recall].
  Future<List<double>> index(String kind, int refId, DateTime at, String text) async {
    final v = (await embed([text])).single;
    _insert(kind, refId, at.millisecondsSinceEpoch, text, v);
    return v;
  }

  void _insert(String kind, int refId, int at, String text, List<double> v) => vectors.execute(
      'INSERT OR IGNORE INTO events (kind, ref_id, at, text, embedding) VALUES (?, ?, ?, ?, ?)',
      [kind, refId, at, text, Float32List.fromList(_unit(v)).buffer.asUint8List()]);

  /// Past events most similar to [query], skipping anything at or after
  /// [before] (the live conversation already holds those).
  List<Recall> recall(List<double> query, {required DateTime before, int k = 3}) {
    final q = _unit(query);
    final scored = <Recall>[];
    // ponytail: brute force over all events; fine for years of one person's chat.
    for (final r in vectors.select('SELECT kind, at, text, embedding FROM events WHERE at < ?',
        [before.millisecondsSinceEpoch])) {
      final v = (r['embedding'] as Uint8List).buffer.asFloat32List();
      var s = 0.0;
      for (var i = 0; i < q.length; i++) {
        s += q[i] * v[i];
      }
      if (s >= minScore) {
        scored.add((at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int), kind: r['kind'] as String,
            text: r['text'] as String, score: s));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).toList();
  }

  /// Deletes the chat history and the episodic memory built from it. Logged
  /// meals, facts and allergies stay. (Wiping only the index would not stick:
  /// [backfill] rebuilds it from chat_messages.)
  void forgetConversations() {
    vectors.execute("DELETE FROM events WHERE kind = 'chat'");
    user.execute('DELETE FROM chat_messages');
  }

  // ---- semantic memory, editable on the "What the AI knows" screen ----------

  List<({int id, String text})> facts() => [
        for (final r in user.select('SELECT id, text FROM memory_facts ORDER BY id DESC'))
          (id: r['id'] as int, text: r['text'] as String)
      ];

  void updateFact(int id, String text) =>
      user.execute('UPDATE memory_facts SET text = ? WHERE id = ?', [text.trim(), id]);

  void deleteFact(int id) => user.execute('DELETE FROM memory_facts WHERE id = ?', [id]);

  List<String> allergies() =>
      [for (final r in user.select('SELECT allergen FROM user_allergens ORDER BY 1')) r['allergen'] as String];

  void removeAllergy(String allergen) =>
      user.execute('DELETE FROM user_allergens WHERE allergen = ?', [allergen]);

  int conversationCount() =>
      user.select("SELECT COUNT(*) AS n FROM chat_messages WHERE role = 'user'").single['n'] as int;

  /// The habits line of [context], for the "What the AI knows" screen.
  String? habits() => _habits(_now());

  // ---- context for each message ------------------------------------------

  /// The short block put in front of every user message: what is true right
  /// now, from the databases — never from the model's memory of the chat.
  String context({List<Recall> recalls = const []}) {
    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final today = user.select(
        'SELECT COUNT(*) AS n, TOTAL(kcal) AS kcal, TOTAL(protein_g) AS p, TOTAL(carbs_g) AS c, '
        'TOTAL(sugar_g) AS s FROM meal_log WHERE eaten_at >= ?', [dayStart]).single;
    final allergens = [for (final r in user.select('SELECT allergen FROM user_allergens ORDER BY 1')) r['allergen']];
    final facts = [
      for (final r in user.select('SELECT text FROM memory_facts ORDER BY id DESC LIMIT 15')) r['text']
    ];
    final lines = [
      'Now: ${DateFormat('EEE d MMM, HH:mm').format(now)}.',
      'Eaten today: ${(today['kcal'] as num).round()} kcal, ${(today['p'] as num).round()} g protein, '
          '${(today['c'] as num).round()} g carbs, ${(today['s'] as num).round()} g sugar '
          '(${today['n']} items). Goals: not set yet.',
      'Allergies: ${allergens.isEmpty ? 'none recorded' : allergens.join(', ')}.',
      if (facts.isNotEmpty) 'About the user: ${facts.join('; ')}.',
      ?_habits(now),
      if (recalls.isNotEmpty)
        'Related past events: ${recalls.map((r) => '${DateFormat('d MMM').format(r.at)} ${r.kind}: "${r.text}"').join(' | ')}',
    ];
    return lines.join('\n');
  }

  String? _habits(DateTime now) {
    final since = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final top = [
      for (final r in user.select(
          'SELECT description, COUNT(*) AS n FROM meal_log WHERE eaten_at >= ? '
          'GROUP BY description HAVING n >= 2 ORDER BY n DESC LIMIT 5', [since]))
        '${r['description']} (${r['n']}x)'
    ];
    final saved = [for (final r in user.select('SELECT title FROM saved_recipes ORDER BY saved_at DESC LIMIT 5')) r['title']];
    final times = [
      for (final r in user.select(
          "SELECT meal_type, AVG(CAST(strftime('%H', eaten_at / 1000, 'unixepoch', 'localtime') AS INT)) AS h "
          'FROM meal_log WHERE eaten_at >= ? AND meal_type IS NOT NULL GROUP BY meal_type HAVING COUNT(*) >= 3',
          [since]))
        '${r['meal_type']} ~${(r['h'] as num).round()}:00'
    ];
    final parts = [
      if (top.isNotEmpty) 'often eats ${top.join(', ')}',
      if (saved.isNotEmpty) 'saved recipes: ${saved.join(', ')}',
      if (times.isNotEmpty) 'usual times: ${times.join(', ')}',
    ];
    return parts.isEmpty ? null : 'Habits (30 days): ${parts.join('; ')}.';
  }
}

List<double> _unit(List<double> v) {
  var n = 0.0;
  for (final x in v) {
    n += x * x;
  }
  n = sqrt(n);
  return n == 0 ? v : [for (final x in v) x / n];
}
