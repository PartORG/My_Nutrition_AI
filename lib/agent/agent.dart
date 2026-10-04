import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_tools.dart';
import 'chat_limit.dart';
import 'chat_model.dart';
import 'crisis.dart';
import 'memory.dart';
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
  CardItem(this.card);
  final AgentCard card;
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
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

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
  int _sessionChars = 0;

  /// Recreate the conversation before the 4096-token context fills up.
  // ponytail: ~4 chars per token estimate; read the real count if the plugin exposes it.
  static const _maxSessionChars = 3000 * 4;

  /// Tool calls allowed in one turn, so a confused model can't loop forever.
  static const _maxToolCalls = 3;

  /// Shows the stored chat (cards are not stored; their effects are in the logs).
  void loadHistory({int limit = 100}) {
    items
      ..clear()
      ..addAll([
        for (final r in user.select(
            "SELECT role, text FROM chat_messages WHERE role IN ('user', 'model') ORDER BY id DESC LIMIT ?",
            [limit]).reversed)
          r['role'] == 'user' ? UserItem(r['text'] as String) : ModelItem(r['text'] as String)
      ]);
    notifyListeners();
  }

  /// Opens the conversation ahead of the first message (the first prefill of
  /// the tool declarations is the slow part, M0: 7.5 s).
  Future<void> warmUp() async => _session ??= await _open();

  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || busy) return;
    busy = true;
    items.add(UserItem(text));
    notifyListeners();
    try {
      if (isCrisis(text)) {
        items.add(CrisisItem()); // never routed through the model
        return;
      }
      if (!limit.tryConsume(unlimited: unlimited())) {
        items.add(LimitItem(limit.dailyFree));
        return;
      }
      final at = _now();
      final id = _store('user', text, at);
      final vector = await memory.index('chat', id, at, text);
      final context = memory.context(recalls: memory.recall(vector, before: at));

      if (_session == null || _sessionChars > _maxSessionChars) {
        await _session?.close();
        _session = await _open(before: id);
      }
      final prompt = '[Context]\n$context\n[/Context]\n$text';
      _sessionChars += prompt.length;
      await _runTurn(_session!.sendUser(prompt));
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

  Future<void> _runTurn(Stream<ModelEvent> stream) async {
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
      if (reply != null && reply.text.trim().isNotEmpty) {
        _sessionChars += reply.text.length;
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
      final result = tools.run(call.name, call.args);
      // Recorded so a chat can be debugged later ("did it really call save?").
      _store('tool', '${call.name} ${call.args} -> ${result.card is ConfirmCard ? 'confirm card' : result.forModel.keys.join(',')}', _now());
      if (result.card != null) items.add(CardItem(result.card!));
      notifyListeners();
      _sessionChars += result.forModel.toString().length;
      stream = _session!.sendToolResult(call.name, result.forModel);
    }
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

  /// The user tapped ✓ or ✕ on a card. Only ✓ writes.
  Future<void> decide(ConfirmCard card, bool accept) async {
    if (card.accepted != null) return;
    card.accepted = accept;
    if (accept) card.apply();
    notifyListeners();
    if (accept) unawaited(memory.backfill()); // index a logged meal for episodic memory
  }

  Future<ChatSession> _open({int? before}) {
    _sessionChars = 0;
    // Working memory after a restart: the last 6 messages, without their context blocks.
    final rows = user.select(
        "SELECT role, text FROM chat_messages WHERE role IN ('user', 'model') AND id < ? "
        'ORDER BY id DESC LIMIT 6', [before ?? 1 << 62]).reversed;
    return model.open(
      system: agentSystemPrompt,
      replay: [for (final r in rows) (isUser: r['role'] == 'user', text: r['text'] as String)],
    );
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
