/// Cook mode: a recipe's instructions as steps, the timer a step asks for, the ingredients it uses.
library;

/// "1. Preheat oven.\n2. Brown the chicken." → the steps, numbers and "Directions:" headings gone.
/// One paragraph without line breaks is split into sentences, two or three to a step.
List<String> recipeSteps(String instructions) {
  final lines = [
    for (final line in instructions.split('\n'))
      if (line.replaceFirst(RegExp(r'^\s*(?:step\s*)?\d+[.)]\s*', caseSensitive: false), '').trim() case final t
          when t.isNotEmpty && !RegExp(r'^(directions|instructions|method|preparation)\s*:?$', caseSensitive: false).hasMatch(t))
        t
  ];
  if (lines.length > 1) return lines;
  final sentences = [
    for (final s in (lines.firstOrNull ?? '').split(RegExp(r'(?<=[.!?])\s+'))) if (s.trim().isNotEmpty) s.trim()
  ];
  if (sentences.length <= 3) return sentences.isEmpty ? lines : [sentences.join(' ')];
  return [for (var i = 0; i < sentences.length; i += 2) sentences.skip(i).take(2).join(' ')];
}

/// The time a step says to wait ("bake 30 minutes", "simmer 1 hour", "11-14 minutes" → the longer end);
/// null when it names none.
Duration? stepTimer(String step) {
  final m = RegExp(r'(\d+)(?:\s*(?:-|–|to)\s*(\d+))?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b', caseSensitive: false)
      .firstMatch(step);
  if (m == null) return null;
  final n = int.parse(m[2] ?? m[1]!);
  final unit = m[3]!.toLowerCase();
  final d = unit.startsWith('h') ? Duration(hours: n) : unit.startsWith('s') ? Duration(seconds: n) : Duration(minutes: n);
  return d.inSeconds == 0 || d > const Duration(hours: 12) ? null : d;
}

/// The ingredients a step names: an ingredient counts when its main word (the first word of
/// "Lentils, red, raw", or the last of "red lentils") appears in the step.
List<({String name, double grams})> stepIngredients(String step, List<({String name, String english, double grams})> ingredients) {
  final text = step.toLowerCase();
  bool names(String word) {
    final w = word.length > 3 && word.endsWith('s') ? word.substring(0, word.length - 1) : word;
    return w.length > 2 && RegExp('\\b${RegExp.escape(w)}').hasMatch(text);
  }

  return [
    for (final i in ingredients)
      if (_keyWords(i.english).any(names)) (name: i.name, grams: i.grams)
  ];
}

Iterable<String> _keyWords(String english) {
  final head = english.split(',').first.toLowerCase().trim();
  final words = head.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return {if (words.isNotEmpty) words.last, if (words.isNotEmpty) words.first};
}
