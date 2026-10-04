import 'dart:convert';

/// Pulls a tool call out of raw model text when the plugin's own parser missed
/// it. Small models wrap calls in fences, `<tool_code>` tags or channel markers,
/// or write `name: {args}` instead of `{"name": .., "parameters": ..}`.
({String name, Map<String, dynamic> args})? parseToolCall(
    String raw, Set<String> toolNames) {
  // flutter_gemma 1.11.3 wraps every Qwen3 token as
  // '<|channel>thought\n' + token + '<channel|>'.
  final text = raw.replaceAll(RegExp(r'<\|channel>thought\n?|<channel\|>'), '');

  // {"name": "x", "parameters"|"arguments": {...}}
  for (final obj in _jsonObjects(text)) {
    final name = obj['name'];
    final args = obj['parameters'] ?? obj['arguments'] ?? const {};
    if (name is String && toolNames.contains(name) && args is Map) {
      return (name: name, args: Map<String, dynamic>.from(args));
    }
  }
  // x: {...}  or  x({...})
  for (final m in RegExp(r'\b(\w+)\s*[:(]\s*\{').allMatches(text)) {
    if (!toolNames.contains(m[1])) continue;
    final args = _jsonObjects(text.substring(m.end - 1)).firstOrNull;
    return (name: m[1]!, args: args ?? {});
  }
  return null;
}

/// Every top-level balanced {...} in [text] that decodes to a JSON object.
Iterable<Map<String, dynamic>> _jsonObjects(String text) sync* {
  var depth = 0, start = -1;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '{') {
      if (depth++ == 0) start = i;
    } else if (text[i] == '}' && depth > 0 && --depth == 0) {
      try {
        final v = jsonDecode(text.substring(start, i + 1));
        if (v is Map<String, dynamic>) yield v;
      } on FormatException {
        // not JSON, keep scanning
      }
    }
  }
}
