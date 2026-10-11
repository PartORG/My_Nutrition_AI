import 'package:sqlite3/sqlite3.dart';

import 'tools.dart' show languageNames;

/// Recipe steps are translated a few lines at a time: the model replies with at most
/// 256 tokens, and ~300 English characters stay well under that in any of the app's languages.
const translationChunkChars = 300;

/// [instructions] as groups of whole lines (steps), each at most [translationChunkChars]
/// unless a single line is longer.
List<String> translationChunks(String instructions) {
  final chunks = <String>[];
  var current = '';
  for (final line in instructions.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
    if (current.isNotEmpty && current.length + 1 + line.length > translationChunkChars) {
      chunks.add(current);
      current = '';
    }
    current = current.isEmpty ? line : '$current\n$line';
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

String translationPrompt(String language) {
  final name = languageNames[language] ?? 'English';
  return 'Translate the cooking instructions the user sends from English into $name. '
      'Reply with the translation only: no notes, no quotes, no greeting. Keep the line breaks and the '
      'step numbers, and keep every number, unit, temperature and time exactly as written.';
}

String? savedTranslation(Database user, int recipeId, String language) => user.select(
    'SELECT text FROM recipe_translations WHERE recipe_id = ? AND lang = ?', [recipeId, language]).firstOrNull?['text']
    as String?;

void saveTranslation(Database user, int recipeId, String language, String text) => user.execute(
    'INSERT OR REPLACE INTO recipe_translations (recipe_id, lang, text) VALUES (?, ?, ?)', [recipeId, language, text]);
