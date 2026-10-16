-- Medical data for nutri.db: conditions, daily limits, foods to avoid and the passages behind
-- condition_info. Curated by hand from the guidelines in nutrition-ai-assistant/data/raw_medical
-- (list: that folder's SOURCES.md), read 2026-10-10. Applied by tool/build_medical.py.
--
-- Rules for this file:
--  * Every limit and every passage names its guideline. Passages are paraphrased, never copied:
--    most sources are copyright of their publishers.
--  * A limit only tightens (the app takes the lowest max). Needs that go the other way, such as
--    more calories in ALS, live in the passages, never in condition_rules.
--  * condition_avoid holds only what a guideline says to AVOID, not what it says to limit:
--    those foods disappear from recipe suggestions.
--  * Condition ids are stable: profiles store them.
--  * foods.name is matched with REGEXP (Python re, registered by the builder).

-- Content release of nutri.db: the app (nutriDataVersion in lib/data/nutri_db.dart) replaces older copies.
INSERT OR REPLACE INTO meta (key, value) VALUES ('data_version', '4');

INSERT INTO conditions (id, name) VALUES
  (1, 'diabetes_t2'), (2, 'hypertension'), (3, 'gout'), (4, 'als'), (5, 'ms');

-- 10% of energy as sugar is 50 g at 2,000 kcal. The app counts total sugars, not only free
-- sugars, so the cap is stricter than the guideline, never looser.
INSERT INTO condition_rules (condition_id, nutrient, max_per_day, note) VALUES
  (1, 'sodium_mg', 2300, 'ADA Standards of Care in Diabetes 2026, rec. 5.20: sodium under 2,300 mg a day'),
  (1, 'sugar_g',   50,   'Added sugars under 10% of energy: Diabetes Canada CPG 2018 ch. 11; ADA 2026 rec. 5.25'),
  (2, 'sodium_mg', 2000, 'ESC 2024 hypertension guideline: about 2 g sodium a day or less; WHO and Hypertension Canada 2025: under 2 g'),
  (2, 'sugar_g',   50,   'ESC 2024 hypertension guideline: free sugars at most 10% of energy');

-- Gout: organ meats (ACR 2012 "avoid"; Oxford and West Suffolk NHS leaflets). Mixed whole-bird
-- composites ("meat and skin and giblets") are ordinary poultry and stay.
INSERT INTO condition_avoid (condition_id, food_id, note)
SELECT 3, id, 'Organ meat, high in purines: avoid with gout (ACR 2012; NHS dietary advice)' FROM foods
WHERE name REGEXP '(?i)^(beef|veal|lamb|pork|chicken|turkey|duck|goose|ox|mutton|calf|game meat|deer|venison|rabbit|moose|elk|caribou|bison|liver|liverwurst|braunschweiger)\b'
  AND name REGEXP '(?i)\b(liver|livers|liverwurst|braunschweiger|kidneys?|sweetbreads?|brains?|giblets|hearts?)\b'
  AND name NOT REGEXP '(?i)meat ?(and|&) ?(skin|skn)|\bbeans?\b|palm|artichoke';

-- Sugar-sweetened drinks: gout (ACR 2012 "avoid" HFCS-sweetened soft drinks and energy drinks) and
-- type 2 diabetes (ADA 2026 rec. 5.25: replace sugar-sweetened beverages, juices included). Sugar
-- >= 5 g/100 g leaves out diet and zero versions by their own numbers.
CREATE TEMP VIEW sugary_drinks AS
SELECT id FROM foods
WHERE sugar_g >= 5
  AND name REGEXP '(?i)\b(soft drinks?|carbonated|colas?|sodas?|soda pop|energy drinks?|root ?beer|ginger ale|lemonade|sports drinks?|fruit (drink|punch)|iced tea)\b'
  AND name NOT REGEXP '(?i)\b(diet|zero|sugar[- ]?free|unsweetened|artificially|low[- ]?cal\w*|alcohol\w*|vodka|rum|whisk\w*|cola cao|baking|bread|crackers?|candy|candies|gum\w*|hearts|ice cream|floats?|pops|popsicles?|sorbet|lollipops?|jel\w*|strings|twists|snacks?|chips?|cakes?|cookies?|bars?|syrup|mix|powder|pdr|concentrate|sauce|glaze|soup|babyfood|squash)\b';

INSERT INTO condition_avoid (condition_id, food_id, note)
SELECT 3, id, 'Sugar-sweetened drink: avoid with gout (ACR 2012)' FROM sugary_drinks;
INSERT INTO condition_avoid (condition_id, food_id, note)
SELECT 1, id, 'Sugar-sweetened drink: replace with water or no-calorie drinks (ADA Standards of Care 2026, rec. 5.25)' FROM sugary_drinks;
DROP VIEW sugary_drinks;

-- Passages for condition_info (FTS search, best two shown). Each names its condition, so a
-- question finds it.
INSERT INTO docs (id, source, text) VALUES
-- Type 2 diabetes (most also apply to type 1)
  (1, 'ADA Standards of Care in Diabetes 2026, section 5 (recs 5.10, 5.13)',
   'Diabetes: there is no single ideal split of calories between carbohydrate, protein and fat for people with diabetes. Meal plans should be individual, built around the person''s preferences, culture, medicines and goals, ideally with a registered dietitian.'),
  (2, 'ADA Standards of Care in Diabetes 2026 (recs 5.14, 5.30)',
   'Diabetes eating pattern: base meals on non-starchy vegetables, whole fruit, beans and lentils, lean protein, whole grains, nuts and seeds, and low-fat dairy or alternatives. Keep red meat, sugary drinks, sweets, refined grains and highly processed foods to a minimum. A Mediterranean-style diet, rich in oily fish, nuts and seeds, helps the heart and blood glucose.'),
  (3, 'ADA Standards of Care in Diabetes 2026 (recs 5.21, 5.22, 5.25)',
   'Diabetes and drinks: water is the best choice. Swap sugar-sweetened drinks, fruit juice included, for water or low- and no-calorie drinks, and keep foods with added sugar to a minimum. Non-nutritive sweeteners can replace sugar in moderation and for the short term.'),
  (4, 'ADA Standards of Care in Diabetes 2026 (recs 5.15, 5.24); Diabetes Canada CPG 2018, ch. 11',
   'Diabetes and carbohydrate: choose minimally processed, high-fibre carbohydrate, at least 14 g of fibre per 1,000 kcal. Eating less carbohydrate can improve blood glucose for some adults, and cutting processed foods is the easiest way to do it. Low glycaemic index foods such as pulses, whole grains and most fruit improve glucose and blood fats in type 2 diabetes.'),
  (5, 'Diabetes Canada CPG 2018, ch. 11; NICE NG28 (rec. 1.3.7)',
   'Diabetes and sugar: added sugars (table sugar, honey, syrups, fructose) are best kept under 10% of daily energy; above that they can raise blood triglycerides. Sugar naturally in whole fruit and plain milk is not added sugar. A small amount of sugary food can replace other carbohydrate in a meal, as long as total energy does not climb.'),
  (6, 'ADA Standards of Care in Diabetes 2026 (rec. 5.20)',
   'Diabetes and salt: keep sodium under 2,300 mg a day (about 6 g of salt). Most sodium comes from processed and restaurant food, so cooking from fresh ingredients is the most effective way to cut it.'),
  (7, 'ADA Standards of Care in Diabetes 2026 (recs 5.18, 5.19); NIDDK',
   'Diabetes and alcohol: adults who drink should stay within the recommended daily limits, and people who do not drink should not start. With insulin or sulfonylureas, alcohol can cause low blood glucose (hypoglycaemia) hours later: eat when drinking and check glucose afterwards.'),
  (8, 'ADA Standards of Care 2026 (rec. 5.12); ADA/EASD type 2 consensus 2022; Diabetes UK 2018',
   'Type 2 diabetes and weight: for people with overweight, losing at least 5-7% of body weight improves blood glucose. Larger, lasting weight loss can put type 2 diabetes into remission: in the DiRECT trial 64% of people who kept off 10 kg or more were in remission. Intensive weight-loss plans need the care team, because diabetes medicines may have to change.'),
  (9, 'ADA Standards of Care in Diabetes 2026 (recs 5.16, 5.17)',
   'Diabetes and supplements: vitamins, minerals such as magnesium or chromium, and herbs or spices such as cinnamon or aloe vera are not recommended for lowering blood glucose. Beta-carotene supplements should be avoided: they bring no benefit and can harm some people.'),
  (10, 'ADA Standards of Care 2026 (recs 5.27, 5.28); NICE NG17 (recs 1.4.1-1.4.3)',
   'Diabetes with insulin (type 1 and type 2): carbohydrate counting helps match mealtime insulin to food, and NICE recommends training in it for type 1 diabetes. People on fixed insulin doses should eat similar amounts of carbohydrate at similar times each day to lower the risk of hypoglycaemia. Fat and protein also affect glucose after a meal.'),
  (11, 'ADA Standards of Care in Diabetes 2026 (rec. 5.26)',
   'Diabetes and keto diets: people taking an SGLT2 inhibitor (for example empagliflozin or dapagliflozin) can develop ketoacidosis and should not follow a ketogenic diet. They should know the warning signs and how to check ketones.'),
  (12, 'ADA Standards of Care in Diabetes 2026 (recs 5.29, 5.31)',
   'Diabetes and heart health: include more plant protein such as nuts, seeds, beans and lentils, and limit foods high in saturated fat such as fatty meat, butter and pastries, to lower cardiovascular risk.'),
  (13, 'NIDDK, Healthy Living with Diabetes',
   'Diabetes and exercise: physical activity lowers blood glucose, and low glucose can last for hours afterwards, especially with insulin or sulfonylureas. Check glucose before, during and after activity, and ask the care team whether to eat carbohydrate or take less insulin. Sports drinks are high in sugar and not needed for moderate activity.'),
  (14, 'NICE NG18 (recs 1.2.38-1.2.54)',
   'Type 1 diabetes in children and young people: families should be offered carbohydrate-counting education and dietitian support. A low glycaemic index diet may help glucose control in children. Extra carbohydrate may be needed before, during and after exercise, and insulin or food may need adjusting when activity changes.'),
-- High blood pressure
  (15, 'ESC 2024 guideline on elevated blood pressure and hypertension; Hypertension Canada 2025',
   'High blood pressure and salt: keep sodium to about 2 g a day or less, roughly 5 g of salt or one teaspoon, counting the salt already in food. Lowering salt lowers blood pressure in a near-linear way. More than 70% of sodium in a typical Western diet comes from processed food, not the salt shaker.'),
  (16, 'NHLBI, Your Guide to Lowering Your Blood Pressure With DASH',
   'High blood pressure and the DASH diet: DASH is rich in fruit, vegetables, low-fat dairy, whole grains, fish, poultry and nuts, with less red meat, sweets and sugary drinks. In trials it lowered blood pressure within two weeks, and most of all when sodium was cut to 1,500 mg a day. Its daily goals include about 4,700 mg potassium, 1,250 mg calcium, 500 mg magnesium and 30 g fibre.'),
  (17, 'ESC 2024 hypertension guideline; NICE NG136 (rec. 1.4.5)',
   'High blood pressure and potassium: eating more potassium, from fruit and vegetables or a potassium-enriched salt substitute, lowers blood pressure. But people with kidney disease, older people, people with diabetes, pregnant women and anyone taking ACE inhibitors, ARBs, spironolactone or potassium-sparing diuretics should not use potassium salt substitutes without their doctor: potassium can build up dangerously.'),
  (18, 'ESC 2024 hypertension guideline; Hypertension Canada 2025',
   'High blood pressure and alcohol: ESC recommends under 14 units a week for men and under 8 for women, and no alcohol is best for health. Cutting down lowers blood pressure most in people who drink three or more drinks a day.'),
  (19, 'ESC 2024 hypertension guideline',
   'High blood pressure and diet: eat more vegetables, fresh fruit, fish, nuts and olive oil, less red meat, and choose low-fat dairy; a Mediterranean or DASH diet is recommended. Aim for a stable BMI of 20-25 and a waist under 94 cm for men and 80 cm for women.'),
  (20, 'ESC 2024 hypertension guideline',
   'High blood pressure and sugar: keep free sugars to at most 10% of energy and cut down on sugar-sweetened drinks, soft drinks and fruit juice included.'),
  (21, 'ESC 2024 hypertension guideline; NICE NG136 (recs 1.4.4, 1.4.6)',
   'High blood pressure, coffee and supplements: ordinary coffee drinking is not linked to a higher risk of hypertension, but energy drinks with caffeine and taurine raise blood pressure and very high caffeine intake should be avoided. Calcium, magnesium or potassium supplements are not a treatment for blood pressure. Large amounts of liquorice can raise blood pressure.'),
-- Gout
  (22, 'NICE NG219 (recs 1.4.1, 1.4.2); ACR 2012 gout guideline part 1',
   'Gout and diet: there is not enough evidence that any particular diet prevents gout flares or lowers urate, so a healthy, balanced diet is advised. Excess weight and heavy drinking can make flares worse. Diet alone usually lowers urate by only about 10-18%, so most people with gout also need long-term urate-lowering medicine.'),
  (23, 'ACR 2012 gout guideline part 1; Oxford University Hospitals and West Suffolk NHS gout diet leaflets',
   'Gout and purines: avoid organ meats such as liver, kidney, heart and sweetbreads. Limit portions of beef, lamb, pork, game and purine-rich seafood such as sardines, anchovies, herring, mackerel, mussels, shrimp, crab and fish roe. Purine-rich vegetables do not need to be avoided.'),
  (24, 'ACR 2012 gout guideline part 1; Oxford University Hospitals and West Suffolk NHS gout diet leaflets',
   'Gout-friendly foods: low-fat dairy (milk, yoghurt, cheese), vegetables and fruit, eggs, bread, pasta, rice and potatoes, beans and lentils, and nuts are all fine to eat regularly. Low-fat dairy and coffee appear to protect against gout.'),
  (25, 'ACR 2020 gout guideline; ACR 2012 part 1; Oxford University Hospitals NHS',
   'Gout and alcohol: limiting alcohol is recommended for everyone with gout. Beer raises the risk most, but wine and spirits count too. More than one or two drinks in 24 hours was linked to a 40% higher risk of a flare. Avoid alcohol completely during a flare and while gout is poorly controlled.'),
  (26, 'ACR 2020 gout guideline; ACR 2012 part 1; Oxford University Hospitals NHS',
   'Gout and sugary drinks: fructose raises uric acid. Avoid soft drinks and energy drinks sweetened with high-fructose corn syrup, and limit fruit juice, smoothies, table sugar and sweet desserts. Water, tea and coffee are better choices.'),
  (27, 'ACR 2020 gout guideline; West Suffolk and Oxford University Hospitals NHS',
   'Gout and weight loss: for people with overweight, steady weight loss lowers uric acid; a drop in BMI of more than 5% was linked to 40% fewer flares. Crash diets, fasting and ketogenic diets should be avoided: they make the kidneys hold on to uric acid and can trigger attacks.'),
  (28, 'Oxford University Hospitals and West Suffolk NHS gout diet leaflets',
   'Gout and fluids: drink at least 2 litres of sugar-free fluid a day, more in hot weather or with exercise, unless a doctor has restricted fluids (for example in kidney or heart failure).'),
  (29, 'ACR 2020 gout guideline; NICE NG219',
   'Gout and supplements: vitamin C supplements are not recommended for gout, and the evidence for cherries or cherry extract is too weak for a recommendation.'),
-- ALS / motor neurone disease
  (30, 'ESPEN guideline on clinical nutrition in neurology 2018; Les Turner ALS Foundation',
   'ALS and weight: people with ALS (motor neurone disease) burn more energy than usual, through breathing, movement and muscle twitching. Losing weight is linked to shorter survival, so the aim is to keep weight stable, or to gain weight when BMI is below 25. Weight should be checked regularly from diagnosis.'),
  (31, 'Les Turner ALS Foundation nutrition guide; ESPEN 2018 (rec. 11)',
   'ALS and calories: eat small meals every 2-3 hours, choose full-fat rather than diet foods, and add calories without adding volume: olive or canola oil, nut butters, avocado, cheese, eggs, milk powder, butter, cream sauces. If weight keeps falling, oral nutritional supplements are recommended; "plus" drinks carry more calories than "high-protein" ones.'),
  (32, 'MND Association, Managing dysphagia; ESPEN 2018 (recs 12-13)',
   'ALS and swallowing (dysphagia): soft, moist food with sauce or gravy, cut small or mashed, is easier to swallow. Foods often avoided are mixed textures (cereal in milk, minestrone), husks and skins (sweetcorn, beans, grapes), stringy foods (celery, pineapple, melted cheese), hard foods (nuts, chewy sweets), crumbly or dry foods (toast, biscuits, flaky pastry) and foods that turn sticky in the mouth. A speech and language therapist sets the right texture (IDDSI levels) and posture, such as tucking the chin when swallowing.'),
  (33, 'MND Association, Managing dysphagia; ESPEN 2018',
   'ALS and thickened drinks: thin liquids are the hardest to swallow safely. Thickening powder or naturally thicker drinks may be suggested, but only a speech and language therapist should recommend thickened fluids, because they carry risks as well as benefits. Coughing or choking when eating, chest infections and long meals are signs to ask for a swallowing assessment.'),
  (34, 'NICE NG42 (recs 1.11.6-1.11.8); EAN ALS guideline 2024; ESPEN 2018',
   'ALS and feeding tubes: a gastrostomy (feeding tube) should be discussed early and at regular intervals. Placing it early is safer; a late gastrostomy carries more risk from low body weight, weaker breathing and dehydration. Some people choose not to have one, and that is their decision.'),
  (35, 'Les Turner ALS Foundation; MND Association, Managing dysphagia; NICE NG42 (rec. 1.11.2)',
   'ALS and drinking: when drinking gets difficult, dehydration is common and can cause constipation and thicker saliva. Signs include dark urine, dizziness, headaches, confusion and more tiredness. If thin drinks like water cause coughing, thicker ones such as milkshakes, smoothies or drinkable yoghurt may be easier, and soups, casseroles and stewed fruit add fluid too.'),
-- Multiple sclerosis
  (36, 'MS Society UK, Diet and MS (2024); NICE NG220 (rec. 1.5.8); ESPEN 2018',
   'MS and diet: no diet has been shown to treat multiple sclerosis or slow it down. A healthy, balanced diet benefits general health, but there is no evidence that a specific diet improves MS fatigue. Restrictive diets risk missing nutrients; talk to the MS team or a dietitian before cutting out food groups. A gluten-free diet is not recommended unless there is coeliac disease.'),
  (37, 'MS Society UK, Diet and MS (2024); NICE NG220 (rec. 1.9.1); ESPEN 2018',
   'MS and vitamin D: UK advice is for everyone to consider 10 micrograms (400 IU) of vitamin D a day, especially from October to March. Vitamin D should not be taken as a treatment for MS itself. Ask the MS team for a blood test before taking high doses: too much vitamin D can cause serious health problems.'),
  (38, 'NICE NG220 (rec. 1.9.2)',
   'MS and omega-3: omega-3 or omega-6 fatty acid supplements are not offered as an MS treatment; there is no evidence that they change relapses or progression. Oily fish is still part of a healthy diet.'),
  (39, 'MS Society UK, Diet and MS (2024)',
   'MS, alcohol and coffee: alcohol can make balance and coordination worse, irritate the bladder and disturb sleep. Coffee does not need to be stopped: the effects of caffeine vary from person to person, but about four cups a day appears healthy for most. Eating less than 6 g of salt a day is sensible.'),
  (40, 'HealthLinkBC, Healthy eating guidelines for MS',
   'MS healthy plate: fill half the plate with vegetables and fruit, a quarter with whole grains such as oats, barley or brown rice, and a quarter with protein such as beans, fish, poultry, tofu, eggs or nuts. Prefer unsaturated fats (olive or canola oil, nuts, seeds, oily fish) over butter and fatty meat, and keep highly processed foods and sugary drinks occasional.'),
  (41, 'ESPEN 2018 (recs 43-49); HealthLinkBC',
   'MS, swallowing and weight: swallowing problems are common in MS, so they should be screened for over time. Texture-modified foods and drinks help when swallowing is unsafe. Unplanned weight loss or being underweight needs early dietary help, and oral nutritional supplements if food is not enough.'),
-- Eating disorders
  (42, 'Academy for Eating Disorders, Medical Care Guide, 4th ed. 2021; NIMH',
   'Eating disorders affect people of every age, gender and body size, and can be dangerous even at a normal weight. Signs include restricting food, binge eating, making oneself vomit, misusing laxatives, diuretics, diet pills or insulin, fasting and excessive exercise. Early help from a doctor and specialist team matters; in the US, call or text 988 in a crisis.'),
  (43, 'Academy for Eating Disorders, Medical Care Guide, 4th ed. 2021; RCPsych MEED 2022',
   'Eating disorders and refeeding: after a period of very little food, starting to eat again can cause refeeding syndrome, a dangerous drop in phosphate, potassium and magnesium that can affect the heart. Restoring nutrition after severe restriction should be medically supervised.'),
  (44, 'RCPsych MEED 2022 (medical emergencies in eating disorders)',
   'Eating disorder warning signs: someone can look well and still be at high medical risk. Fainting, feeling dizzy on standing, a very slow heart rate or a low body temperature need urgent medical assessment.'),
  (45, 'NICE NG69',
   'Eating disorders and family: people with an eating disorder may find it hard to talk about it. Family members and carers often feel guilty or responsible, and they can be involved in treatment and supported themselves.'),
-- General healthy eating
  (46, 'Dietary Guidelines for Americans 2025-2030; WHO via Hypertension Canada 2025',
   'Salt for everyone: the general population aged 14 and over should eat less than 2,300 mg of sodium a day; WHO advises under 2,000 mg. Most sodium comes from processed and packaged food.'),
  (47, 'Dietary Guidelines for Americans 2025-2030 and 2020-2025; Health Canada Dietary Guidelines 2019',
   'Added sugar for everyone: no amount of added sugar is needed for health. Keep added sugars under 10% of calories (about 50 g on 2,000 kcal) and, per the 2025-2030 US guidelines, under 10 g in one meal. Sugary drinks and sweets should not be regular; water is the drink of choice. Sugars naturally in fruit and plain milk do not count as added sugar.'),
  (48, 'Dietary Guidelines for Americans 2025-2030; Health Canada Dietary Guidelines 2019',
   'Fats for everyone: saturated fat should stay under 10% of daily calories. Prefer foods with unsaturated fat such as olive oil, nuts, seeds and oily fish, and eat highly processed foods less often.'),
  (49, 'Health Canada Dietary Guidelines 2019; Dietary Guidelines for Americans 2025-2030',
   'Healthy eating basics: eat vegetables, fruit, whole grains and protein foods regularly, and choose plant-based protein such as beans, lentils, tofu and nuts more often. Whole and frozen vegetables and fruit are both good choices; 100% juice is best limited or diluted.'),
  (50, 'Dietary Guidelines for Americans 2025-2030',
   'Alcohol for everyone: drinking less is better for health. Pregnant women, people recovering from alcohol use disorder and people taking medicines or with conditions that interact with alcohol should not drink at all.'),
  (51, 'Dietary Guidelines for Americans 2020-2025; ADA Standards of Care 2026 (rec. 5.24)',
   'Fibre for everyone: most people eat too little fibre, which the US guidelines call a dietary component of public health concern. About 14 g of fibre per 1,000 kcal is the usual target; whole grains instead of refined grains, vegetables, fruit, beans and lentils raise it.');
