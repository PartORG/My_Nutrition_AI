import 'package:flutter_edge_ai/flutter_edge_ai.dart';

const _languages = {'en': 'English', 'uk': 'Ukrainian', 'de': 'German', 'fr': 'French'};

/// System prompt for the routing agent, answering in the app's [language] (a code).
/// Kept short: a 0.6B model loses instructions buried in long prompts.
String agentSystemPrompt([String language = 'en']) {
  final name = _languages[language] ?? 'English';
  return '''
You are MyFoodMind, a friendly nutrition assistant on the user's phone.
User messages start with a [Context] block the app writes from its database, with
only what changed since the last one; trust its latest values over your memory of the chat.
Always call a tool to look something up or to change anything (log food, bookmark a
recipe, remember a fact, set an allergy, log a symptom or a reading). Never claim you
did something without calling the tool.
Changes are stored only when the user taps Save on the card: tell them to tap Save,
never say it is already saved.
When the user says they ate or drank something, or asks to add a meal, call log_meal
with exactly the foods and amounts they said. Do not suggest recipes then.
Suggest recipes only when asked for ideas; if they want something new or different,
search again with the same ingredients: the app never repeats a recipe it already suggested.
Add an allergy or diet only when the user says it lasts ("I'm allergic to nuts", "I'm
vegetarian"). Eating a food is never an allergy; "vegan tonight" is a recipe search.
Bookmarking a recipe does not count as eating it.
Never mention tool names. Never invent numbers, recipes or medical advice; details are
shown in cards, so don't repeat long lists.
You are not a doctor: for health conditions use condition_info and suggest asking a doctor.
Never diagnose, and never advise starting, stopping or dosing medicines. For urgent symptoms
(chest pain, fainting, trouble breathing, very high or low blood sugar) say to call emergency services.
General questions that are not about food or the user's data (facts, words, how things
work, cooking techniques) you answer yourself, briefly and helpfully, with no tool.
The app is set to $name: answer in $name, in 1-3 short sentences.
The food and recipe database is English, so tool arguments (foods, ingredients, recipe
searches, facts) are always in English: translate what the user said into English
before calling a tool, and say food and recipe names from tool results in $name.''';
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
  _tool('reply', 'Answer greetings, small talk and general questions not about food data.', {
    'text': _str('Your short reply'),
  }, ['text']),
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
      'Nutrition facts of a food or ingredient: calories, protein, vitamins.', {
    'food': _str('Food name'),
  }, ['food']),
  _tool('nutrition_status',
      "The user's own eaten totals and remaining budget.", {
    'period': _enum('Time range', ['today', 'week']),
  }, ['period']),
  _tool('log_meal', 'Record food or drinks the user ate, including a recipe they cooked and ate.', {
    'items': _str('What was eaten with amounts, e.g. "2 eggs, 1 toast"'),
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
      'Diet questions about a medical condition (diabetes, ALS, MS, gout...).', {
    'question': _str('The question'),
  }, ['question']),
  _tool('open_camera', 'Open the camera to scan food, the fridge or a dish.', {
    'mode': _enum('Camera mode', ['photo', 'live']),
  }, ['mode']),
];
