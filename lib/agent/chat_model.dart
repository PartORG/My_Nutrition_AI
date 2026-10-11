/// What a model turn produces, streamed.
sealed class ModelEvent {}

class TextChunk extends ModelEvent {
  TextChunk(this.text);
  final String text;
}

class ToolCall extends ModelEvent {
  ToolCall(this.name, this.args);
  final String name;
  final Map<String, dynamic> args;
}

typedef Turn = ({bool isUser, String text});

/// The chat model's context window (getActiveModel's maxTokens).
const llmContextTokens = 4096;

/// One live conversation. Keeping it open is what makes turns fast: the tool
/// declarations are processed once, not on every message (M0: 2.4–4 s vs 8 s).
abstract interface class ChatSession {
  Stream<ModelEvent> sendUser(String text);
  Stream<ModelEvent> sendToolResult(String tool, Map<String, Object?> result);

  /// Adds a tool result without a reply: the model reads it with the next user message.
  Future<void> stageToolResult(String tool, Map<String, Object?> result);

  /// [text]'s length in the model's own tokens.
  Future<int> countTokens(String text);
  Future<void> close();
}

abstract interface class ChatModel {
  /// [replay] seeds the history after the session is recreated. [tools] false: a plain
  /// text session (recipe translation), without the agent's tool declarations.
  Future<ChatSession> open({required String system, required List<Turn> replay, bool tools = true});
}
