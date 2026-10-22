import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/chat_model.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/agent/recipe_translation.dart';
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
  final systems = <String>[];
  final sent = <String>[];
  final toolResults = <(String, Map<String, Object?>)>[];

  /// The verdicts for the hidden answer checks, in order; OK when it runs out.
  final checks = <String>[];
  final checkPrompts = <String>[];
  bool fail = false;

  @override
  Future<ChatSession> open({required String system, required List<Turn> replay, bool tools = true}) async {
    opens.add(replay);
    systems.add(system);
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
    if (text.startsWith('[Check] Compare')) {
      m.checkPrompts.add(text);
      return Stream.value(TextChunk(m.checks.isEmpty ? 'OK' : m.checks.removeAt(0)));
    }
    m.sent.add(text);
    return _next();
  }

  @override
  Stream<ModelEvent> sendToolResult(String tool, Map<String, Object?> result) {
    m.toolResults.add((tool, result));
    return _next();
  }

  @override
  Future<int> countTokens(String text) async => (text.length / 4).ceil();

  @override
  Future<void> stageToolResult(String tool, Map<String, Object?> result) async => m.toolResults.add((tool, result));

  @override
  Future<void> close() async {}
}

void main() {
  late Directory tmp;
  late Database nutri, user, vectors, profilesDb;
  late FakeModel model;
  late Agent agent;
  var paid = false;

  Agent makeAgent({String language = 'en', bool modelFirst = true, bool check = true}) => Agent(
        model: model,
        tools: AgentTools(nutri, user, clock: () => DateTime(2026, 10, 4, 8)),
        memory: Memory(user, vectors, fakeEmbed, clock: () => DateTime(2026, 10, 4, 8)),
        user: user,
        limit: ChatLimit(profilesDb, clock: () => DateTime(2026, 10, 4, 8)),
        unlimited: () => paid,
        clock: () => DateTime(2026, 10, 4, 8),
        language: language,
        modelFirst: modelFirst,
        checkAnswers: check,
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_agent_');
    nutri = openNutriDb('test/nutri_test.db');
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

  test('log meal: tool → captioned card, no second model pass; ✓ writes', () async {
    model.script.addAll([
      [ToolCall('log_meal', {'items': '2 eggs', 'meal_type': 'breakfast'})],
      [TextChunk('never generated')],
    ]);
    await agent.send('Breakfast was 2 eggs');

    expect(agent.items.map((i) => i.runtimeType), [UserItem, CardItem]);
    expect((agent.items.last as CardItem).caption, isTrue);
    // Staged for the model's next turn, so it knows the card is waiting for Save.
    expect(model.toolResults.single.$2['status'], contains('NOT saved'));
    expect(model.script.length, 1, reason: 'the follow-up was not generated');
    expect(meals(), 0);

    final card = (agent.items[1] as CardItem).card as ConfirmCard;
    await agent.decide(card, true);
    await agent.decide(card, false); // a second tap changes nothing
    expect(meals(), 1);
    expect(card.accepted, isTrue);
  });

  test('meal card: a wrong food is swapped, an item removed, one added; Undo takes the save back', () async {
    model.script.add([ToolCall('log_meal', {'items': '2 eggs and an apple', 'meal_type': 'breakfast'})]);
    await agent.send('Breakfast was 2 eggs and an apple');
    final card = (agent.items[1] as CardItem).card as ConfirmCard;
    final banana = agent.tools.searchFood('banana').first;
    agent.setFood(card, card.items.first, banana);
    expect(card.items.first.label, banana.label);
    expect(card.items.first.grams, banana.servingG ?? 100);
    if (card.items.length > 1) agent.setFood(card, card.items.last, null);
    agent.addFood(card, agent.tools.searchFood('broccoli').first);
    expect(card.items.map((i) => i.label), [banana.label, contains('roccoli')]);
    await agent.decide(card, true);
    expect([for (final r in user.select('SELECT description FROM meal_log ORDER BY id')) r['description']],
        [banana.label, contains('roccoli')]);
    agent.undo(card);
    agent.undo(card); // a second tap changes nothing
    expect(meals(), 0);
    expect(card.undone, isTrue);
  });

  test('router first (the phone gate failed): plain "I ate…" and "I\'m allergic to…" skip the model and the count',
      () async {
    agent = makeAgent(modelFirst: false);
    await agent.send('I ate 2 eggs and a banana for breakfast');
    await agent.send("I'm allergic to peanuts");
    expect(model.sent, isEmpty);
    final cards = [for (final i in agent.items) if (i is CardItem) i.card as ConfirmCard];
    expect(cards.map((c) => c.title), ['Log breakfast', 'Add allergy']);
    expect(cards[0].lines.length, 2);
    expect(cards[1].lines, ['peanuts']);
    expect(agent.items.whereType<CardItem>().every((c) => c.caption), isTrue, reason: 'a fixed line, no model');
    expect(ChatLimit(profilesDb, clock: () => DateTime(2026, 10, 4, 8)).usedToday, 0);

    // Questions and unknown foods still go to the model.
    await agent.send('I ate a dragonfruit smoothie');
    await agent.send('Did I eat enough protein?');
    expect(model.sent.length, 2);
  });

  test('tool calls are recorded in the chat log, but not shown or replayed', () async {
    model.script.addAll([
      [ToolCall('recipe', {'action': 'save', 'recipe': 'shakshuka'})],
    ]);
    await agent.send('bookmark the shakshuka');
    final roles = [for (final r in user.select('SELECT role FROM chat_messages ORDER BY id')) r['role']];
    expect(roles, ['user', 'tool']);
    expect(user.select("SELECT text FROM chat_messages WHERE role = 'tool'").single['text'],
        'recipe {action: save, recipe: shakshuka} -> confirm card');
    agent.loadHistory();
    expect(agent.items.map((i) => i.runtimeType), [UserItem]);
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
    model.script.add([ToolCall('search_recipes', {'query': 'breakfast', 'ingredients': 'egg, oats, lentils'})]);
    await agent.send('something for breakfast'); // "ideas" would skip the model (the router)
    final list = (agent.items.whereType<CardItem>().last.card as RecipeListCard).recipes;
    agent.showRecipe(list[1].id); // tap on the second one
    expect((agent.items.last as CardItem).card, isA<RecipeCard>());
    expect(((agent.items.last as CardItem).card as RecipeCard).title, list[1].title);
    expect(model.sent.length, 1, reason: 'the tap did not go through the model');
    model.script.add([ToolCall('recipe', {'action': 'save', 'recipe': 'it'})]);
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
    expect(model.sent.single, contains('Allergies and diet: peanuts.'));
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

  test('recipe steps: whole lines per chunk, streamed, saved once, the chat reopens after', () async {
    final steps = [for (var i = 1; i <= 6; i++) '$i. ${'Stir the pot gently. ' * 4}'.trim()].join('\n');
    final chunks = translationChunks(steps);
    expect(chunks.length, greaterThan(1));
    expect(chunks.every((c) => c.length <= translationChunkChars), isTrue);
    expect(chunks.join('\n'), steps, reason: 'nothing lost or split mid-line');

    final uk = makeAgent(language: 'uk');
    await uk.warmUp(); // a live chat session
    model.script.addAll([for (var i = 0; i < chunks.length; i++) [TextChunk('Крок '), TextChunk('$i')]]);
    final seen = await uk.translateRecipe(4, steps).toList();
    final full = [for (var i = 0; i < chunks.length; i++) 'Крок $i'].join('\n');
    expect(seen.last, full);
    expect(seen.length, greaterThan(chunks.length), reason: 'streamed token by token');
    expect(model.systems.skip(1).every((s) => s.contains('into Ukrainian')), isTrue);
    expect(savedTranslation(user, 4, 'uk'), full);
    expect(uk.busy, isFalse);

    final opens = model.opens.length;
    expect(await uk.translateRecipe(4, steps).toList(), [full], reason: 'saved: no model call');
    expect(model.opens.length, opens);
    await uk.send('hello');
    expect(model.opens.length, opens + 1, reason: 'the chat session was closed for the translation');

    uk.busy = true;
    expect(await uk.translateRecipe(5, steps).toList(), isEmpty, reason: 'never while the chat runs');
  });

  test('free tier stops at 30 messages a day; paid tier does not', () async {
    for (var i = 0; i < 30; i++) {
      await agent.send('message $i');
    }
    await agent.send('one more');
    expect(agent.items.last, isA<LimitItem>());
    expect(model.sent.length, 30);
    paid = true;
    await agent.send('now unlimited');
    expect(model.sent.length, 31);
  });

  test('a general question is answered in plain text; a looping model is cut off with an error', () async {
    model.script.add([TextChunk('Canberra '), TextChunk('is the capital.')]);
    await agent.send('What is the capital of Australia?');
    expect((agent.items.last as ModelItem).text, 'Canberra is the capital.');

    // Errors go back to the model (cards don't), so a confused model could loop.
    model.script.addAll(List.generate(10, (_) => [ToolCall('lookup_nutrition', {'food': 'unicorn'})]));
    await agent.send('unicorn?');
    expect(model.toolResults.length, 3);
    expect(agent.items.last, isA<ErrorItem>(), reason: 'never silence');
    expect(agent.busy, isFalse);
  });

  test('two requests in one message: both tools run, results go back together', () async {
    model.script.addAll([
      [ToolCall('log_meal', {'items': '2 eggs'}), ToolCall('lookup_nutrition', {'food': 'unicorn'})],
      [TextChunk('Tap Save for the eggs; I found nothing on unicorns.')],
    ]);
    await agent.send('Breakfast was 2 eggs, and how much protein is in a unicorn?');
    expect(agent.items.whereType<CardItem>().single.caption, isFalse, reason: 'the model still speaks');
    expect([for (final r in model.toolResults) r.$1], ['log_meal', 'lookup_nutrition']);
    expect((agent.items.last as ModelItem).text, contains('Tap Save'));
  });

  test('a tool call written as text runs instead of being shown', () async {
    model.script.addAll([
      [TextChunk('```json\n{"name": "remember_fact", "parameters": {"fact": "hates olives"}}\n```')],
    ]);
    await agent.send('Olives are disgusting');
    expect(agent.items.whereType<ModelItem>(), isEmpty);
    expect(agent.items.last, isA<CardItem>());
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

  test('release hands the model over after the warm-up; the next message reopens the chat', () async {
    final warming = agent.warmUp();
    await agent.release(); // photo or voice: waits for the warm-up, then closes it
    await warming;
    expect(model.opens.length, 1);
    await agent.send('Hi');
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

  test('each day is a new chat: yesterday is stored but neither shown nor replayed', () async {
    var now = DateTime(2026, 10, 4, 22);
    final day = Agent(
      model: model,
      tools: AgentTools(nutri, user, clock: () => now),
      memory: Memory(user, vectors, fakeEmbed, clock: () => now),
      user: user,
      limit: ChatLimit(profilesDb, clock: () => now),
      unlimited: () => true,
      clock: () => now,
    )..loadHistory();
    await day.send('message yesterday');
    now = DateTime(2026, 10, 5, 7);
    await day.send('good morning');
    expect(day.items.whereType<UserItem>().map((i) => i.text), ['good morning'], reason: 'open past midnight');
    expect(model.opens.last, isEmpty, reason: 'the new day\'s conversation starts clean');
    day.loadHistory();
    expect(day.items.whereType<UserItem>().map((i) => i.text), ['good morning']);
    expect(user.select("SELECT COUNT(*) AS n FROM chat_messages WHERE role = 'user'").single['n'], 2);
  });

  test('later messages carry only the context lines that changed', () async {
    await agent.send('Hi!');
    await agent.send('Hi again');
    expect(model.sent[1], 'Hi again', reason: 'nothing changed (the clock is fixed)');
    user.execute("INSERT INTO user_allergens VALUES ('peanuts', 0)");
    await agent.send('ok');
    expect(model.sent[2], '[Context]\nAllergies and diet: peanuts.\n[/Context]\nok');
  });

  test('the conversation is recreated, with the whole context, before its tokens run out', () async {
    agent = makeAgent(check: false); // the check turns spend tokens too: counted in the next test
    await agent.send('Hi!');
    final long = List.filled(800, 'word').join(' '); // ~1k tokens at 4 chars per token
    await agent.send(long);
    expect(model.opens.length, 1);
    await agent.send(long);
    expect(model.opens.length, 2);
    expect(model.sent.last, startsWith('[Context]\nNow: '));
  });

  group('model first (docs/PLAN.md "All nutrients, patterns", 9)', () {
    test('the model is asked first; a call that holds against the words runs, and the message is counted', () async {
      model.script.add([ToolCall('log_meal', {'items': '2 eggs, banana', 'meal_type': 'breakfast'})]);
      await agent.send('I ate 2 eggs and a banana for breakfast');
      expect(model.sent.single, endsWith('I ate 2 eggs and a banana for breakfast'));
      expect((agent.items.whereType<CardItem>().single.card as ConfirmCard).lines.length, 2);
      expect(ChatLimit(profilesDb, clock: () => DateTime(2026, 10, 4, 8)).usedToday, 1);
    });

    test('an invented food or amount goes back once with the reason; the retry runs', () async {
      model.script.addAll([
        [ToolCall('log_meal', {'items': '2 eggs, 200 g bacon'})],
        [ToolCall('log_meal', {'items': '2 eggs'})],
      ]);
      await agent.send('I had 2 eggs');
      expect(model.toolResults.first.$2['error'], contains('did not mention 200 g bacon'));
      final card = agent.items.whereType<CardItem>().single.card as ConfirmCard;
      expect(card.lines, ['egg · 100 g · 143 kcal']);
    });

    test('amounts: digits or number words in any language; an invented one is refused', () {
      final t = AgentTools(nutri, user);
      expect(t.checkCall('log_meal', {'items': '2 eggs'}, 'two eggs please'), isNull);
      expect(t.checkCall('log_meal', {'items': '3 eggs'}, 'я з’їв три яйця'), isNull);
      expect(t.checkCall('log_meal', {'items': '200 g rice'}, 'some rice'), contains('200'));
      expect(t.checkCall('log_health', {'kind': 'weight', 'value': '73 kg'}, 'I weigh 72.5'), contains('73'));
      expect(t.checkCall('recipe', {'action': 'show', 'recipe': '4'}, 'the fourth one'), 'no recipe list was shown');
    });

    test('a food said in another language passes through its aliases', () {
      final t = AgentTools(nutri, user)..language = 'uk';
      final banana = nutri.select(
          "SELECT alias FROM food_aliases WHERE lang = 'uk' AND food_id = (SELECT id FROM foods WHERE name = 'banana')")
          .firstOrNull?['alias'] as String?;
      if (banana != null) expect(t.checkCall('log_meal', {'items': 'banana'}, 'я з’їв $banana'), isNull);
      expect(t.checkCall('log_meal', {'items': 'salmon'}, 'я з’їв банан'), anyOf(isNull, contains('salmon')),
          reason: 'salmon without a Ukrainian alias in the test data cannot be told');
    });

    test('a second failed check falls back to the router', () async {
      model.script.addAll([
        [ToolCall('log_meal', {'items': '300 g bacon'})],
        [ToolCall('log_meal', {'items': '300 g bacon'})],
      ]);
      await agent.send('I ate 2 eggs');
      final card = agent.items.whereType<CardItem>().single;
      expect((card.card as ConfirmCard).lines, ['egg · 100 g · 143 kcal']);
      expect(card.caption, isTrue);
    });

    test('no call where the router sees one: the router card follows the reply, unless the model asked back',
        () async {
      model.script.addAll([
        [TextChunk('Enjoy your eggs!')],
        [TextChunk('How many eggs did you have?')],
      ]);
      await agent.send('I ate 2 eggs');
      expect(agent.items.whereType<CardItem>().length, 1);
      await agent.send('I ate eggs');
      expect(agent.items.whereType<CardItem>().length, 1, reason: 'the question was the right answer');
    });
  });

  group('the answer check (decision 10)', () {
    test('OK: ✓, the check is not counted', () async {
      model.script.add([TextChunk('Spinach has iron.')]);
      await agent.send('Which vegetable has iron?');
      final reply = agent.items.whereType<ModelItem>().single;
      expect(reply.check, ReplyCheck.verified);
      expect(model.checkPrompts.length, 1);
      expect(ChatLimit(profilesDb, clock: () => DateTime(2026, 10, 4, 8)).usedToday, 1);
    });

    test('WRONG once: written again with the reason; the stored text is the new one', () async {
      model.script.addAll([
        [TextChunk('You ate 900 kcal today.')],
        [TextChunk('You have not logged anything today.')],
      ]);
      model.checks.add('WRONG: nothing is logged today');
      await agent.send('How much did I eat today?');
      final reply = agent.items.whereType<ModelItem>().single;
      expect((reply.text, reply.check), ('You have not logged anything today.', ReplyCheck.verified));
      expect(model.sent.last, contains('nothing is logged today'));
      expect(user.select("SELECT text FROM chat_messages WHERE role = 'model'").single['text'],
          'You have not logged anything today.');
    });

    test('WRONG twice: the text is hidden and never replayed; cards stay', () async {
      model.script.addAll([
        [ToolCall('condition_info', {'question': 'diabetes diet'})], // always answered in words, after its card
        [TextChunk('Diabetes is cured by cinnamon.')],
        [TextChunk('Cinnamon cures it.')],
      ]);
      model.checks.addAll(['WRONG: the passages say no such thing', 'WRONG: still not in the passages']);
      await agent.send('What should I eat with diabetes?');
      expect(agent.items.whereType<ModelItem>().single.check, ReplyCheck.unverified);
      expect(agent.items.whereType<CardItem>(), isNotEmpty);
      expect(user.select("SELECT 1 FROM chat_messages WHERE role = 'model'"), isEmpty);
    });
  });
}
