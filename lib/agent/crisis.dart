/// Crisis detection runs before the model: a 0.6B model must never be the
/// thing deciding whether someone gets a helpline.
// ponytail: keyword list, misses indirect phrasing; extend from real reports.
final _crisis = RegExp(
  r"\b(suicid\w*|kill (my ?self|me)|end (my life|it all)|want to die|"
  r"don'?t want to (live|be alive)|hurt(ing)? my ?self|self[- ]?harm|"
  r"starv(e|ing) my ?self|purg(e|ing)|mak(e|ing) my ?self (throw up|vomit|sick))",
  caseSensitive: false,
);

bool isCrisis(String message) => _crisis.hasMatch(message);
