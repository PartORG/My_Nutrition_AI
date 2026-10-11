import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_tools.dart';
import 'chat_limit.dart';
import 'chat_model.dart';
import 'crisis.dart';
import 'memory.dart';
import 'recipe_translation.dart';
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
}

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
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

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

  /// Room kept free for one turn's output: up to 3 tool calls, their results and
  /// a reply of at most 256 tokens. The conversation is recreated before it runs out.
  static const _turnRoom = 1024;

  /// Context lines as the live conversation last saw them, by label ("Eaten today"):
  /// a message carries only the lines that changed since.
  final _sentContext = <String, String>{};

  /// Tool calls allowed in one turn, so a confused model can't loop forever.
  static const _maxToolCalls = 3;

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
  Future<void> warmUp() async => _session ??= await _open();

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
      if (tools.route(text) case final routed?) {
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
      await _runTurn(_session!.sendUser(prompt), text);
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

  Future<void> _runTurn(Stream<ModelEvent> stream, String said) async {
    for (var calls = 0;; calls++) {
      ModelItem? reply;
      ToolCall? call;
      await for (final e in stream) {
        switch (e) {
          case TextChunk(:final text):
            if (reply == null) items.add(reply = ModelItem());
            reply.text += text;
            notifyListeners();
          case ToolCall():
            call = e;
        }
      }
      if (call != null) _sessionTokens += await _session!.countTokens('${call.name} ${jsonEncode(call.args)}');
      if (reply != null && reply.text.trim().isNotEmpty) {
        _sessionTokens += await _session!.countTokens(reply.text);
        _store('model', reply.text.trim(), _now());
      }
      if (call == null) return;
      if (call.name == 'reply' || calls >= _maxToolCalls) {
        final text = '${call.args['text'] ?? ''}'.trim();
        if (text.isNotEmpty) {
          items.add(ModelItem(text));
          _store('model', text, _now());
        }
        return;
      }
      final result = tools.run(call.name, call.args, said: said);
      // Recorded so a chat can be debugged later ("did it really call save?").
      _store('tool', '${call.name} ${call.args} -> ${result.card is ConfirmCard ? 'confirm card' : result.forModel.keys.join(',')}', _now());
      _sessionTokens += await _session!.countTokens(result.forModel.toString());
      if (_cardSaysItAll(call.name, result)) {
        // No second model pass (M0: a written answer costs seconds); a fixed line instead.
        items.add(CardItem(result.card!, caption: true));
        await _session!.stageToolResult(call.name, result.forModel);
        return;
      }
      if (result.card != null) items.add(CardItem(result.card!));
      notifyListeners();
      stream = _session!.sendToolResult(call.name, result.forModel);
    }
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

  /// The user tapped ✓ or ✕ on a card. Only ✓ writes.
  Future<void> decide(ConfirmCard card, bool accept) async {
    if (card.accepted != null) return;
    card.accepted = accept;
    if (accept) {
      card.apply();
      onWrite?.call();
    }
    notifyListeners();
    if (accept) unawaited(memory.backfill()); // index a logged meal for episodic memory
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
