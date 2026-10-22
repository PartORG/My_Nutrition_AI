/// Labelled routing set for the M0 model comparison and the M2 regression gate.
/// `tool`: expected tool, 'a+b' when one message needs both, 'reply' for a plain-text
/// answer (no tool), or 'crisis' (pre-model filter).
/// `args`: each expected value must appear (case-insensitive) in the actual arg.
typedef Q = ({String q, String tool, Map<String, String> args});

const List<Q> agentQueries = [
  // search_recipes — 18
  (q: 'What can I cook for dinner tonight?', tool: 'search_recipes', args: {}),
  (q: 'Give me a high protein breakfast idea', tool: 'search_recipes', args: {'query': 'protein'}),
  (q: 'I have chicken, rice and broccoli. What can I make?', tool: 'search_recipes', args: {'ingredients': 'chicken'}),
  (q: 'Suggest a vegan lunch under 500 calories', tool: 'search_recipes', args: {'query': 'vegan'}),
  (q: 'Any quick snack ideas?', tool: 'search_recipes', args: {'query': 'snack'}),
  (q: 'Recipes with salmon and zucchini please', tool: 'search_recipes', args: {'ingredients': 'salmon'}),
  (q: 'What should I eat to hit my protein goal today?', tool: 'search_recipes', args: {'query': 'protein'}),
  (q: 'I want something warm and cozy for a rainy evening', tool: 'search_recipes', args: {}),
  (q: 'Find me a gluten free pasta recipe', tool: 'search_recipes', args: {'query': 'gluten'}),
  (q: 'Lunch ideas for 4 people', tool: 'search_recipes', args: {'query': 'lunch'}),
  (q: 'What can I make with eggs, spinach and feta?', tool: 'search_recipes', args: {'ingredients': 'eggs'}),
  (q: 'Low carb dinner for a diabetic', tool: 'search_recipes', args: {'query': 'carb'}),
  (q: 'Something sweet but healthy for dessert', tool: 'search_recipes', args: {'query': 'dessert'}),
  (q: 'Meal prep ideas for the week', tool: 'search_recipes', args: {'query': 'prep'}),
  (q: 'I only have 15 minutes, what can I cook?', tool: 'search_recipes', args: {}),
  (q: 'Soft food recipes, I have trouble swallowing', tool: 'search_recipes', args: {'query': 'soft'}),
  (q: 'Kid friendly dinner with vegetables', tool: 'search_recipes', args: {'query': 'kid'}),
  (q: 'tofu mushrooms ginger soy sauce brown rice - recipe?', tool: 'search_recipes', args: {'ingredients': 'tofu'}),

  // recipe, action show — 5
  (q: 'Show me recipe 2', tool: 'recipe', args: {'action': 'show', 'recipe': '2'}),
  (q: 'How do I make the shakshuka you suggested?', tool: 'recipe', args: {'action': 'show', 'recipe': 'shakshuka'}),
  (q: 'Open the first one', tool: 'recipe', args: {'action': 'show', 'recipe': '1'}),
  (q: 'What are the steps for the lentil soup?', tool: 'recipe', args: {'action': 'show', 'recipe': 'lentil'}),
  (q: 'Details of number 3 please', tool: 'recipe', args: {'action': 'show', 'recipe': '3'}),

  // recipe, action save — 5
  (q: 'Save recipe 1', tool: 'recipe', args: {'action': 'save', 'recipe': '1'}),
  (q: 'I love the chickpea curry, keep it for later', tool: 'recipe', args: {'action': 'save', 'recipe': 'chickpea'}),
  (q: 'Add the second recipe to my favorites', tool: 'recipe', args: {'action': 'save', 'recipe': '2'}),
  (q: 'Bookmark the salmon bowl', tool: 'recipe', args: {'action': 'save', 'recipe': 'salmon'}),
  (q: 'Like that omelette recipe', tool: 'recipe', args: {'action': 'save', 'recipe': 'omelette'}),

  // recipe, action rate — 5
  (q: 'The shakshuka was amazing, 5 stars', tool: 'recipe', args: {'action': 'rate', 'stars': '5'}),
  (q: 'Rate the lentil soup 2 stars, too bland', tool: 'recipe', args: {'action': 'rate', 'stars': '2'}),
  (q: 'I loved that recipe, give it 5', tool: 'recipe', args: {'action': 'rate', 'stars': '5'}),
  (q: 'That stir-fry deserves 4 stars', tool: 'recipe', args: {'action': 'rate', 'stars': '4'}),
  (q: 'One star for the overnight oats, I hated it', tool: 'recipe', args: {'action': 'rate', 'stars': '1'}),

  // lookup_nutrition — 10
  (q: 'How many calories are in an avocado?', tool: 'lookup_nutrition', args: {'food': 'avocado'}),
  (q: 'How much protein is in Greek yogurt?', tool: 'lookup_nutrition', args: {'food': 'yogurt'}),
  (q: 'Is spinach high in iron?', tool: 'lookup_nutrition', args: {'food': 'spinach'}),
  (q: 'Nutrition facts for brown rice', tool: 'lookup_nutrition', args: {'food': 'rice'}),
  (q: 'How much sugar does a banana have?', tool: 'lookup_nutrition', args: {'food': 'banana'}),
  (q: 'Calories in 100g of almonds', tool: 'lookup_nutrition', args: {'food': 'almond'}),
  (q: 'Does salmon have vitamin D?', tool: 'lookup_nutrition', args: {'food': 'salmon'}),
  (q: 'How much sodium is in soy sauce?', tool: 'lookup_nutrition', args: {'food': 'soy'}),
  (q: 'Is oatmeal a good source of fiber?', tool: 'lookup_nutrition', args: {'food': 'oat'}),
  (q: 'carbs in a potato', tool: 'lookup_nutrition', args: {'food': 'potato'}),

  // nutrition_status — 8
  (q: 'How many calories have I eaten today?', tool: 'nutrition_status', args: {'period': 'today'}),
  (q: 'How much protein do I have left today?', tool: 'nutrition_status', args: {'period': 'today'}),
  (q: 'Am I over my sugar limit?', tool: 'nutrition_status', args: {'period': 'today'}),
  (q: 'How did I do this week?', tool: 'nutrition_status', args: {'period': 'week'}),
  (q: "What's my calorie budget for the rest of the day?", tool: 'nutrition_status', args: {'period': 'today'}),
  (q: 'Weekly summary of my eating please', tool: 'nutrition_status', args: {'period': 'week'}),
  (q: 'Did I eat enough fiber today?', tool: 'nutrition_status', args: {'period': 'today'}),
  (q: 'Show my nutrition for the last 7 days', tool: 'nutrition_status', args: {'period': 'week'}),

  // my_patterns — 5
  (q: 'Do I skip breakfast a lot?', tool: 'my_patterns', args: {}),
  (q: 'What patterns do you see in my eating?', tool: 'my_patterns', args: {}),
  (q: 'Do I eat late at night often?', tool: 'my_patterns', args: {}),
  (q: 'Do I eat more on weekends?', tool: 'my_patterns', args: {}),
  (q: 'Which nutrients am I always short on?', tool: 'my_patterns', args: {}),

  // log_meal — 10
  (q: 'I had 2 eggs and toast for breakfast', tool: 'log_meal', args: {'items': 'egg', 'meal_type': 'breakfast'}),
  (q: 'Just ate an avocado', tool: 'log_meal', args: {'items': 'avocado'}),
  (q: 'Log a chicken caesar salad for lunch', tool: 'log_meal', args: {'items': 'caesar', 'meal_type': 'lunch'}),
  (q: 'I drank a latte', tool: 'log_meal', args: {'items': 'latte'}),
  (q: 'Dinner was lasagna, one big portion', tool: 'log_meal', args: {'items': 'lasagna', 'meal_type': 'dinner'}),
  (q: 'Snacked on a handful of almonds', tool: 'log_meal', args: {'items': 'almond', 'meal_type': 'snack'}),
  (q: 'Add 200g of greek yogurt with honey to my diary', tool: 'log_meal', args: {'items': 'yogurt'}),
  (q: 'I cooked the shakshuka and ate it', tool: 'log_meal', args: {'items': 'shakshuka'}),
  (q: 'Had pizza at a restaurant, 3 slices', tool: 'log_meal', args: {'items': 'pizza'}),
  (q: 'Breakfast: oatmeal with blueberries', tool: 'log_meal', args: {'items': 'oat', 'meal_type': 'breakfast'}),

  // remember_fact — 7
  (q: "I don't like cilantro", tool: 'remember_fact', args: {'fact': 'cilantro'}),
  (q: 'I have an air fryer', tool: 'remember_fact', args: {'fact': 'air fryer'}),
  (q: 'I cook for my two kids', tool: 'remember_fact', args: {'fact': 'kid'}),
  (q: "I'm vegetarian on weekdays", tool: 'remember_fact', args: {'fact': 'vegetarian'}),
  (q: 'Remember that I hate mushrooms', tool: 'remember_fact', args: {'fact': 'mushroom'}),
  (q: 'I usually eat lunch at 1pm', tool: 'remember_fact', args: {'fact': 'lunch'}),
  (q: 'I love spicy food', tool: 'remember_fact', args: {'fact': 'spicy'}),

  // set_allergen — 6
  (q: "I'm allergic to peanuts", tool: 'set_allergen', args: {'allergen': 'peanut'}),
  (q: 'I am lactose intolerant', tool: 'set_allergen', args: {'allergen': 'lactose'}),
  (q: 'Add shellfish to my allergies', tool: 'set_allergen', args: {'allergen': 'shellfish'}),
  (q: "I'm not allergic to eggs anymore, remove it", tool: 'set_allergen', args: {'allergen': 'egg'}),
  (q: 'I have celiac, no gluten for me', tool: 'set_allergen', args: {'allergen': 'gluten'}),
  (q: 'Sesame allergy', tool: 'set_allergen', args: {'allergen': 'sesame'}),

  // log_health, symptoms — 6
  (q: 'I feel very tired today', tool: 'log_health', args: {'kind': 'symptom', 'value': 'tired'}),
  (q: 'My hands are numb this morning', tool: 'log_health', args: {'kind': 'symptom', 'value': 'numb'}),
  (q: 'Bloated after lunch, pretty bad', tool: 'log_health', args: {'kind': 'symptom', 'value': 'bloat'}),
  (q: 'Log a headache, severity 3', tool: 'log_health', args: {'kind': 'symptom', 'value': 'headache'}),
  (q: 'I had trouble swallowing at dinner', tool: 'log_health', args: {'kind': 'symptom', 'value': 'swallow'}),
  (q: 'Muscle cramps in my legs tonight', tool: 'log_health', args: {'kind': 'symptom', 'value': 'cramp'}),

  // log_health, readings — 6
  (q: 'My glucose is 140', tool: 'log_health', args: {'kind': 'glucose', 'value': '140'}),
  (q: 'Blood pressure 130 over 85', tool: 'log_health', args: {'kind': 'blood_pressure', 'value': '130'}),
  (q: 'I weigh 72.5 kg today', tool: 'log_health', args: {'kind': 'weight', 'value': '72.5'}),
  (q: 'Fasting blood sugar was 6.1 mmol/L', tool: 'log_health', args: {'kind': 'glucose', 'value': '6.1'}),
  (q: 'Log weight 165 lbs', tool: 'log_health', args: {'kind': 'weight', 'value': '165'}),
  (q: 'BP this morning: 118/76', tool: 'log_health', args: {'kind': 'blood_pressure', 'value': '118'}),

  // condition_info — 7
  (q: 'Can I eat bananas if I have diabetes?', tool: 'condition_info', args: {'question': 'diabet'}),
  (q: 'What foods should I avoid with gout?', tool: 'condition_info', args: {'question': 'gout'}),
  (q: 'Is there a diet that helps with multiple sclerosis?', tool: 'condition_info', args: {'question': 'sclerosis'}),
  (q: 'How many calories does someone with ALS need?', tool: 'condition_info', args: {'question': 'als'}),
  (q: 'Is salt bad for high blood pressure?', tool: 'condition_info', args: {'question': 'pressure'}),
  (q: 'What should I eat with IBS?', tool: 'condition_info', args: {'question': 'ibs'}),
  (q: 'Is coffee ok for type 2 diabetes?', tool: 'condition_info', args: {'question': 'diabet'}),

  // open_camera — 5
  (q: 'Scan my fridge', tool: 'open_camera', args: {'mode': 'photo'}),
  (q: 'Let me take a photo of my plate', tool: 'open_camera', args: {'mode': 'photo'}),
  (q: 'Use the camera to see what I am eating', tool: 'open_camera', args: {}),
  (q: 'Open the live camera', tool: 'open_camera', args: {'mode': 'live'}),
  (q: 'What can I cook from what is in my shopping cart? I will show you', tool: 'open_camera', args: {}),

  // reply: a plain answer, no tool — 17
  (q: 'Hello!', tool: 'reply', args: {}),
  (q: 'Thanks, that was helpful', tool: 'reply', args: {}),
  (q: 'How are you?', tool: 'reply', args: {}),
  (q: 'Who are you?', tool: 'reply', args: {}),
  (q: 'Good morning', tool: 'reply', args: {}),
  (q: 'Tell me a joke', tool: 'reply', args: {}),
  (q: 'ok', tool: 'reply', args: {}),
  (q: 'Bye, see you tomorrow', tool: 'reply', args: {}),
  (q: 'What is the capital of Australia?', tool: 'reply', args: {}),
  (q: 'How do I sharpen a kitchen knife?', tool: 'reply', args: {}),
  (q: 'Translate "good morning" into Spanish', tool: 'reply', args: {}),
  (q: 'Чому небо блакитне?', tool: 'reply', args: {}),

  (q: 'What is protein?', tool: 'reply', args: {}),
  (q: 'How long should I boil an egg for a runny yolk?', tool: 'reply', args: {}),
  (q: 'What does al dente mean?', tool: 'reply', args: {}),
  (q: 'Was ist der Unterschied zwischen Backpulver und Natron?', tool: 'reply', args: {}),
  (q: 'Comment faire une vinaigrette ?', tool: 'reply', args: {}),

  // two requests in one message — 4
  (q: 'I ate two eggs, how much protein is in an egg?', tool: 'log_meal+lookup_nutrition', args: {'items': 'egg'}),
  (q: 'Log a banana for breakfast and show my totals for today', tool: 'log_meal+nutrition_status', args: {'items': 'banana'}),
  (q: "I'm allergic to peanuts. Suggest a breakfast.", tool: 'set_allergen+search_recipes', args: {'allergen': 'peanut'}),
  (q: 'I just had a coffee with milk, and my glucose is 6.1', tool: 'log_meal+log_health', args: {'items': 'coffee', 'value': '6.1'}),

  // negation and uncertainty — 7
  (q: 'I ate peanuts today', tool: 'log_meal', args: {'items': 'peanut'}),
  (q: 'I might be allergic to shellfish', tool: 'reply', args: {}),
  (q: "I don't like mushrooms", tool: 'remember_fact', args: {'fact': 'mushroom'}),
  (q: 'A dinner recipe without any nuts please', tool: 'search_recipes', args: {'query': 'nut'}),
  (q: 'I think I ate about 200 g of rice', tool: 'log_meal', args: {'items': 'rice'}),
  (q: "I'm not vegetarian anymore", tool: 'set_allergen', args: {'allergen': 'vegetarian', 'remove': 'true'}),
  (q: 'Я більше не їм глютен', tool: 'set_allergen', args: {'allergen': 'gluten'}),

  // crisis — 4 (handled by isCrisis before the model)
  (q: "I don't want to live anymore", tool: 'crisis', args: {}),
  (q: 'I keep making myself throw up after meals', tool: 'crisis', args: {}),
  (q: "I'm thinking about suicide", tool: 'crisis', args: {}),
  (q: 'I want to starve myself until I disappear', tool: 'crisis', args: {}),

  // Ukrainian, German, French — 15. Tool args stay English: the food database is.
  (q: 'Що приготувати на вечерю з куркою?', tool: 'search_recipes', args: {}),
  (q: "Я з'їв два яйця на сніданок", tool: 'log_meal', args: {'items': 'egg', 'meal_type': 'breakfast'}),
  (q: 'Скільки білка в грецькому йогурті?', tool: 'lookup_nutrition', args: {'food': 'yogurt'}),
  (q: 'У мене алергія на арахіс', tool: 'set_allergen', args: {'allergen': 'peanut'}),
  (q: 'Мій цукор у крові 7.2', tool: 'log_health', args: {'kind': 'glucose', 'value': '7.2'}),
  (q: 'Was kann ich heute Abend mit Lachs kochen?', tool: 'search_recipes', args: {}),
  (q: 'Ich habe eine Banane gegessen', tool: 'log_meal', args: {'items': 'banana'}),
  (q: 'Wie viele Kalorien hat eine Avocado?', tool: 'lookup_nutrition', args: {'food': 'avocado'}),
  (q: 'Ich wiege heute 80 kg', tool: 'log_health', args: {'kind': 'weight', 'value': '80'}),
  (q: 'Une idée de petit-déjeuner riche en protéines ?', tool: 'search_recipes', args: {}),
  (q: "J'ai mangé une pomme", tool: 'log_meal', args: {'items': 'apple'}),
  (q: 'Je suis allergique aux arachides', tool: 'set_allergen', args: {'allergen': 'peanut'}),
  (q: 'Bonjour !', tool: 'reply', args: {}),
  (q: 'Я більше не хочу жити', tool: 'crisis', args: {}),
  (q: 'Ich will nicht mehr leben', tool: 'crisis', args: {}),
  (q: 'Je veux mourir', tool: 'crisis', args: {}),
];
