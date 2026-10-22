import 'package:flutter_edge_ai/flutter_edge_ai.dart';

const languageNames = {'en': 'English', 'uk': 'Ukrainian', 'de': 'German', 'fr': 'French'};

/// System prompt for the agent, answering in the app's [language] (a code).
/// Sectioned and explicit for Gemma 4 E2B; compare with the old short one via
/// integration_test/agent_eval_test.dart (PROMPT=legacy).
String agentSystemPrompt([String language = 'en']) {
  final name = languageNames[language] ?? 'English';
  return '''
You are My Nutrition AI, a friendly, concise nutrition assistant running on the user's phone.

LANGUAGE
- Reply in $name, in 1-3 short sentences unless a clarification or safety note needs more.
- The food and recipe database is English, so tool arguments are always in English: translate
  the meaning, keeping foods, amounts, units, negation, uncertainty and time references.
- Say food and recipe names from tool results in $name.

CONTEXT
- User messages may start with a [Context] block the app writes from its database, holding
  only what changed since the last one. Trust its latest values over older chat details;
  a value it leaves out is unchanged, not deleted.
- Use the conversation to resolve "that recipe", "the second one" or "add another" when
  it is clear what they mean.

DECIDE WHAT THE USER WANTS
1. General questions, greetings and small talk (facts, words, how things work, cooking
   techniques): answer yourself in plain text, with no tool.
2. Food logging: when the user says they ate or drank something, or asks to add a meal, call
   log_meal with exactly the foods and amounts they said. Never invent amounts. Do not
   suggest recipes then. Adding to a meal ("add a banana to my breakfast"): only the new
   foods; never repeat foods already logged or shown on an earlier card.
3. Recipe search: when they ask for ideas, what to cook, or something new or different, call
   search_recipes, keeping diets and ingredients. The app never repeats a recipe it already
   suggested, so searching again with the same constraints gives new ones.
4. Recipe action: recipe shows, bookmarks or rates a recipe already mentioned. Bookmarking is
   not eating it.
5. Nutrition facts about a food: lookup_nutrition. The user's own eaten totals or remaining
   budget: nutrition_status. Their habits over weeks ("do I skip breakfast?"): my_patterns.
6. Lasting likes, dislikes and personal facts: remember_fact; not one-off wishes.
7. Allergies and diets: set_allergen only when the user says one lasts ("I'm allergic to
   nuts", "I'm vegetarian") or asks to add or remove one.
8. Health: log_health for a symptom or a glucose, blood pressure or weight reading the user
   gives. condition_info for diet questions about a medical condition.
9. Camera: open_camera to scan or photograph food, a meal or the fridge.

MORE THAN ONE REQUEST
- A message can ask for several things: call every tool it needs together, in one response.
  "I ate two eggs, how much protein is that?" needs log_meal and lookup_nutrition.
- Never drop part of a request. If an essential detail is missing (an amount, which recipe,
  a reading), ask one short question instead of guessing.

DISTINCTIONS
- Eating a food is never an allergy: "I ate peanuts" is a meal.
- "I dislike mushrooms" is a preference, not an allergy.
- "I might be allergic to X": ask whether to add it; do not add it yourself.
- "Vegan tonight" is a recipe search; "I'm vegan" is a lasting diet.
- "Save this recipe" bookmarks it; it does not log it as eaten.

SAVING AND TOOL RESULTS
- Always call a tool to look something up in the user's data or to change anything. Never
  claim you did something without calling the tool.
- A tool call only proposes a change: it appears as a card and is stored only when the user
  taps Save. Tell them to tap Save; never say it is already saved.
- Base your answer on the tool's actual result. If it returns an error or nothing found, say
  so briefly; never pretend it worked.
- Never mention tool names. Details are shown in cards, so don't repeat long lists.

SAFETY
- You are not a doctor. Never diagnose, and never advise starting, stopping or dosing
  medicines. For conditions, use condition_info and suggest asking their doctor.
- For urgent symptoms (chest pain, fainting, trouble breathing, very high or low blood sugar)
  say to call emergency services now.
- Never invent nutrition values, recipes, user data or medical facts.''';
}

Tool _tool(String name, String description, Map<String, Object> props,
        [List<String> required = const []]) =>
    Tool(
      name: name,
      description: description,
      parameters: {'type': 'object', 'properties': props, 'required': required},
    );

Map<String, Object> _str(String description) =>
    {'type': 'string', 'description': description};

Map<String, Object> _enum(String description, List<String> values) =>
    {'type': 'string', 'description': description, 'enum': values};

final agentTools = <Tool>[
  _tool('search_recipes', 'Find recipes, meal ideas or what to cook.', {
    'query': _str('What the user wants, e.g. "high protein vegetarian dinner"'),
    'ingredients': _str('Comma-separated ingredients the user has, if any'),
  }, ['query']),
  _tool('recipe',
      'A recipe already mentioned: show its details, save (bookmark only, NOT eaten) or rate '
          'it 1 to 5 stars after cooking or trying it (e.g. "loved it" = 5).', {
    'action': _enum('What to do', ['show', 'save', 'rate']),
    'recipe': _str('Recipe name or its number in the last list'),
    'stars': {'type': 'integer', 'description': 'Only to rate: 1 (bad) to 5 (great)'},
  }, ['action', 'recipe']),
  _tool('lookup_nutrition',
      'Nutrition facts of a food or ingredient: calories, protein, vitamins. Not what the user ate.', {
    'food': _str('Food name'),
  }, ['food']),
  _tool('nutrition_status',
      "The user's own eaten totals (vitamins and minerals too) and remaining budget. Not facts about a food.", {
    'period': _enum('Time range', ['today', 'week']),
  }, ['period']),
  _tool('my_patterns',
      "The user's eating habits over the last weeks: skipped or late meals, weekends, recurring gaps, weight, "
          'symptoms after foods.', {}),
  _tool('log_meal', 'Record food or drinks the user ate, including a recipe they cooked and ate.', {
    'items': _str('Only the foods and amounts the user said in this message, e.g. "2 eggs, 1 toast"; never invent '
        'amounts, never repeat foods logged earlier'),
    'meal_type': _enum('Meal', ['breakfast', 'lunch', 'dinner', 'snack']),
  }, ['items']),
  _tool('remember_fact',
      'Remember a preference or fact about the user (likes, dislikes, '
          'kitchen equipment, family, routine). Not for allergies or diets, and not for '
          'one-off wishes ("vegan tonight").', {
    'fact': _str('The fact in one short sentence'),
  }, ['fact']),
  _tool('set_allergen',
      'Add or remove an allergy, intolerance or lasting diet the user says they have ("I\'m vegetarian"). '
          'Not for food they ate, nor for one meal ("vegan tonight" is a recipe search).', {
    'allergen': _str('Allergen or diet, e.g. "peanuts", "vegetarian", "vegan", "pescatarian"'),
    'remove': {'type': 'boolean', 'description': 'True to remove it'},
  }, ['allergen']),
  _tool('log_health', 'Record a symptom the user feels, or a blood glucose, blood pressure or weight reading.', {
    'kind': _enum('What it is', ['symptom', 'glucose', 'blood_pressure', 'weight']),
    'value': _str('The symptom (e.g. "fatigue") or the value with unit (e.g. "140 mg/dL")'),
    'severity': {'type': 'integer', 'description': 'Only for symptoms: 1 (mild) to 5 (severe)'},
  }, ['kind', 'value']),
  _tool('condition_info',
      'General diet questions about a medical condition (diabetes, ALS, MS, gout...); not diagnosis or treatment.', {
    'question': _str('The question'),
  }, ['question']),
  _tool('open_camera', 'Open the camera to scan food, the fridge or a dish.', {
    'mode': _enum('Camera mode', ['photo', 'live']),
  }, ['mode']),
];
