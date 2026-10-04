import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/chat_model.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

import 'memory_test.dart' show fakeEmbed;

/// Plays back one scripted list of events per model call and records what the
/// agent sent, so tests can check prompts and tool results.
class FakeModel implements ChatModel {
  FakeModel(this.script);
  final List<List<ModelEvent>> script;
  final opens = <List<Turn>>[];
  final sent = <String>[];
  final toolResults = <(String, Map<String, Object?>)>[];
  bool fail = false;

  @override
  Future<ChatSession> open({required String system, required List<Turn> replay}) async {
    opens.add(replay);
    return _FakeSession(this);
  }
}

class _FakeSession implements ChatSession {
  _FakeSession(this.m);
  final FakeModel m;

  Stream<ModelEvent> _next() {
    if (m.fail) return Stream.error(StateError('model crashed'));
    return Stream.fromIterable(m.script.isEmpty ? [TextChunk('ok')] : m.script.removeAt(0));
  }

  @override
  Stream<ModelEvent> sendUser(String text) {
    m.sent.add(text);
    return _next();
  }

  @override
  Stream<ModelEvent> sendToolResult(String tool, Map<String, Object?> result) {
    m.toolResults.add((tool, result));
    return _next();
  }

  @override
  Future<void> close() async {}
}

void main() {
  late Directory tmp;
  late Database nutri, user, vectors, profilesDb;
  late FakeModel model;
  late Agent agent;
  var paid = false;

  Agent makeAgent() => Agent(
        model: model,
        tools: AgentTools(nutri, user, clock: () => DateTime(2026, 10, 4, 8)),
        memory: Memory(user, vectors, fakeEmbed, clock: () => DateTime(2026, 10, 4, 8)),
        user: user,
        limit: ChatLimit(profilesDb, clock: () => DateTime(2026, 10, 4, 8)),
        unlimited: () => paid,
        clock: () => DateTime(2026, 10, 4, 8),
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_agent_');
    nutri = openNutriDb('assets/nutri.db');
    user = openUserDb('${tmp.path}/user.db');
    vectors = openVectorsDb('${tmp.path}/vectors.db');
    profilesDb = migrated(sqlite3.openInMemory(), profilesDbMigrations);
    paid = false;
    model = FakeModel([]);
    agent = makeAgent();
  });
  tearDown(() {
    for (final db in [nutri, user, vectors, profilesDb]) {
      db.close();
    }
    tmp.deleteSync(recursive: true);
  });

  int meals() => user.select('SELECT COUNT(*) AS n FROM meal_log').single['n'] as int;

  test('log meal: tool → card → "not saved" to model → reply; ✓ writes', () async {
    model.script.addAll([
      [ToolCall('log_meal', {'items': '2 eggs', 'meal_type': 'breakfast'})],
      [TextChunk('Here is your breakfast, '), TextChunk('please confirm.')],
    ]);
    await agent.send('I had 2 eggs for breakfast');

    expect(agent.items.map((i) => i.runtimeType), [UserItem, CardItem, ModelItem]);
    expect((agent.items.last as ModelItem).text, 'Here is your breakfast, please confirm.');
    expect(model.toolResults.single.$2['status'], contains('NOT saved'));
    expect(meals(), 0);

    final card = (agent.items[1] as CardItem).card as ConfirmCard;
    await agent.decide(card, true);
    await agent.decide(card, false); // a second tap changes nothing
    expect(meals(), 1);
    expect(card.accepted, isTrue);
  });

  test('tool calls are recorded in the chat log, but not shown or replayed', () async {
    model.script.addAll([
      [ToolCall('save_recipe', {'recipe': 'shakshuka'})],
      [TextChunk('Tap Save to bookmark it.')],
    ]);
    await agent.send('bookmark the shakshuka');
    final roles = [for (final r in user.select('SELECT role FROM chat_messages ORDER BY id')) r['role']];
    expect(roles, ['user', 'tool', 'model']);
    expect(user.select("SELECT text FROM chat_messages WHERE role = 'tool'").single['text'],
        'save_recipe {recipe: shakshuka} -> confirm card');
    agent.loadHistory();
    expect(agent.items.map((i) => i.runtimeType), [UserItem, ModelItem]);
  });

  test('"I ate this" adds a ✓ card without the model or the daily count', () async {
    agent.ateRecipe(2);
    final card = agent.items.single as CardItem;
    expect((card.card as ConfirmCard).lines.single, startsWith('Shakshuka · '));
    expect(model.sent, isEmpty);
    expect(ChatLimit(profilesDb).usedToday, 0);
    await agent.decide(card.card as ConfirmCard, true);
    expect(meals(), 1);
  });

  test('tapping a listed recipe opens exactly it, and "save it" then means that one', () async {
    model.script.add([ToolCall('search_recipes', {'query': 'breakfast'})]);
    await agent.send('breakfast ideas');
    final list = (agent.items.whereType<CardItem>().last.card as RecipeListCard).recipes;
    agent.showRecipe(list[1].id); // tap on the second one
    expect((agent.items.last as CardItem).card, isA<RecipeCard>());
    expect(((agent.items.last as CardItem).card as RecipeCard).title, list[1].title);
    expect(model.sent.length, 1, reason: 'the tap did not go through the model');
    model.script.add([ToolCall('save_recipe', {'recipe': 'it'})]);
    await agent.send('save it');
    final save = agent.items.whereType<CardItem>().last.card as ConfirmCard;
    expect(save.lines, [list[1].title]);
  });

  test('✕ writes nothing', () async {
    model.script.add([ToolCall('remember_fact', {'fact': 'hates olives'})]);
    await agent.send('I hate olives');
    final card = agent.items.whereType<CardItem>().single.card as ConfirmCard;
    await agent.decide(card, false);
    expect(user.select('SELECT 1 FROM memory_facts'), isEmpty);
  });

  test('every message carries the database context; history is stored clean', () async {
    user.execute("INSERT INTO user_allergens VALUES ('peanuts', 0)");
    await agent.send('Hi!');
    expect(model.sent.single, startsWith('[Context]\nNow: Sun 4 Oct, 08:00.'));
    expect(model.sent.single, contains('Allergies: peanuts.'));
    expect(model.sent.single, endsWith('[/Context]\nHi!'));
    final stored = [for (final r in user.select('SELECT role, text FROM chat_messages')) '${r['role']}:${r['text']}'];
    expect(stored, ['user:Hi!', 'model:ok']);
  });

  test('crisis messages never reach the model and are not counted', () async {
    await agent.send("I don't want to live anymore");
    expect(agent.items.last, isA<CrisisItem>());
    expect(model.sent, isEmpty);
    expect(ChatLimit(profilesDb, clock: () => DateTime(2026, 10, 4, 8)).usedToday, 0);
    expect(user.select('SELECT 1 FROM chat_messages'), isEmpty);
  });

  test('free tier stops at 15 messages a day; paid tier does not', () async {
    for (var i = 0; i < 15; i++) {
      await agent.send('message $i');
    }
    await agent.send('one more');
    expect(agent.items.last, isA<LimitItem>());
    expect(model.sent.length, 15);
    paid = true;
    await agent.send('now unlimited');
    expect(model.sent.length, 16);
  });

  test('the reply tool shows its text; a looping model is cut off', () async {
    model.script.add([ToolCall('reply', {'text': 'Hello there!'})]);
    await agent.send('Hello');
    expect((agent.items.last as ModelItem).text, 'Hello there!');

    model.script.addAll(List.generate(10, (_) => [ToolCall('lookup_nutrition', {'food': 'banana'})]));
    await agent.send('banana?');
    expect(model.toolResults.length, 3);
    expect(agent.busy, isFalse);
  });

  test('a model error shows an error item and the next message reopens', () async {
    await agent.warmUp();
    model.fail = true;
    await agent.send('Hi');
    expect(agent.items.last, isA<ErrorItem>());
    model.fail = false;
    await agent.send('Hi again');
    expect(model.opens.length, 2);
    expect(agent.items.last, isA<ModelItem>());
  });

  test('a new session replays the last 6 messages without context blocks', () async {
    for (var i = 0; i < 5; i++) {
      await agent.send('message $i');
    }
    final fresh = makeAgent(); // e.g. after the app restarted
    await fresh.send('next');
    final replay = model.opens.last;
    expect(replay.length, 6);
    expect(replay.first, (isUser: true, text: 'message 2'));
    expect(replay.every((t) => !t.text.contains('[Context]')), isTrue);
    fresh.loadHistory();
    expect(fresh.items.length, 12);
  });
}
