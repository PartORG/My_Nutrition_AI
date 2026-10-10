import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'chat_model.dart';
import 'tools.dart';

/// [ChatModel] on Gemma 4 E2B via flutter_edge_ai (native tool calling, M0).
class GemmaChatModel implements ChatModel {
  GemmaChatModel(this.model);
  final InferenceModel model;

  @override
  Future<ChatSession> open({required String system, required List<Turn> replay}) async {
    final chat = await model.createChat(
      temperature: 0, // M0 accuracy was measured greedy
      topK: 1,
      tools: agentTools,
      supportsFunctionCalls: true,
      modelType: ModelType.gemma4,
      systemInstruction: system,
      maxOutputTokens: 256,
    );
    for (final t in replay) {
      await chat.addQueryChunk(Message.text(text: t.text, isUser: t.isUser));
    }
    return _GemmaSession(chat);
  }
}

class _GemmaSession implements ChatSession {
  _GemmaSession(this.chat);
  final InferenceChat chat;

  @override
  Stream<ModelEvent> sendUser(String text) async* {
    await chat.addQueryChunk(Message.text(text: text, isUser: true));
    yield* _generate();
  }

  @override
  Stream<ModelEvent> sendToolResult(String tool, Map<String, Object?> result) async* {
    await chat.addQueryChunk(Message.toolResponse(toolName: tool, response: result));
    yield* _generate();
  }

  // flutter_edge_ai stages chunks until the next generate, which sends the result as text
  // ahead of the user's message; a model-role reply can't be added between turns.
  @override
  Future<void> stageToolResult(String tool, Map<String, Object?> result) =>
      chat.addQueryChunk(Message.toolResponse(toolName: tool, response: result));

  @override
  Future<int> countTokens(String text) => chat.session.sizeInTokens(text);

  Stream<ModelEvent> _generate() async* {
    await for (final r in chat.generateChatResponseAsync()) {
      switch (r) {
        case TextResponse(:final token):
          yield TextChunk(token);
        case FunctionCallResponse(:final name, :final args):
          yield ToolCall(name, args);
        case ParallelFunctionCallResponse(:final calls) when calls.isNotEmpty:
          yield ToolCall(calls.first.name, calls.first.args);
        default: // thinking, etc.
      }
    }
  }

  @override
  Future<void> close() => chat.close();
}
