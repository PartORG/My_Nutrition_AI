// The phone gate before shipping model-first chat (docs/PLAN.md "All nutrients, patterns", 11): the real Agent — the
// model first, the argument checks with one retry, the router as the fallback, the hidden answer check — over the
// routing set in English, Ukrainian, German and French, on the phone.
//
//   flutter test --no-uninstall integration_test/phone_gate_test.dart -d <phone> \
//     --dart-define=MODEL_PATH=/sdcard/Android/data/io.github.partorg.myfoodmind/files/models/gemma-4-E2B-it.litertlm
//
// NUTRI_PATH: nutri.db with its health.db beside it (default: the copy the app installed). LANGS=en,uk limits the set.
// Pass: >= 95 % right tool after check and retry, <= 1 % wrong meals logged. Prints the time of every step.
// Failing it: build with Agent(modelFirst: false) (the router first) until the prompts are fixed.
import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/chat_model.dart';
import 'package:myfoodmind/agent/gemma_chat_model.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/data/diary.dart' show setPref;
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_queries_i18n.dart';
import 'eval_score.dart';

const _path = String.fromEnvironment('MODEL_PATH');
const _nutri = String.fromEnvironment('NUTRI_PATH');
const _langs = String.fromEnvironment('LANGS', defaultValue: 'en,uk,de,fr');
const _backend = String.fromEnvironment('BACKEND', defaultValue: 'gpu');

/// Records what ran: the tools after their check, and the router when it stood in.
class _Recording extends AgentTools {
  _Recording(super.nutri, super.user);
  final ran = <(String, Map<String, dynamic>)>[];
  final routed = <ToolResult>[];

  @override
  ToolResult run(String name, Map<String, dynamic> args, {String said = ''}) {
    ran.add((name, args));
    return super.run(name, args, said: said);
  }

  @override
  ToolResult? route(String said) {
    final r = super.route(said);
    if (r != null) routed.add(r);
    return r;
  }
}

/// Times every model call by what it was: the user's turn, a tool result, a check, a rewrite.
class _Timed implements ChatModel {
  _Timed(this.inner);
  final ChatModel inner;
  final steps = <(String, int)>[];

  @override
  Future<ChatSession> open({required String system, required List<Turn> replay, bool tools = true}) async {
    final sw = Stopwatch()..start();
    final s = await inner.open(system: system, replay: replay, tools: tools);
    steps.add(('open', sw.elapsedMilliseconds));
    return _TimedSession(s, steps);
  }
}

class _TimedSession implements ChatSession {
  _TimedSession(this.inner, this.steps);
  final ChatSession inner;
  final List<(String, int)> steps;

  Stream<ModelEvent> _timed(String kind, Stream<ModelEvent> s) async* {
    final sw = Stopwatch()..start();
    yield* s;
    steps.add((kind, sw.elapsedMilliseconds));
  }

  @override
  Stream<ModelEvent> sendUser(String text) => _timed(
      text.startsWith('[Check] Compare') ? 'check' : text.startsWith('[Check]') ? 'rewrite' : 'turn', inner.sendUser(text));

  @override
  Stream<ModelEvent> sendToolResult(String tool, Map<String, Object?> result) =>
      _timed(result.containsKey('error') ? 'retry' : 'answer', inner.sendToolResult(tool, result));

  @override
  Future<void> stageToolResult(String tool, Map<String, Object?> result) => inner.stageToolResult(tool, result);

  @override
  Future<int> countTokens(String text) => inner.countTokens(text);

  @override
  Future<void> close() => inner.close();
}

/// The tool a router card stands for.
String _routedTool(ToolResult r) => switch (r.card) {
      ConfirmCard(:final title) when title.contains('allergy') || title.contains('diet') => 'set_allergen',
      ConfirmCard(:final title) when title.contains('recipe') => 'recipe',
      ConfirmCard() => 'log_meal',
      NutritionCard() => 'nutrition_status',
      RecipeListCard() => 'search_recipes',
      RecipeCard() => 'recipe',
      _ => 'reply',
    };

Future<List<List<double>>> _embed(List<String> texts) async => [
      for (final t in texts) [for (var i = 0; i < 8; i++) (t.hashCode >> i & 1).toDouble()]
    ];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('phone gate: >= 95 % right tool, <= 1 % wrong meals', () async {
    expect(_path, isNotEmpty, reason: 'pass --dart-define=MODEL_PATH=...');
    await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
    await FlutterEdgeAi.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm).fromFile(_path).install();
    final llm = await FlutterEdgeAi.getActiveModel(
        maxTokens: llmContextTokens, preferredBackend: PreferredBackend.values.byName(_backend));
    final support = await getApplicationSupportDirectory();
    final nutri = openNutriDb(_nutri.isEmpty ? '${support.path}/nutri.db' : _nutri);
    expect(hasHealth(nutri), isTrue, reason: 'health.db must sit beside nutri.db');
    // "Show me recipe 2" needs a list on screen: the first five recipes stand in for the last search.
    final shown = [for (final r in nutri.select('SELECT id FROM recipes ORDER BY id LIMIT 5')) r['id']].join(',');
    final tmp = Directory.systemTemp.createTempSync('gate_');

    final langs = _langs.split(',');
    final set = [...agentQueriesEn, ...agentQueriesI18n].where((e) => langs.contains(e.lang)).toList();
    var right = 0, meals = 0, wrongMeals = 0, retried = 0, rewritten = 0, unverified = 0;
    final misses = <String>[];
    final steps = <String, List<int>>{};
    final perLang = <String, List<int>>{};

    for (final (i, e) in set.indexed) {
      final q = e.q;
      // A fresh profile per query keeps them independent; the app keeps one conversation instead.
      final user = openUserDb('${tmp.path}/user_$i.db');
      final vectors = openVectorsDb('${tmp.path}/vectors_$i.db');
      setPref(user, 'last_recipes', shown);
      final tools = _Recording(nutri, user)..language = e.lang;
      final timed = _Timed(GemmaChatModel(llm));
      final agent = Agent(
        model: timed,
        tools: tools,
        memory: Memory(user, vectors, _embed, nutri: nutri),
        user: user,
        limit: ChatLimit(migrated(sqlite3.openInMemory(), profilesDbMigrations)),
        unlimited: () => true,
        language: e.lang,
      );
      await agent.send(q.q);

      final crisis = agent.items.any((i) => i is CrisisItem);
      final names = {for (final (n, _) in tools.ran) n, for (final r in tools.routed) _routedTool(r)};
      final actual = (
        tool: crisis ? 'crisis' : (names.isEmpty ? 'reply' : names.join('+')),
        args: {for (final (_, a) in tools.ran) ...a},
      );
      final s = score(q, actual);
      final lang = perLang.putIfAbsent(e.lang, () => [0, 0]);
      lang[1]++;
      if (s.tool) {
        right++;
        lang[0]++;
      } else {
        misses.add('  [${e.lang}] want ${q.tool}, got ${actual.tool} ${actual.args}: "${q.q}"');
      }
      // A meal card where none was asked, or one without the food that was said, is a wrong meal.
      final mealCards = [
        for (final c in agent.items.whereType<CardItem>())
          if (c.card case final ConfirmCard m when m.items.isNotEmpty) m
      ];
      meals += mealCards.length;
      final want = q.args['items']?.toLowerCase();
      for (final m in mealCards) {
        if (!q.tool.contains('log_meal') || (want != null && !m.items.any((it) => it.label.toLowerCase().contains(want)))) {
          wrongMeals++;
          misses.add('  [${e.lang}] WRONG MEAL ${m.lines}: "${q.q}"');
        }
      }
      final log = [for (final r in user.select("SELECT text FROM chat_messages WHERE role = 'tool'")) r['text'] as String];
      if (log.any((t) => t.startsWith('check failed'))) retried++;
      if (log.any((t) => t.startsWith('answer check: WRONG'))) rewritten++;
      if (agent.items.any((i) => i is ModelItem && i.check == ReplyCheck.unverified)) unverified++;
      for (final (kind, ms) in timed.steps) {
        (steps[kind] ??= []).add(ms);
      }
      agent.dispose();
      user.close();
      vectors.close();
    }
    await llm.close();
    nutri.close();

    final n = set.length;
    String p(List<int> l, double at) => '${(l..sort())[((l.length - 1) * at).round()]}';
    final report = StringBuffer()
      ..writeln('=== phone gate: model first + checks, ${langs.join('/')} on ${Platform.operatingSystem} ===')
      ..writeln('right tool: $right/$n = ${(100 * right / n).toStringAsFixed(1)} % (need 95)')
      ..writeln('wrong meals: $wrongMeals of $meals meal cards over $n messages = '
          '${(100 * wrongMeals / n).toStringAsFixed(1)} % (need <= 1)')
      ..writeln('per language: ${perLang.entries.map((e) => '${e.key} ${e.value[0]}/${e.value[1]}').join(', ')}')
      ..writeln('argument check retries: $retried · answers rewritten: $rewritten · unverified: $unverified')
      ..writeln('steps (ms, p50/p90): ${steps.entries.map((e) => '${e.key} ${p(e.value, .5)}/${p(e.value, .9)} ×${e.value.length}').join(' · ')}')
      ..writeln('misses:')
      ..writeAll(misses, '\n');
    // ignore: avoid_print
    print(report);
    expect(right / n, greaterThanOrEqualTo(.95));
    expect(wrongMeals / n, lessThanOrEqualTo(.01));
  }, timeout: const Timeout(Duration(hours: 3)));
}
