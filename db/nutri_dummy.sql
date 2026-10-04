-- DUMMY development data. Approximate per-100 g values; not for real use.
-- The real nutri.db replaces this file's output entirely.

INSERT INTO meta VALUES
  ('schema_version', '1'),
  ('embedding_model', 'embeddinggemma-300m'),
  ('built_at', 'dummy');

INSERT INTO foods (id, name, kcal, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg) VALUES
  (1,  'chicken breast, cooked', 165, 31,   3.6,  0,    0,    0,    74),
  (2,  'white rice, cooked',     130, 2.7,  0.3,  28,   0.4,  0.1,  1),
  (3,  'brown rice, cooked',     123, 2.7,  1.0,  25.6, 1.6,  0.2,  4),
  (4,  'broccoli',               34,  2.8,  0.4,  6.6,  2.6,  1.7,  33),
  (5,  'egg',                    143, 12.6, 9.5,  0.7,  0,    0.4,  142),
  (6,  'spinach',                23,  2.9,  0.4,  3.6,  2.2,  0.4,  79),
  (7,  'feta cheese',            264, 14.2, 21.3, 4.1,  0,    4.1,  1116),
  (8,  'tomato',                 18,  0.9,  0.2,  3.9,  1.2,  2.6,  5),
  (9,  'onion',                  40,  1.1,  0.1,  9.3,  1.7,  4.2,  4),
  (10, 'olive oil',              884, 0,    100,  0,    0,    0,    2),
  (11, 'salmon',                 208, 20,   13,   0,    0,    0,    59),
  (12, 'zucchini',               17,  1.2,  0.3,  3.1,  1.0,  2.5,  8),
  (13, 'avocado',                160, 2,    14.7, 8.5,  6.7,  0.7,  7),
  (14, 'banana',                 89,  1.1,  0.3,  22.8, 2.6,  12.2, 1),
  (15, 'oats',                   389, 16.9, 6.9,  66.3, 10.6, 0,    2),
  (16, 'greek yogurt, plain',    59,  10.2, 0.4,  3.6,  0,    3.2,  36),
  (17, 'almonds',                579, 21.2, 49.9, 21.6, 12.5, 4.4,  1),
  (18, 'peanuts',                567, 25.8, 49.2, 16.1, 8.5,  4.7,  18),
  (19, 'lentils, cooked',        116, 9,    0.4,  20.1, 7.9,  1.8,  2),
  (20, 'potato, boiled',         87,  1.9,  0.1,  20.1, 1.8,  0.9,  5),
  (21, 'milk, whole',            61,  3.2,  3.3,  4.8,  0,    5.1,  43),
  (22, 'pasta, cooked',          158, 5.8,  0.9,  30.9, 1.8,  0.6,  1),
  (23, 'soy sauce',              53,  8.1,  0.6,  4.9,  0.8,  0.4,  5493),
  (24, 'tofu',                   76,  8,    4.8,  1.9,  0.3,  0.6,  7),
  (25, 'chickpeas, cooked',      164, 8.9,  2.6,  27.4, 7.6,  4.8,  7);

INSERT INTO recipes (id, title, instructions, servings, minutes, tags, texture) VALUES
  (1, 'Chicken broccoli stir-fry',
      'Slice the chicken. Stir-fry in oil 6 min, add broccoli 4 min, add soy sauce. Serve on rice.',
      2, 20, 'dinner,high-protein,quick', NULL),
  (2, 'Shakshuka',
      'Soften onion in oil, add tomatoes and simmer 10 min. Crack in eggs, cover 6 min, top with feta.',
      2, 25, 'breakfast,vegetarian', NULL),
  (3, 'Lentil soup',
      'Cook onion in oil, add lentils, tomato, diced potato and water. Simmer 30 min.',
      4, 40, 'lunch,vegan,soup,high-fiber', 'soft'),
  (4, 'Overnight oats with banana',
      'Mix oats and milk, refrigerate overnight. Top with sliced banana and almonds.',
      1, 5, 'breakfast,vegetarian,quick', NULL),
  (5, 'Salmon zucchini bowl',
      'Bake salmon 15 min. Saute zucchini and spinach in oil. Serve together.',
      2, 25, 'dinner,pescatarian,low-carb', NULL),
  (6, 'Potato spinach puree',
      'Boil potatoes, blend with wilted spinach, warm milk and oil until smooth.',
      2, 25, 'dinner,vegetarian,soft-food', 'pureed'),
  (7, 'Chickpea tofu curry',
      'Fry onion, add tomato, chickpeas and cubed tofu. Simmer 15 min with spices.',
      3, 30, 'dinner,vegan,high-protein', NULL);

INSERT INTO recipe_ingredients (recipe_id, food_id, grams) VALUES
  (1, 1, 300), (1, 4, 250), (1, 23, 30), (1, 10, 15), (1, 3, 300),
  (2, 5, 200), (2, 8, 400), (2, 9, 100), (2, 7, 60), (2, 10, 15),
  (3, 19, 400), (3, 9, 100), (3, 8, 200), (3, 20, 200), (3, 10, 15),
  (4, 15, 50), (4, 21, 150), (4, 14, 100), (4, 17, 15),
  (5, 11, 300), (5, 12, 300), (5, 10, 15), (5, 6, 100),
  (6, 20, 400), (6, 6, 100), (6, 21, 100), (6, 10, 10),
  (7, 25, 300), (7, 24, 200), (7, 8, 300), (7, 9, 100), (7, 10, 15);

INSERT INTO dishes (id, name, serving_g, recipe_id, kcal, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg) VALUES
  (1, 'lasagna',            350, NULL, 135, 7.5, 5.5, 13.5, 1.2, 2.8, 400),
  (2, 'caesar salad',       250, NULL, 127, 7,   9,   5,    1.5, 1.5, 330),
  (3, 'pizza margherita',   107, NULL, 266, 11,  10,  33,   2.3, 3.6, 598),
  (4, 'shakshuka',          350, 2,    NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Barcodes in the 2xx in-store range: not real products.
INSERT INTO products (barcode, name, kcal, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg) VALUES
  ('2000000000015', 'Dummy penne pasta, dry',   359, 12.5, 2,   71.2, 3,   3.5, 6),
  ('2000000000022', 'Dummy plain yogurt 2%',    63,  5.3,  2,   7,    0,   7,   70),
  ('2000000000039', 'Dummy wholegrain cereal',  370, 10,   4.5, 70,   9,   12,  300);

INSERT INTO allergens (food_id, allergen) VALUES
  (5, 'egg'), (7, 'milk'), (16, 'milk'), (21, 'milk'), (17, 'tree nuts'),
  (18, 'peanuts'), (11, 'fish'), (23, 'soy'), (23, 'gluten'), (24, 'soy'), (22, 'gluten');

INSERT INTO conditions (id, name) VALUES
  (1, 'diabetes_t2'), (2, 'hypertension'), (3, 'gout'), (4, 'als'), (5, 'ms');

INSERT INTO condition_rules (condition_id, nutrient, max_per_day, note) VALUES
  (1, 'sugar_g',   25,   'DUMMY rule for development'),
  (1, 'carbs_g',   200,  'DUMMY rule for development'),
  (2, 'sodium_mg', 1500, 'DUMMY rule for development');

INSERT INTO docs (id, source, text) VALUES
  (1, 'DUMMY', 'DUMMY TEXT. People with type 2 diabetes are often advised to limit added sugar and prefer high-fiber carbohydrates.'),
  (2, 'DUMMY', 'DUMMY TEXT. A lower sodium intake is commonly recommended for people with high blood pressure.'),
  (3, 'DUMMY', 'DUMMY TEXT. People with ALS may need texture-modified food and extra calories to maintain weight.'),
  (4, 'DUMMY', 'DUMMY TEXT. No single diet is proven for multiple sclerosis; a balanced diet with vitamin D is commonly discussed.');
