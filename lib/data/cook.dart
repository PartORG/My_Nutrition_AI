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

// ---- units: recipe steps in the user's system ------------------------------------------------------------------

enum _Kind { temp, length, weight, volume }

/// A unit after a number, what it measures, its value in the target system's base (°C, cm, g, ml for metric;
/// °F, in, oz, ml for imperial), and the least number it may follow ("350F" is a temperature, "1 C" a cup; "2°C"
/// in a step is a cup someone converted, as no step cooks below 10 degrees).
typedef _Unit = ({String re, _Kind kind, double Function(double) to, double min});

// A number as recipes write it: "1 1/2", "2-1/2", "3/4", "1½", "1.5"; a range "8-10", "2 to 3".
const _n = r'(?:\d+(?:\s+|-))?\d+/\d+|(?:\d+\s*)?[½¼¾⅓⅔⅛]|\d+(?:\.\d+)?';
// Not inside a fraction ("1/2") or a word; "C/140C" is a separator. "3 - 9\" pizzas" is three of them, not a range.
const _start = r'(?<![\w.])(?<!\d/)';
const _to = r'(?:-|\s*–\s*|\s+to\s+)';
const _range = '$_start($_n)(?:$_to($_n))?';
const _inch = r'\s*(?:-|\s)?(?:inch(?:es)?\b|in\.(?!\w)|")';
const _cm = r'\s*(?:-|\s)?(?:cm|centimet(?:er|re)s?)\b';

final List<_Unit> _imperialUnits = [
  (re: r'\s*(?:°|º|˚)\s*F\b|\s*deg(?:rees?|\.)?\s*F(?:ahrenheit)?\b', kind: _Kind.temp, to: (f) => (f - 32) * 5 / 9, min: 10),
  (re: r'\s?F\b', kind: _Kind.temp, to: (f) => (f - 32) * 5 / 9, min: 100),
  // "Preheat oven to 350 degrees": no oven goes past 250 °C, so from 250 it is Fahrenheit.
  (re: r'\s*(?:°|º|˚|degrees?)(?!\s*(?:[CF]\b|Celsius|Fahrenheit))', kind: _Kind.temp, to: (f) => (f - 32) * 5 / 9, min: 250),
  (re: r'\s*-?\s*(?:fl\.?\s*oz\b\.?|fluid\s+ounces?\b)', kind: _Kind.volume, to: (v) => v * 29.57, min: 0),
  (re: r'\s*-?\s*(?:oz\b\.?|ounces?\b)', kind: _Kind.weight, to: (v) => v * 28.35, min: 0),
  (re: r'\s*-?\s*(?:lbs?\b\.?|pounds?\b)', kind: _Kind.weight, to: (v) => v * 453.6, min: 0),
  (re: _inch, kind: _Kind.length, to: (v) => v * 2.54, min: 0),
  (re: r'\s*-?\s*cups?\b', kind: _Kind.volume, to: (v) => v * 240, min: 0),
  (re: r'\s*-?\s*pints?\b', kind: _Kind.volume, to: (v) => v * 473, min: 0),
  (re: r'\s*-?\s*(?:quarts?\b|qts?\b\.?)', kind: _Kind.volume, to: (v) => v * 946, min: 0),
  (re: r'\s*-?\s*gallons?\b', kind: _Kind.volume, to: (v) => v * 3785, min: 0),
];

final List<_Unit> _metricUnits = [
  (re: r'\s*(?:°|º|˚)\s*C\b|\s*deg(?:rees?|\.)?\s*C(?:elsius)?\b', kind: _Kind.temp, to: (c) => c * 9 / 5 + 32, min: 10),
  (re: r'\s?C\b', kind: _Kind.temp, to: (c) => c * 9 / 5 + 32, min: 100),
  (re: r'\s*(?:kg|kilos?|kilograms?)\b', kind: _Kind.weight, to: (v) => v * 35.274, min: 0),
  // shortcut: under 20 g stays grams ("total fat 3g" in a step's nutrition note is not an ounce question).
  (re: r'\s*(?:g|gr|grams?)\b', kind: _Kind.weight, to: (v) => v / 28.35, min: 20),
  (re: r'\s*(?:ml|millilit(?:er|re)s?)\b', kind: _Kind.volume, to: (v) => v, min: 0),
  (re: r'\s*(?:l|lit(?:er|re)s?)\b', kind: _Kind.volume, to: (v) => v * 1000, min: 0),
  (re: _cm, kind: _Kind.length, to: (v) => v / 2.54, min: 0),
  (re: r'\s*(?:-|\s)?(?:mm|millimet(?:er|re)s?)\b', kind: _Kind.length, to: (v) => v / 25.4, min: 0),
];

/// Recipe text in the user's units: "Bake at 350°F in a 9x13 inch pan" → "Bake at 175°C in a 23 x 33 cm pan" for
/// [imperial] false, and the other way round for true. Spoons stay (both systems cook with them); a step that
/// already gives both ("375°F (190°C)") keeps its own figure.
String unitsFor(String text, {required bool imperial}) {
  final from = imperial ? _metricUnits : _imperialUnits, into = imperial ? _imperialUnits : _metricUnits;
  String any(List<_Unit> units) => '(?:$_n)(?:$_to(?:$_n))?(?:${units.map((u) => u.re).join('|')})';
  // Both given ("375°F (190°C)", "325°F/160°C"): the figure already in the user's units, whichever comes first.
  text = text
      .replaceAllMapped(RegExp('$_start${any(from)}\\s*\\((\\s*${any(into)}[^()]*)\\)', caseSensitive: false), (m) => m[1]!.trim())
      .replaceAllMapped(RegExp('$_start(${any(into)})\\s*\\(\\s*${any(from)}[^()]*\\)', caseSensitive: false), (m) => m[1]!)
      .replaceAllMapped(RegExp('$_start${any(from)}\\s*/\\s*(${any(into)})', caseSensitive: false), (m) => m[1]!)
      .replaceAllMapped(RegExp('$_start(${any(into)})\\s*/\\s*${any(from)}', caseSensitive: false), (m) => m[1]!);
  // "9x13 inch", "13 x 9\"": each side, the unit once.
  final side = r'(\d+(?:\.\d+)?)\s*(?:x|×|by)\s*';
  text = text.replaceAllMapped(
      RegExp('$_start$side(\\d+(?:\\.\\d+)?)(?:\\s*(?:x|×|by)\\s*(\\d+(?:\\.\\d+)?))?(?:${imperial ? _cm : _inch})',
          caseSensitive: false), (m) {
    final sides = [m[1], m[2], m[3]].nonNulls.map((s) => double.parse(s) * (imperial ? 1 / 2.54 : 2.54));
    return '${sides.map((v) => _plain((v / (imperial ? .5 : 1)).round() * (imperial ? .5 : 1))).join(' x ')} '
        '${imperial ? 'in' : 'cm'}';
  });
  for (final u in from) {
    text = text.replaceAllMapped(RegExp('$_range(?:${u.re})', caseSensitive: false), (m) {
      final a = _value(m[1]!), b = m[2] == null ? null : _value(m[2]!);
      // "3/4°C Parmigiano" is a cup written as C: temperatures come whole.
      if (a == null || a < u.min || (m[2] != null && b == null) || (u.kind == _Kind.temp && a % 1 != 0)) return m[0]!;
      return _say(u.kind, u.to(a), b == null ? null : u.to(b), imperial);
    });
  }
  // "1/2 cup (4 fl oz)" gave the same figure twice.
  return text.replaceAllMapped(RegExp(r'(\d[\d./ –]*\s?(?:°[CF]|[a-zA-Z]+(?: oz)?))\s*\(\1\)'), (m) => m[1]!);
}

/// "1 1/2" → 1.5, "1½" → 1.5, "3/4" → 0.75; null for "1/0".
double? _value(String s) {
  const glyphs = {'½': .5, '¼': .25, '¾': .75, '⅓': 1 / 3, '⅔': 2 / 3, '⅛': .125};
  var total = 0.0;
  for (final m in RegExp(r'(\d+)/(\d+)|\d+(?:\.\d+)?|[½¼¾⅓⅔⅛]').allMatches(s)) {
    if (m[1] != null) {
      final d = int.parse(m[2]!);
      if (d == 0) return null;
      total += int.parse(m[1]!) / d;
    } else {
      total += glyphs[m[0]] ?? double.parse(m[0]!);
    }
  }
  return total;
}

/// [a] (to [b]) in the target base, as a cook writes it: "175°C", "23 cm", "450 g", "1.4 kg", "1 1/2 cups".
String _say(_Kind kind, double a, double? b, bool imperial) {
  final top = b ?? a;
  double r(double v, double step) => (v / step).round() * step;
  String two(String Function(double) f, String unit) => '${f(a)}${b == null ? '' : '–${f(b)}'}$unit';
  return switch ((kind, imperial)) {
    (_Kind.temp, false) => two((v) => _plain(r(v, 5)), '°C'),
    (_Kind.temp, true) => two((v) => _plain(r(v, 5)), '°F'),
    (_Kind.length, false) => top < 1
        ? two((v) => _plain(r(v * 10, 1)), ' mm')
        : two((v) => _plain(r(v, top < 5 ? .5 : 1)), ' cm'),
    (_Kind.length, true) => two((v) => top < 5 ? _quarters(r(v, .25)) : _plain(r(v, 1)), ' in'),
    (_Kind.weight, false) => top >= 1000
        ? two((v) => _plain(r(v / 1000, .1)), ' kg')
        : two((v) => _plain(r(v, 5)), ' g'),
    (_Kind.weight, true) => top >= 16 ? two((v) => _quarters(r(v / 16, .25)), ' lb') : two((v) => _quarters(r(v, .5)), ' oz'),
    (_Kind.volume, false) => top >= 1000
        ? two((v) => _plain(r(v / 1000, .1)), ' L')
        : two((v) => _plain(r(v, top < 100 ? 5 : 10)), ' ml'),
    (_Kind.volume, true) => top < 60
        ? two((v) => _quarters(r(v / 29.57, .5)), ' fl oz')
        : two((v) => _quarters(r(v / 240, .25)), top / 240 > 1 ? ' cups' : ' cup'),
  };
}

/// 23.0 → "23", 1.4 → "1.4".
String _plain(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// 1.5 → "1 1/2", 0.75 → "3/4", 0 → "1/4" (never nothing).
String _quarters(double v) {
  if (v < .25) v = .25;
  final whole = v.floor(), part = const {1: '1/4', 2: '1/2', 3: '3/4'}[((v - whole) * 4).round()];
  return part == null ? '$whole' : (whole == 0 ? part : '$whole $part');
}
