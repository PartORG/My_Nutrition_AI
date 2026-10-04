import 'package:flutter_gemma/flutter_gemma.dart';

/// System prompt for the routing agent. Kept short: a 0.6B model loses
/// instructions buried in long prompts.
const agentSystemPrompt = '''
You are MyFoodMind, a friendly nutrition assistant on the user's phone.
Call a tool whenever the user asks for data, wants to log something, or states a
fact about themselves. Never invent numbers, recipes or medical advice: tools have
the real data. For greetings, thanks or small talk, use the reply tool.''';

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
  _tool('reply', 'Answer greetings, thanks and small talk with a short message.', {
    'text': _str('Your short reply'),
  }, ['text']),
  _tool('search_recipes', 'Find recipes, meal ideas or what to cook.', {
    'query': _str('What the user wants, e.g. "high protein vegetarian dinner"'),
    'ingredients': _str('Comma-separated ingredients the user has, if any'),
  }, ['query']),
  _tool('show_recipe', 'Show the full details of a recipe already mentioned.', {
    'recipe': _str('Recipe name or its number in the last list'),
  }, ['recipe']),
  _tool('save_recipe', 'Save or like a recipe for later.', {
    'recipe': _str('Recipe name or its number in the last list'),
  }, ['recipe']),
  _tool('lookup_nutrition',
      'Nutrition facts of a food or ingredient: calories, protein, vitamins.', {
    'food': _str('Food name'),
  }, ['food']),
  _tool('nutrition_status',
      "The user's own eaten totals and remaining budget.", {
    'period': _enum('Time range', ['today', 'week']),
  }, ['period']),
  _tool('log_meal', 'Record food the user ate or drank.', {
    'items': _str('What was eaten with amounts, e.g. "2 eggs, 1 toast"'),
    'meal_type': _enum('Meal', ['breakfast', 'lunch', 'dinner', 'snack']),
  }, ['items']),
  _tool('remember_fact',
      'Remember a preference or fact about the user (likes, dislikes, '
          'kitchen equipment, family, routine). Not for allergies.', {
    'fact': _str('The fact in one short sentence'),
  }, ['fact']),
  _tool('set_allergen', 'Add or remove a food allergy or intolerance.', {
    'allergen': _str('Allergen, e.g. "peanuts"'),
    'remove': {'type': 'boolean', 'description': 'True to remove it'},
  }, ['allergen']),
  _tool('log_symptom', 'Record a symptom the user feels.', {
    'symptom': _str('Symptom, e.g. "fatigue"'),
    'severity': {'type': 'integer', 'description': '1 (mild) to 5 (severe)'},
  }, ['symptom']),
  _tool('log_reading', 'Record a measurement: blood glucose, blood pressure or weight.', {
    'kind': _enum('Measurement', ['glucose', 'blood_pressure', 'weight']),
    'value': _str('Value with unit, e.g. "140 mg/dL"'),
  }, ['kind', 'value']),
  _tool('condition_info',
      'Diet questions about a medical condition (diabetes, ALS, MS, gout...).', {
    'question': _str('The question'),
  }, ['question']),
  _tool('open_camera', 'Open the camera to scan food, the fridge, a dish or a barcode.', {
    'mode': _enum('Camera mode', ['photo', 'live', 'barcode']),
  }, ['mode']),
];
