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

/// One live conversation. Keeping it open is what makes turns fast: the tool
/// declarations are processed once, not on every message (M0: 2.4–4 s vs 8 s).
abstract interface class ChatSession {
  Stream<ModelEvent> sendUser(String text);
  Stream<ModelEvent> sendToolResult(String tool, Map<String, Object?> result);
  Future<void> close();
}

abstract interface class ChatModel {
  /// [replay] seeds the history after the session is recreated.
  Future<ChatSession> open({required String system, required List<Turn> replay});
}
