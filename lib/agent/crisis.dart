/// Crisis detection runs before the model: a 0.6B model must never be the
/// thing deciding whether someone gets a helpline. English, Ukrainian, German
/// and French, like the app. Errs towards the helpline: a false alarm costs a
/// card, a miss can cost more.
// ponytail: keyword list, misses indirect phrasing; extend from real reports.
final _crisis = RegExp(
  // English
  r"\b(suicid\w*|kill (my ?self|me)|end (my life|it all)|want to die|"
  r"don'?t want to (live|be alive)|hurt(ing)? my ?self|self[- ]?harm|"
  r"starv(e|ing) my ?self|purg(e|ing)|mak(e|ing) my ?self (throw up|vomit|sick))|"
  // Ukrainian (no \b: Dart's \b only knows ASCII letters)
  r"(хочу|хочеться|краще б) (в|по)?мерти|не хочу (більше )?жити|покінчити (з собою|з життям|життя)|"
  r"(в|у)бити себе|самогубств|суїцид|самоушкодж|(завдати|завдаю|завдав|завдала) собі (шкоди|болю)|"
  r"(ріжу|різати|порізати) себе|морити себе голодом|морю себе голодом|викликати (в себе |у себе )?блювоту|"
  r"викликаю (в себе |у себе )?блювоту|"
  // German
  r"selbstmord|suizid|mich (umbringen|töten)|bringe mich um|will (nicht mehr leben|sterben)|möchte sterben|"
  r"mein leben beenden|mir (selbst )?(weh ?tun|etwas antun)|selbstverletz|(mich )?ritzen|ritze mich|"
  r"hungere mich|mich (zum )?(erbrechen|übergeben) bringen|"
  // French
  r"me suicider|me tuer|en finir(?! avec (?!la vie|tout))|mettre fin à (ma vie|mes jours)|(veux|voudrais|envie de) mourir|"
  r"ne veux plus vivre|me faire du mal|me mutiler|automutil|scarif|me faire vomir|m'affamer|me priver de manger",
  caseSensitive: false,
);

bool isCrisis(String message) => _crisis.hasMatch(message);
