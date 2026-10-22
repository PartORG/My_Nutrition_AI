import 'agent_queries.dart';

/// The routing set in Ukrainian, German and French for the phone gate (docs/PLAN.md "All nutrients, patterns", 11),
/// plus the cases the old router answered alone (water). Expected args stay English: tool arguments always are.
/// Crisis lines have their own tests (isCrisis runs before the model).
const _set = <(String, Map<String, String>, String, String, String)>[
  // search_recipes
  ('search_recipes', {}, 'Що приготувати сьогодні на вечерю?', 'Was kann ich heute zum Abendessen kochen?', 'Que puis-je cuisiner ce soir ?'),
  ('search_recipes', {'query': 'protein'}, 'Дай ідею сніданку з високим вмістом білка', 'Gib mir eine Idee für ein proteinreiches Frühstück', 'Donne-moi une idée de petit-déjeuner riche en protéines'),
  ('search_recipes', {'ingredients': 'chicken'}, 'У мене є курка, рис і броколі. Що можна зробити?', 'Ich habe Hähnchen, Reis und Brokkoli. Was kann ich machen?', 'J’ai du poulet, du riz et du brocoli. Que puis-je faire ?'),
  ('search_recipes', {'query': 'vegan'}, 'Порадь веганський обід до 500 калорій', 'Schlag ein veganes Mittagessen unter 500 Kalorien vor', 'Propose un déjeuner végan de moins de 500 calories'),
  ('search_recipes', {'query': 'snack'}, 'Є ідеї для швидкого перекусу?', 'Hast du Ideen für einen schnellen Snack?', 'Des idées de collation rapide ?'),
  ('search_recipes', {'ingredients': 'salmon'}, 'Рецепти з лососем і цукіні, будь ласка', 'Rezepte mit Lachs und Zucchini bitte', 'Des recettes avec du saumon et des courgettes, s’il te plaît'),
  ('search_recipes', {'query': 'gluten'}, 'Знайди рецепт пасти без глютену', 'Finde mir ein glutenfreies Nudelrezept', 'Trouve-moi une recette de pâtes sans gluten'),
  ('search_recipes', {'query': 'lunch'}, 'Ідеї обіду на 4 людини', 'Ideen fürs Mittagessen für 4 Personen', 'Des idées de déjeuner pour 4 personnes'),
  ('search_recipes', {'ingredients': 'egg'}, 'Що можна зробити з яєць, шпинату і фети?', 'Was kann ich aus Eiern, Spinat und Feta machen?', 'Que faire avec des œufs, des épinards et de la feta ?'),
  ('search_recipes', {'query': 'carb'}, 'Вечеря з малою кількістю вуглеводів для діабетика', 'Kohlenhydratarmes Abendessen für Diabetiker', 'Un dîner pauvre en glucides pour un diabétique'),
  ('search_recipes', {'query': 'dessert'}, 'Щось солодке, але корисне на десерт', 'Etwas Süßes, aber Gesundes zum Nachtisch', 'Un dessert sucré mais sain'),
  ('search_recipes', {}, 'У мене лише 15 хвилин, що приготувати?', 'Ich habe nur 15 Minuten, was kann ich kochen?', 'J’ai seulement 15 minutes, que cuisiner ?'),
  ('search_recipes', {'query': 'soft'}, 'Рецепти м’якої їжі, мені важко ковтати', 'Rezepte für weiche Kost, ich kann schlecht schlucken', 'Des recettes de plats mous, j’ai du mal à avaler'),
  ('search_recipes', {'query': 'nut'}, 'Рецепт вечері без горіхів, будь ласка', 'Ein Abendessen-Rezept ganz ohne Nüsse bitte', 'Une recette de dîner sans noix, s’il te plaît'),

  // recipe: show, save, rate (a list of recipes is on screen)
  ('recipe', {'action': 'show', 'recipe': '2'}, 'Покажи рецепт 2', 'Zeig mir Rezept 2', 'Montre-moi la recette 2'),
  ('recipe', {'action': 'show', 'recipe': 'shakshuka'}, 'Як приготувати шакшуку, яку ти запропонував?', 'Wie mache ich die Shakshuka, die du vorgeschlagen hast?', 'Comment faire la chakchouka que tu as proposée ?'),
  ('recipe', {'action': 'show', 'recipe': '1'}, 'Відкрий перший', 'Öffne das erste', 'Ouvre la première'),
  ('recipe', {'action': 'show', 'recipe': '3'}, 'Деталі номера 3, будь ласка', 'Details zu Nummer 3 bitte', 'Les détails du numéro 3, s’il te plaît'),
  ('recipe', {'action': 'save', 'recipe': '1'}, 'Збережи рецепт 1', 'Speichere Rezept 1', 'Enregistre la recette 1'),
  ('recipe', {'action': 'save', 'recipe': '2'}, 'Додай другий рецепт в обране', 'Füge das zweite Rezept zu meinen Favoriten hinzu', 'Ajoute la deuxième recette à mes favoris'),
  ('recipe', {'action': 'save', 'recipe': 'salmon'}, 'Збережи боул із лососем', 'Merk dir die Lachs-Bowl', 'Garde le bol au saumon'),
  ('recipe', {'action': 'rate', 'stars': '5'}, 'Шакшука була чудова, 5 зірок', 'Die Shakshuka war großartig, 5 Sterne', 'La chakchouka était géniale, 5 étoiles'),
  ('recipe', {'action': 'rate', 'stars': '2'}, 'Оціни сочевичний суп на 2 зірки, надто прісний', 'Bewerte die Linsensuppe mit 2 Sternen, zu fade', 'Note la soupe de lentilles 2 étoiles, trop fade'),
  ('recipe', {'action': 'rate', 'stars': '4'}, 'Той стир-фрай заслуговує 4 зірки', 'Das Pfannengericht verdient 4 Sterne', 'Ce sauté mérite 4 étoiles'),

  // lookup_nutrition
  ('lookup_nutrition', {'food': 'avocado'}, 'Скільки калорій в авокадо?', 'Wie viele Kalorien hat eine Avocado?', 'Combien de calories dans un avocat ?'),
  ('lookup_nutrition', {'food': 'spinach'}, 'Чи багато заліза у шпинаті?', 'Hat Spinat viel Eisen?', 'Les épinards sont-ils riches en fer ?'),
  ('lookup_nutrition', {'food': 'rice'}, 'Харчова цінність бурого рису', 'Nährwerte von Naturreis', 'Valeurs nutritionnelles du riz complet'),
  ('lookup_nutrition', {'food': 'banana'}, 'Скільки цукру в банані?', 'Wie viel Zucker hat eine Banane?', 'Combien de sucre dans une banane ?'),
  ('lookup_nutrition', {'food': 'almond'}, 'Калорії в 100 г мигдалю', 'Kalorien in 100 g Mandeln', 'Calories dans 100 g d’amandes'),
  ('lookup_nutrition', {'food': 'salmon'}, 'Чи є в лососі вітамін D?', 'Hat Lachs Vitamin D?', 'Le saumon contient-il de la vitamine D ?'),
  ('lookup_nutrition', {'food': 'soy'}, 'Скільки натрію в соєвому соусі?', 'Wie viel Natrium ist in Sojasoße?', 'Combien de sodium dans la sauce soja ?'),
  ('lookup_nutrition', {'food': 'potato'}, 'вуглеводи в картоплі', 'Kohlenhydrate in einer Kartoffel', 'glucides dans une pomme de terre'),

  // nutrition_status
  ('nutrition_status', {'period': 'today'}, 'Скільки калорій я з’їв сьогодні?', 'Wie viele Kalorien habe ich heute gegessen?', 'Combien de calories ai-je mangées aujourd’hui ?'),
  ('nutrition_status', {'period': 'today'}, 'Скільки білка мені ще лишилося на сьогодні?', 'Wie viel Protein bleibt mir heute noch?', 'Combien de protéines me reste-t-il aujourd’hui ?'),
  ('nutrition_status', {'period': 'today'}, 'Я перевищив ліміт цукру?', 'Bin ich über meinem Zuckerlimit?', 'Ai-je dépassé ma limite de sucre ?'),
  ('nutrition_status', {'period': 'week'}, 'Як у мене пройшов цей тиждень?', 'Wie lief diese Woche bei mir?', 'Comment s’est passée ma semaine ?'),
  ('nutrition_status', {'period': 'today'}, 'Чи достатньо клітковини я з’їв сьогодні?', 'Habe ich heute genug Ballaststoffe gegessen?', 'Ai-je mangé assez de fibres aujourd’hui ?'),
  ('nutrition_status', {'period': 'today'}, 'Мені сьогодні бракує заліза?', 'Fehlt mir heute Eisen?', 'Est-ce que je manque de fer aujourd’hui ?'),

  // log_meal
  ('log_meal', {'items': 'egg', 'meal_type': 'breakfast'}, 'На сніданок я з’їв 2 яйця і тост', 'Ich hatte 2 Eier und Toast zum Frühstück', 'J’ai mangé 2 œufs et un toast au petit-déjeuner'),
  ('log_meal', {'items': 'avocado'}, 'Щойно з’їв авокадо', 'Habe gerade eine Avocado gegessen', 'Je viens de manger un avocat'),
  ('log_meal', {'items': 'caesar', 'meal_type': 'lunch'}, 'Запиши салат цезар з куркою на обід', 'Trag einen Caesar Salad mit Hähnchen zum Mittag ein', 'Note une salade César au poulet pour le déjeuner'),
  ('log_meal', {'items': 'latte'}, 'Я випив лате', 'Ich habe einen Latte getrunken', 'J’ai bu un latte'),
  ('log_meal', {'items': 'lasagna', 'meal_type': 'dinner'}, 'На вечерю була лазанья, одна велика порція', 'Zum Abendessen gab es Lasagne, eine große Portion', 'Au dîner, des lasagnes, une grosse portion'),
  ('log_meal', {'items': 'almond', 'meal_type': 'snack'}, 'Перекусив жменею мигдалю', 'Eine Handvoll Mandeln als Snack', 'J’ai grignoté une poignée d’amandes'),
  ('log_meal', {'items': 'yogurt'}, 'Додай 200 г грецького йогурту з медом у щоденник', 'Füge 200 g griechischen Joghurt mit Honig zu meinem Tagebuch hinzu', 'Ajoute 200 g de yaourt grec au miel à mon journal'),
  ('log_meal', {'items': 'pizza'}, 'Їв піцу в ресторані, 3 шматки', 'Hatte im Restaurant Pizza, 3 Stücke', 'J’ai mangé une pizza au restaurant, 3 parts'),
  ('log_meal', {'items': 'oat', 'meal_type': 'breakfast'}, 'Сніданок: вівсянка з чорницею', 'Frühstück: Haferbrei mit Heidelbeeren', 'Petit-déjeuner : flocons d’avoine aux myrtilles'),
  ('log_meal', {'items': 'peanut'}, 'Я сьогодні їв арахіс', 'Ich habe heute Erdnüsse gegessen', 'J’ai mangé des cacahuètes aujourd’hui'),
  ('log_meal', {'items': 'rice'}, 'Здається, я з’їв близько 200 г рису', 'Ich glaube, ich habe etwa 200 g Reis gegessen', 'Je crois que j’ai mangé environ 200 g de riz'),
  ('log_meal', {'items': 'water'}, 'Я випив 2 склянки води', 'Ich habe 2 Gläser Wasser getrunken', 'J’ai bu 2 verres d’eau'),

  // remember_fact
  ('remember_fact', {'fact': 'cilantro'}, 'Я не люблю кінзу', 'Ich mag keinen Koriander', 'Je n’aime pas la coriandre'),
  ('remember_fact', {'fact': 'air fryer'}, 'У мене є аерогриль', 'Ich habe eine Heißluftfritteuse', 'J’ai une friteuse à air'),
  ('remember_fact', {'fact': 'kid'}, 'Я готую для двох дітей', 'Ich koche für meine zwei Kinder', 'Je cuisine pour mes deux enfants'),
  ('remember_fact', {'fact': 'mushroom'}, 'Запам’ятай, що я ненавиджу гриби', 'Merk dir, dass ich Pilze hasse', 'Retiens que je déteste les champignons'),
  ('remember_fact', {'fact': 'spicy'}, 'Я люблю гостру їжу', 'Ich liebe scharfes Essen', 'J’adore la nourriture épicée'),

  // set_allergen
  ('set_allergen', {'allergen': 'lactose'}, 'У мене непереносимість лактози', 'Ich habe eine Laktoseintoleranz', 'Je suis intolérant au lactose'),
  ('set_allergen', {'allergen': 'shellfish'}, 'Додай молюсків до моїх алергій', 'Füge Schalentiere zu meinen Allergien hinzu', 'Ajoute les fruits de mer à mes allergies'),
  ('set_allergen', {'allergen': 'gluten'}, 'У мене целіакія, мені без глютену', 'Ich habe Zöliakie, kein Gluten für mich', 'Je suis cœliaque, pas de gluten pour moi'),
  ('set_allergen', {'allergen': 'sesame'}, 'Алергія на кунжут', 'Sesamallergie', 'Allergie au sésame'),
  ('set_allergen', {'allergen': 'vegetarian', 'remove': 'true'}, 'Я більше не вегетаріанець', 'Ich bin kein Vegetarier mehr', 'Je ne suis plus végétarien'),

  // log_health
  ('log_health', {'kind': 'symptom', 'value': 'tired'}, 'Я сьогодні дуже втомлений', 'Ich bin heute sehr müde', 'Je suis très fatigué aujourd’hui'),
  ('log_health', {'kind': 'symptom', 'value': 'bloat'}, 'Здуття після обіду, досить сильне', 'Blähungen nach dem Mittagessen, ziemlich schlimm', 'Ballonnements après le déjeuner, assez forts'),
  ('log_health', {'kind': 'symptom', 'value': 'headache'}, 'Запиши головний біль, сила 3', 'Trag Kopfschmerzen ein, Stärke 3', 'Note un mal de tête, intensité 3'),
  ('log_health', {'kind': 'glucose', 'value': '140'}, 'Мій рівень глюкози 140', 'Mein Blutzucker ist 140', 'Ma glycémie est à 140'),
  ('log_health', {'kind': 'blood_pressure', 'value': '130'}, 'Тиск 130 на 85', 'Blutdruck 130 zu 85', 'Tension 130 sur 85'),
  ('log_health', {'kind': 'weight', 'value': '72.5'}, 'Я сьогодні важу 72.5 кг', 'Ich wiege heute 72,5 kg', 'Je pèse 72,5 kg aujourd’hui'),

  // condition_info
  ('condition_info', {'question': 'diabet'}, 'Чи можна їсти банани при діабеті?', 'Darf ich mit Diabetes Bananen essen?', 'Puis-je manger des bananes si j’ai du diabète ?'),
  ('condition_info', {'question': 'gout'}, 'Яких продуктів уникати при подагрі?', 'Welche Lebensmittel sollte ich bei Gicht meiden?', 'Quels aliments éviter avec la goutte ?'),
  ('condition_info', {'question': 'pressure'}, 'Чи шкідлива сіль при високому тиску?', 'Ist Salz schlecht bei Bluthochdruck?', 'Le sel est-il mauvais pour l’hypertension ?'),

  // open_camera
  ('open_camera', {'mode': 'photo'}, 'Відскануй мій холодильник', 'Scanne meinen Kühlschrank', 'Scanne mon frigo'),
  ('open_camera', {'mode': 'live'}, 'Відкрий камеру в живому режимі', 'Öffne die Live-Kamera', 'Ouvre la caméra en direct'),

  // my_patterns
  ('my_patterns', {}, 'Я часто пропускаю сніданок?', 'Lasse ich oft das Frühstück aus?', 'Est-ce que je saute souvent le petit-déjeuner ?'),

  // reply
  ('reply', {}, 'Привіт!', 'Hallo!', 'Salut !'),
  ('reply', {}, 'Дякую, це допомогло', 'Danke, das hat geholfen', 'Merci, ça m’a aidé'),
  ('reply', {}, 'Хто ти?', 'Wer bist du?', 'Qui es-tu ?'),
  ('reply', {}, 'Що таке білок?', 'Was ist Protein?', 'Qu’est-ce qu’une protéine ?'),
  ('reply', {}, 'Скільки варити яйце, щоб жовток був рідкий?', 'Wie lange koche ich ein Ei für ein weiches Eigelb?', 'Combien de temps cuire un œuf pour un jaune coulant ?'),
  ('reply', {}, 'Можливо, у мене алергія на молюсків', 'Vielleicht bin ich gegen Schalentiere allergisch', 'Je suis peut-être allergique aux fruits de mer'),

  // two requests in one message
  ('log_meal+lookup_nutrition', {'items': 'egg'}, 'Я з’їв два яйця, скільки білка в яйці?', 'Ich habe zwei Eier gegessen, wie viel Protein hat ein Ei?', 'J’ai mangé deux œufs, combien de protéines dans un œuf ?'),
  ('log_meal+nutrition_status', {'items': 'banana'}, 'Запиши банан на сніданок і покажи мої підсумки за сьогодні', 'Trag eine Banane zum Frühstück ein und zeig meine Summen für heute', 'Note une banane au petit-déjeuner et montre mes totaux du jour'),
];

/// Ukrainian, German and French, each a [Q] with its language.
final agentQueriesI18n = <({String lang, Q q})>[
  for (final (tool, args, uk, de, fr) in _set) ...[
    (lang: 'uk', q: (q: uk, tool: tool, args: args)),
    (lang: 'de', q: (q: de, tool: tool, args: args)),
    (lang: 'fr', q: (q: fr, tool: tool, args: args)),
  ],
];

/// The English set, with the router's own water and recipe-list cases added.
final agentQueriesEn = <({String lang, Q q})>[
  for (final q in agentQueries) (lang: 'en', q: q),
  (lang: 'en', q: (q: 'I drank 2 glasses of water', tool: 'log_meal', args: {'items': 'water'})),
  (lang: 'en', q: (q: 'Am I low on iron today?', tool: 'nutrition_status', args: {'period': 'today'})),
];
