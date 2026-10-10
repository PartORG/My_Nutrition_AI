import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/tool_call_parser.dart';

void main() {
  const tools = {'log_health', 'search_recipes', 'reply'};
  // Records compare maps by identity, so compare fields.
  void expectCall(String raw, String name, Map<String, dynamic> args) {
    final r = parseToolCall(raw, tools);
    expect(r?.name, name);
    expect(r?.args, args);
  }

  test('canonical JSON', () {
    expectCall('{"name": "search_recipes", "parameters": {"query": "vegan"}}', 'search_recipes', {'query': 'vegan'});
  });

  test('channel markers split every token', () {
    // Exact shape captured from flutter_gemma 1.11.3 + Qwen3 on Linux.
    const raw = '<|channel>thought\n\n<tool<channel|><|channel>thought\n_code<channel|>'
        '<|channel>thought\n><channel|><|channel>thought\n\n{"<channel|>'
        '<|channel>thought\nname<channel|><|channel>thought\n":<channel|>'
        '<|channel>thought\n "reply", "parameters": {"text": "hi"}}<channel|>';
    expectCall(raw, 'reply', {'text': 'hi'});
  });

  test('name: {args} inside fences', () {
    const raw = '```json log_health: {"kind": "glucose", "value": "140"} ```';
    expectCall(raw, 'log_health', {'kind': 'glucose', 'value': '140'});
  });

  test('unknown tool or plain prose gives null', () {
    expect(parseToolCall('{"name": "rm_rf", "parameters": {}}', tools), isNull);
    expect(parseToolCall('Try a lentil soup {with love}!', tools), isNull);
  });
}
