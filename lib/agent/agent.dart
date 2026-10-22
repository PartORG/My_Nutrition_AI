import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/diary.dart' show lastMealId, undoMealsAfter;
import 'agent_tools.dart';
import 'chat_limit.dart';
import 'chat_model.dart';
import 'crisis.dart';
import 'memory.dart';
import 'recipe_translation.dart';
import 'tool_call_parser.dart';
import 'tools.dart';

/// One row of the chat as the UI shows it.
sealed class ChatItem {}

class UserItem extends ChatItem {
  UserItem(this.text);
  final String text;
}

class ModelItem extends ChatItem {
  ModelItem([this.text = '']);
  String text; // grows while streaming

  /// The hidden second pass over this answer (docs/PLAN.md "All nutrients, patterns", 10).
  ReplyCheck check = ReplyCheck.none;
}

/// none: not checked (a replayed message); checking: "checking…"; verified: ✓; unverified: the text is hidden,
/// "couldn't verify this answer".
enum ReplyCheck { none, checking, verified, unverified }

class CardItem extends ChatItem {
  CardItem(this.card, {this.caption = false});
  final AgentCard card;

  /// Shown without a model reply: the UI puts a short translated line above it.
  final bool caption;
}

/// Shown instead of calling the model.
class CrisisItem extends ChatItem {}

class LimitItem extends ChatItem {
  LimitItem(this.dailyFree);
  final int dailyFree;
}

class ErrorItem extends ChatItem {}

/// The chat loop: crisis filter → daily limit → memory → model ⇄ tools.
class Agent extends ChangeNotifier {
  Agent({
    required this.model,
    required this.tools,
    required this.memory,
    required this.user,
    required this.limit,
    required this.unlimited,
    this.onWrite,
    this.language = 'en',
    this.modelFirst = true,
    this.checkAnswers = true,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// The model decides every message, the router is its fallback (decision 9). False puts the router first again:
  /// the phone gate (decision 11) failed.
  final bool modelFirst;

  /// Every text answer gets a hidden check turn (decision 10).
  final bool checkAnswers;

  /// Called after the user confirms a write, so other screens can refresh.
  final VoidCallback? onWrite;

  /// The app's language code: the model answers in it.
  final String language;

  final ChatModel model;
  final AgentTools tools;
  final Memory memory;
  final Database user;
  final ChatLimit limit;

  /// Paid tier? Read on every message so an upgrade applies at once.
  final bool Function() unlimited;
  final DateTime Function() _now;

  final items = <ChatItem>[];
  bool busy = false;

  ChatSession? _session;

  /// Tokens the live conversation holds, counted with the model's tokenizer:
  /// system prompt, tool declarations, replayed history and every turn since.
  int _sessionTokens = 0;

  /// Room kept free for one turn's output: up to 3 rounds of tool calls, their results and
  /// a reply of at most 256 tokens (1024 with thinking). The conversation is recreated before it runs out.
  // shortcut: thinking's room is a guess, not measured on the phone; check agent_latency_test before shipping it.
  static const _turnRoom = agentThinking ? 2048 : 1024;

  /// Context lines as the live conversation last saw them, by label ("Eaten today"):
  /// a message carries only the lines that changed since.
  final _sentContext = <String, String>{};

  /// Rounds of tool calls allowed in one turn, so a confused model can't loop forever.
  static const _maxToolCalls = 3;

  static final _toolNames = {for (final t in agentTools) t.name};

  /// Each day is a new chat: earlier days stay stored on the phone and come back
  /// through episodic memory ("what did I cook yesterday?"), not in the window.
  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The day the live conversation and [items] belong to.
  DateTime? _day;

  /// Shows today's stored chat (cards are not stored; their effects are in the logs).
  void loadHistory({int limit = 100}) {
    _day = _today();
    items
      ..clear()
      ..addAll([
        for (final r in user.select(
            "SELECT role, text FROM chat_messages WHERE role IN ('user', 'model') AND created_at >= ? "
            'ORDER BY id DESC LIMIT ?',
            [_day!.millisecondsSinceEpoch, limit]).reversed)
          r['role'] == 'user' ? UserItem(r['text'] as String) : ModelItem(r['text'] as String)
      ]);
    notifyListeners();
  }

  /// Recipe steps in the app's [language], streamed as they're written, then saved so each
  /// recipe is translated once. One model runs one conversation at a time on a phone (two
  /// sessions risk running out of memory), so this waits for no chat turn: it returns at once
  /// when [busy], and otherwise closes the chat, which reopens with its history next message.
  Stream<String> translateRecipe(int recipeId, String instructions) async* {
    if (savedTranslation(user, recipeId, language) case final saved?) {
      yield saved;
      return;
    }
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await _session?.close();
      _session = null;
      var done = '';
      for (final chunk in translationChunks(instructions)) {
        final session = await model.open(system: translationPrompt(language), replay: const [], tools: false);
        try {
          var part = '';
          await for (final e in session.sendUser(chunk)) {
            if (e is TextChunk) {
              part += e.text;
              yield done.isEmpty ? part.trim() : '$done\n${part.trim()}';
            }
          }
          done = done.isEmpty ? part.trim() : '$done\n${part.trim()}';
        } finally {
          await session.close();
        }
      }
      saveTranslation(user, recipeId, language, done); // only a complete one: leaving the screen cancels
      yield done;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Opens the conversation ahead of the first message (the first prefill of
  /// the tool declarations is the slow part, M0: 7.5 s).
  Future<void> warmUp() => _warming ??= () async {
        _session ??= await _open();
      }();
  Future<void>? _warming;

  /// Photo and voice hand the model pictures and sound, which it takes only in its one main conversation
  /// (flutter_edge_ai rejects media on `openSession`), and opening that one ends the chat's. Waits for a warm-up or
  /// turn in flight; the chat reopens with its history next message, as after [translateRecipe].
  Future<void> release() async {
    await _warming?.then((_) {}, onError: (_) {});
    while (busy) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _session?.close();
    _session = null;
  }

  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || busy) return;
    busy = true;
    if (_day != null && _day != _today()) {
      // Past midnight with the chat open: a new day's chat.
      items.clear();
      await _session?.close();
      _session = null;
    }
    _day = _today();
    items.add(UserItem(text));
    notifyListeners();
    try {
      if (isCrisis(text)) {
        items.add(CrisisItem()); // never routed through the model
        return;
      }
      if ((modelFirst ? null : tools.route(text)) case final routed?) {
        // Plain "I ate…" / "I'm allergic to…": the card at once, no model, not counted.
        final at = _now();
        final id = _store('user', text, at);
        _store('tool', 'routed -> ${routed.forModel}', at);
        items.add(CardItem(routed.card!, caption: true));
        unawaited(memory.index('chat', id, at, text).then((_) {}, onError: (Object e) => debugPrint('index: $e')));
        return;
      }
      if (!limit.tryConsume(unlimited: unlimited())) {
        items.add(LimitItem(limit.dailyFree));
        return;
      }
      final at = _now();
      final id = _store('user', text, at);
      // Embedding costs ~0.8 s on the phone's CPU: wait for it only when the message
      // points at the past; otherwise it indexes while the model runs.
      final vector = memory.index('chat', id, at, text);
      unawaited(vector.then((_) {}, onError: (Object e) => debugPrint('index: $e')));
      final recalls = refersToPast(text) ? memory.recall(await vector, before: at) : const <Recall>[];
      final context = memory.context(recalls: recalls);

      _session ??= await _open(before: id);
      var prompt = _prompt(context, text);
      var size = await _session!.countTokens(prompt);
      if (_sessionTokens + size + _turnRoom > llmContextTokens) {
        await _session!.close();
        _session = null;
        _session = await _open(before: id);
        prompt = _prompt(context, text); // the new conversation gets the whole block
        size = await _session!.countTokens(prompt);
      }
      _sessionTokens += size;
      final turn = await _runTurn(_session!.sendUser(prompt), text);
      // The model wrote no call where the router sees one ("I ate 2 eggs" answered "Enjoy!"): the router's card.
      // Not when it only asked something back ("How many eggs?"): that is the right answer. A question after a claim
      // ("I've saved your dinner. Anything else?") is not: the card is the only way the meal gets saved.
      final said = turn.reply?.text.trim() ?? '';
      final asked = said.endsWith('?') && !RegExp(r'[.!]\s').hasMatch(said);
      if ((modelFirst && !turn.called && !asked ? tools.route(text) : null) case final routed?) {
        _store('tool', 'fallback router -> ${routed.forModel}', _now());
        items.add(CardItem(routed.card!, caption: turn.reply == null));
      }
      if ((checkAnswers ? turn.reply : null) case final reply?) await _check(reply, turn.storedId!);
    } catch (e, st) {
      debugPrint('agent error: $e\n$st');
      items.add(ErrorItem());
      await _session?.close();
      _session = null; // start clean next time
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// One turn: model text and tool rounds. [reply] is the last text the user sees (and [storedId] its chat row);
  /// [called] whether any tool ran.
  Future<({ModelItem? reply, int? storedId, bool called})> _runTurn(Stream<ModelEvent> stream, String said) async {
    ModelItem? last;
    int? lastId;
    var called = false, failedChecks = 0;
    for (var round = 0;; round++) {
      ModelItem? reply;
      final calls = <ToolCall>[];
      await for (final e in stream) {
        switch (e) {
          case TextChunk(:final text):
            if (reply == null) items.add(reply = ModelItem());
            reply.text += text;
            notifyListeners();
          case ToolCall():
            calls.add(e); // several when one message asks for several things
        }
      }
      // A call the model wrote as text the plugin couldn't parse: run it, don't show it.
      if (calls.isEmpty && reply != null) {
        if (parseToolCall(reply.text, _toolNames) case (:final name, :final args)) {
          items.remove(reply);
          reply = null;
          calls.add(ToolCall(name, args));
        }
      }
      for (final call in calls) {
        _sessionTokens += await _session!.countTokens('${call.name} ${jsonEncode(call.args)}');
      }
      if (reply != null && reply.text.trim().isNotEmpty) {
        _sessionTokens += await _session!.countTokens(reply.text);
        (last, lastId) = (reply, _store('model', reply.text.trim(), _now()));
      }
      if (calls.isEmpty) return (reply: last, storedId: lastId, called: called);
      if (round >= _maxToolCalls) {
        items.add(ErrorItem()); // still calling tools: a confused model, not an answer
        return (reply: null, storedId: null, called: called);
      }
      // Model first: the arguments must hold against the user's words. One retry with the reason, then the router.
      final problems = [for (final call in calls) modelFirst ? tools.checkCall(call.name, call.args, said) : null];
      if (problems.nonNulls.isNotEmpty) {
        _store('tool', 'check failed: ${[for (final (i, c) in calls.indexed) if (problems[i] != null) '${c.name} '
            '${problems[i]}']}', _now());
        if (++failedChecks > 1) {
          // Its words went with the wrong call ("I'll log the bacon"): gone from the screen and the replay.
          if (last != null) {
            items.remove(last);
            user.execute('DELETE FROM chat_messages WHERE id = ?', [lastId]);
          }
          if (tools.route(said) case final routed?) {
            items.add(CardItem(routed.card!, caption: true));
            await _session!.stageToolResult(calls.last.name, routed.forModel);
            return (reply: null, storedId: null, called: true);
          }
          items.add(ErrorItem());
          return (reply: null, storedId: null, called: called);
        }
        final answers = [
          for (final problem in problems)
            problem == null
                ? {'status': 'not run: another call failed the check; call it again if still needed'}
                : {'error': 'checked against the user\'s words: $problem. Call it again with only what the user '
                      'said, or ask them'},
        ];
        for (var i = 0; i < calls.length - 1; i++) {
          await _session!.stageToolResult(calls[i].name, answers[i]);
        }
        stream = _session!.sendToolResult(calls.last.name, answers.last);
        continue;
      }
      called = true;
      final results = [for (final call in calls) (call: call, result: tools.run(call.name, call.args, said: said))];
      final saidAll = results.every((r) => _cardSaysItAll(r.call.name, r.result));
      for (final (:call, :result) in results) {
        // Recorded so a chat can be debugged later ("did it really call save?").
        _store('tool', '${call.name} ${call.args} -> ${result.card is ConfirmCard ? 'confirm card' : result.forModel.keys.join(',')}', _now());
        _sessionTokens += await _session!.countTokens(result.forModel.toString());
        // No second model pass when the cards say it all (M0: a written answer costs seconds); a fixed line instead.
        if (result.card != null) items.add(CardItem(result.card!, caption: saidAll));
      }
      notifyListeners();
      final lastResult = results.removeLast();
      for (final (:call, :result) in results) {
        await _session!.stageToolResult(call.name, result.forModel);
      }
      if (saidAll) {
        await _session!.stageToolResult(lastResult.call.name, lastResult.result.forModel);
        // The text before the calls ("Let me log that") isn't the answer to check: the cards are.
        return (reply: null, storedId: null, called: true);
      }
      stream = _session!.sendToolResult(lastResult.call.name, lastResult.result.forModel);
    }
  }

  static const _checkPrompt = '[Check] Compare your last answer with the [Context] block and the tool results above. '
      'Is every number, food, recipe and claim in it backed by them or by general knowledge, and does it answer the '
      'user? Reply only OK, or WRONG: and the reason in a few words.';

  /// The hidden second pass (decision 10), in the same conversation: OK → ✓; WRONG → written again once with the
  /// reason; WRONG again → the text is hidden ("couldn't verify"), the cards stay. Not counted as a message.
  Future<void> _check(ModelItem reply, int storedId) async {
    reply.check = ReplyCheck.checking;
    notifyListeners();
    for (var attempt = 0;; attempt++) {
      final wrong = await _verdict();
      if (wrong == null) {
        reply.check = ReplyCheck.verified;
        user.execute('UPDATE chat_messages SET text = ? WHERE id = ?', [reply.text.trim(), storedId]);
        break;
      }
      _store('tool', 'answer check: WRONG: $wrong', _now());
      if (attempt == 1) {
        reply.check = ReplyCheck.unverified;
        user.execute('DELETE FROM chat_messages WHERE id = ?', [storedId]); // never replayed as if it were right
        break;
      }
      final prompt = "[Check] Your last answer was wrong: $wrong. Write the answer to the user's message again, "
          'correctly, in the same language, without calling tools.';
      _sessionTokens += await _session!.countTokens(prompt);
      reply.text = '';
      notifyListeners();
      await for (final e in _session!.sendUser(prompt)) {
        if (e is TextChunk) {
          reply.text += e.text;
          notifyListeners();
        }
      }
      _sessionTokens += await _session!.countTokens(reply.text);
    }
    notifyListeners();
  }

  /// The check turn's verdict: null = OK (anything but WRONG: a check that rambles hides no answer), else the reason.
  Future<String?> _verdict() async {
    _sessionTokens += await _session!.countTokens(_checkPrompt);
    var out = '';
    await for (final e in _session!.sendUser(_checkPrompt)) {
      if (e is TextChunk) out += e.text;
    }
    _sessionTokens += await _session!.countTokens(out);
    final m = RegExp(r'^\W*WRONG\W*(.*)', caseSensitive: false, dotAll: true).firstMatch(out.trim());
    return m == null ? null : (m[1]!.trim().isEmpty ? 'not backed by the facts' : m[1]!.trim());
  }

  /// The card shows everything the reply would say. The model still answers after
  /// condition_info (it summarises passages), errors, empty results and notes it must pass on.
  static bool _cardSaysItAll(String tool, ToolResult r) =>
      r.card != null &&
      tool != 'condition_info' &&
      !r.forModel.keys.any(const {'error', 'not_found', 'caution', 'repeated'}.contains);

  /// A tap on a recipe in a list: opens exactly that recipe, no model, not counted.
  void showRecipe(int recipeId) {
    items.add(CardItem(tools.showRecipeById(recipeId).card!));
    notifyListeners();
  }

  /// "What can I cook?" from the camera review: recipes for what was seen,
  /// no model, not counted. False when nothing matches.
  bool cookWith(List<String> ingredients) {
    final card = tools.run('search_recipes', {'query': '', 'ingredients': ingredients.join(', ')}).card;
    if (card == null) return false;
    items.add(CardItem(card));
    notifyListeners();
    return true;
  }

  /// A photo from the chat's camera: its meal card, to check and save. No model, not counted.
  void addPhoto(ConfirmCard card) {
    items.add(CardItem(card, caption: true));
    notifyListeners();
  }

  /// "I ate this" on a recipe card: straight to a ✓ card, no model, not counted.
  void ateRecipe(int recipeId) {
    items.add(CardItem(tools.logRecipe(recipeId).card!));
    notifyListeners();
  }

  /// "Forget past conversations": history, episodic memory, and the live
  /// conversation the model still holds in its context.
  Future<void> forgetConversations() async {
    memory.forgetConversations();
    await _session?.close();
    _session = null;
    items.clear();
    notifyListeners();
  }

  /// The user picked another meal on a meal card before saving.
  void setMealType(ConfirmCard card, String mealType) {
    if (card.accepted != null) return;
    card.mealType = mealType;
    notifyListeners();
  }

  /// The user changed an amount on a meal card before saving.
  void setGrams(ConfirmCard card, MealItem item, double grams) {
    if (card.accepted != null) return;
    item.grams = grams < 0 ? 0 : grams;
    notifyListeners();
  }

  /// The user swapped a food on a meal card for one they picked; null [food] removes the item.
  void setFood(ConfirmCard card, MealItem item, FoodChoice? food) {
    if (card.accepted != null) return;
    if (food == null) {
      card.items.remove(item);
    } else {
      final f = MealItem.of(food, grams: food.servingG ?? item.grams);
      item
        ..food = food
        ..corrected = item.seen != null
        ..check = false
        ..label = f.label
        ..grams = f.grams
        ..per100 = f.per100
        ..estimated = f.estimated
        ..recipeId = f.recipeId
        ..servingG = f.servingG;
    }
    notifyListeners();
  }

  /// "+ Add food" on a meal card.
  void addFood(ConfirmCard card, FoodChoice food) {
    if (card.accepted != null) return;
    card.items.add(MealItem.of(food));
    notifyListeners();
  }

  /// The user tapped ✓ or ✕ on a card. Only ✓ writes.
  Future<void> decide(ConfirmCard card, bool accept) async {
    if (card.accepted != null) return;
    card.accepted = accept;
    if (accept) {
      if (card.items.isNotEmpty) card.undoFrom = lastMealId(user);
      card.apply();
      onWrite?.call();
    }
    notifyListeners();
    if (accept) unawaited(memory.backfill()); // index a logged meal for episodic memory
  }

  /// Undo on a saved meal card: the meals its Save added are deleted.
  void undo(ConfirmCard card) {
    final from = card.undoFrom;
    if (from == null || card.undone) return;
    undoMealsAfter(user, from);
    card.undone = true;
    onWrite?.call();
    notifyListeners();
  }

  Future<ChatSession> _open({int? before}) async {
    // Working memory after a restart: today's last 6 messages, without their context blocks.
    final rows = user.select(
        "SELECT role, text FROM chat_messages WHERE role IN ('user', 'model') AND id < ? AND created_at >= ? "
        'ORDER BY id DESC LIMIT 6', [before ?? 1 << 62, _today().millisecondsSinceEpoch]).reversed;
    final replay = [for (final r in rows) (isUser: r['role'] == 'user', text: r['text'] as String)];
    final session = await model.open(system: agentSystemPrompt(language), replay: replay);
    _sentContext.clear();
    // ponytail: the declarations as JSON, not as the chat template renders them; _turnRoom covers the gap.
    _sessionTokens = await session.countTokens([
      agentSystemPrompt(language),
      jsonEncode([for (final t in agentTools) {'name': t.name, 'description': t.description, 'parameters': t.parameters}]),
      for (final t in replay) t.text,
    ].join('\n'));
    return session;
  }

  /// The user's message after the context lines the conversation hasn't seen yet.
  String _prompt(String context, String text) {
    final fresh = [
      for (final line in context.split('\n'))
        if (_sentContext[line.split(':').first] != line) line
    ];
    for (final line in fresh) {
      _sentContext[line.split(':').first] = line;
    }
    return fresh.isEmpty ? text : '[Context]\n${fresh.join('\n')}\n[/Context]\n$text';
  }

  int _store(String role, String text, DateTime at) {
    user.execute('INSERT INTO chat_messages (role, text, created_at) VALUES (?, ?, ?)',
        [role, text, at.millisecondsSinceEpoch]);
    return user.lastInsertRowId;
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }
}
