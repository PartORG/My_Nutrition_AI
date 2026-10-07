# nutri.db data sources

Built by `tool/build_real_nutri_db.py` on 2026-10-07 from `nutrition-ai-assistant/data/raw_nutritions` and `raw_recipes`. Every file in both folders is listed; byte-identical copies are read once.

| table | rows |
|---|---|
| foods | 50,518 |
| allergens | 50,161 |
| recipes | 166,094 |
| recipe_ingredients | 1,370,274 |
| dishes | 620 |
| products | 263,164 |
| conditions | 5 |
| condition_rules | 3 |
| condition_avoid | 4 |
| docs | 4 |
| nutri.db bytes | 290,131,968 |
| foods used by recipes | 2,094 |
| recipes renamed (same title, other ingredients) | 24,604 |

## Rules

- Non-authoritative nutrition rows must pass range checks and kcal ≈ 4·protein + 4·carbs + 9·fat (±20 %, ±20 kcal; alcohol exempt).
- A recipe is kept only if it states servings and **every** ingredient line maps to a food and a gram amount (water, salt-and-pepper-to-taste and similar are allowed to carry no nutrition).
- An ingredient line whose words imply an allergen the matched food lacks is rejected, so a wrong match can never hide an allergen from the filter.
- Where the source publishes calories per serving, ours must agree within ±30 % (±80 kcal).
- Recipes are ranked by rating × log(reviews) (+1 when calories were confirmed) and kept until the 300 MB budget.

## Per file

| file | rows | kept | used for | dropped (reason: rows) | notes |
|---|---|---|---|---|---|
| `raw_nutritions/ABBREV.csv` | 8,790 | 8,781 | foods (generic, authoritative) | same name as a more authoritative food: 9 | USDA SR28 abbreviated file. |
| `raw_nutritions/BakedFoodNutritions.csv` | 656 | 422 | foods (branded baked goods) | same name as a more authoritative food: 221; kcal does not match protein/fat/carbs: 13 | Per 100 g; total fat = sum of the fatty-acid columns (no total fat column); 'Sodium-g' is in mg. |
| `raw_nutritions/FOOD-DATA-GROUP1 (1).csv` | 551 | 0 | - | duplicate file (same MD5 as FOOD-DATA-GROUP1.csv): 551 | Byte-identical copy of `raw_nutritions/FOOD-DATA-GROUP1.csv` (same MD5), read once. |
| `raw_nutritions/FOOD-DATA-GROUP1.csv` | 551 | 0 | - | per serving with no serving weight: 551 | Per serving with unknown weight (cream cheese 51 kcal = one tablespoon). |
| `raw_nutritions/FOOD-DATA-GROUP2.csv` | 319 | 0 | - | per serving with no serving weight: 319 | Per serving with unknown weight (cream cheese 51 kcal = one tablespoon). |
| `raw_nutritions/FOOD-DATA-GROUP3 (1).csv` | 571 | 0 | - | duplicate file (same MD5 as FOOD-DATA-GROUP3.csv): 571 | Byte-identical copy of `raw_nutritions/FOOD-DATA-GROUP3.csv` (same MD5), read once. |
| `raw_nutritions/FOOD-DATA-GROUP3.csv` | 571 | 0 | - | per serving with no serving weight: 571 | Per serving with unknown weight (cream cheese 51 kcal = one tablespoon). |
| `raw_nutritions/FOOD-DATA-GROUP4.csv` | 232 | 0 | - | per serving with no serving weight: 232 | Per serving with unknown weight (cream cheese 51 kcal = one tablespoon). |
| `raw_nutritions/FOOD-DATA-GROUP5.csv` | 722 | 0 | - | per serving with no serving weight: 722 | Per serving with unknown weight (cream cheese 51 kcal = one tablespoon). |
| `raw_nutritions/FastFoodNutritionMenuV2.csv` | 1,148 | 0 | - | no serving weight (per-100 g impossible): 1,148 | Fast-food items per serving. |
| `raw_nutritions/FastFoodNutritionMenuV3.csv` | 1,147 | 0 | - | no serving weight (per-100 g impossible): 1,147 | Same as V2 with one row fewer. |
| `raw_nutritions/Food Composition.csv` | 1,561 | 0 | - | no nutrient values: 1,561 | Australian Food Composition (AFCD) food details: descriptions and sampling notes, no nutrient values. |
| `raw_nutritions/Food_Nutrition_Dataset.csv` | 205 | 118 | foods | same name as a more authoritative food: 43; kcal does not match protein/fat/carbs: 33; value out of range: 11 | USDA-style names, per 100 g; no fiber/sugar/sodium. |
| `raw_nutritions/Indian_Food_Nutrition_Processed.csv` | 1,014 | 952 | foods (Indian dishes, per 100 g) | kcal does not match protein/fat/carbs: 34; same name as a more authoritative food: 28 | Indian Nutrient Databank style, per 100 g; no serving weight so they are foods, not camera dishes. |
| `raw_nutritions/Nutrition_Value_Dataset.csv` | 530 | 143 | dishes | no gram weight for the serving: 386; kcal does not match protein/fat/carbs: 1 | Indian fast-food chains, 'Per Serve Size' in g. |
| `raw_nutritions/Nutritional Datasets for New Zealand Foods.xlsx` | 2,767 | 2,740 | foods (generic, authoritative) | sheet 'FOODFiles-AminoAcids' not nutrition per food (see note): 2,767; sheet 'Matching Table' not nutrition per food (see note): 418; sheet 'Recipes - Drew et al 2020' not nutrition per food (see note): 365; same name as a more authoritative food: 27; sheet 'Introduction' not nutrition per food (see note): 1 | NZ FOODfiles 2018. Sheet FOODFiles-Nutrients loaded. FOODFiles-AminoAcids: amino acids only (not in the schema). Matching Table: formulas pointing back at FOODFiles-Nutrients (duplicates). 'Recipes - Drew et al 2020': ingredient percentages for survey food groups, no instructions or amounts (cannot be recipes). Introduction: text. |
| `raw_nutritions/NutritionalFacts_Fruit_Vegetables_Seafood (1).csv` | 62 | 0 | - | duplicate file (same MD5 as NutritionalFacts_Fruit_Vegetables_Seafood.csv): 62 | Byte-identical copy of `raw_nutritions/NutritionalFacts_Fruit_Vegetables_Seafood.csv` (same MD5), read once. |
| `raw_nutritions/NutritionalFacts_Fruit_Vegetables_Seafood.csv` | 62 | 0 | same as the lower-case file | duplicate of nutritionalfacts_fruit_vegetables_seafood.csv: 62 | Older export of nutritionalfacts_fruit_vegetables_seafood.csv (no header row, 54 of its 61 rows). |
| `raw_nutritions/Top 100 Healthiest Food in the World.csv` | 98 | 0 | - | no fat/carbs values: 98 | Calories, protein, fiber only. |
| `raw_nutritions/calorie_dataset.csv` | 5,000 | 0 | - | no food names: 5,000 | Macro numbers with a calorie class, for ML. |
| `raw_nutritions/cleaned_nutrition_dataset_per100g.csv` | 3,454 | 0 | - | per serving with no serving weight: 3,454 | Claims per 100 g but holds the FOOD-DATA-GROUP per-serving values (margarine with yoghurt: 88 kcal). |
| `raw_nutritions/comprehensive_foods_usda.csv` | 40,000 | 25,427 | foods (Foundation generic, Branded) | SR Legacy = same foods as ABBREV.csv: 7,793; same name as a more authoritative food: 4,720; missing kcal/protein/fat/carbs: 991; kcal does not match protein/fat/carbs: 700; value out of range: 213; sugar above carbs: 81; protein+fat+carbs over 100 g per 100 g: 75 | USDA FoodData Central extract, per 100 g. |
| `raw_nutritions/daily_food_nutrition_dataset.csv` | 651 | 82 | dishes | no gram weight for the serving: 565; kcal does not match protein/fat/carbs: 4 | Per serving; only rows whose name states grams/ounces can be used. |
| `raw_nutritions/en.openfoodfacts.org.products.tsv` | 356,027 | 263,164 | products (barcodes) | missing kcal/protein/fat/carbs: 64,768; no product name: 17,454; kcal does not match protein/fat/carbs: 8,633; protein+fat+carbs over 100 g per 100 g: 684; sugar above carbs: 507; value out of range: 438; no valid barcode: 327; malformed line: 52 | Open Food Facts dump (Sep 2019). energy_100g is kJ; sodium_100g in g (or from salt_100g / 2.5). |
| `raw_nutritions/fastfood.csv` | 515 | 0 | - | no serving weight (per-100 g impossible): 515 | Fast-food items per serving. |
| `raw_nutritions/food.csv` | 7,413 | 818 | foods (merged into USDA SR28) | same food as ABBREV.csv (merged): 6,594; same name as a more authoritative food: 1 | USDA SR, same NDB numbers as ABBREV.csv. |
| `raw_nutritions/food1.csv` | 7,413 | 0 | - | duplicate file (same MD5 as food.csv): 7,413 | Byte-identical copy of `raw_nutritions/food.csv` (same MD5), read once. |
| `raw_nutritions/food_menu_nutrition_dataset.csv` | 7,500 | 0 | - | synthetic data: 7,500 | Generated: random chain/city/price combinations (e.g. a Five Guys 'Veggie Sub' in London). |
| `raw_nutritions/foods_allergens.csv` | 3,332 | 3,332 | allergen flags for foods_health_scores_allergens.csv | - | Open Food Facts extract: names and allergen flags, no nutrition values. 3332 rows add allergen flags to a product of foods_health_scores_allergens.csv. |
| `raw_nutritions/foods_dietary_restrictions.csv` | 4,997 | 4,997 | allergen flags for foods_health_scores_allergens.csv | - | Open Food Facts extract: names and allergen flags, no nutrition values. 4997 rows add allergen flags to a product of foods_health_scores_allergens.csv. |
| `raw_nutritions/foods_health_scores_allergens.csv` | 4,997 | 4,288 | foods (branded, with allergens) | missing kcal/protein/fat/carbs: 279; same name as a more authoritative food: 221; no name: 96; kcal does not match protein/fat/carbs: 92; sugar above carbs: 9; value out of range: 8; protein+fat+carbs over 100 g per 100 g: 4 | Open Food Facts extract without barcodes, per 100 g; allergen flags become allergens rows. |
| `raw_nutritions/foodstruct_nutritional_facts.csv` | 1,174 | 1,115 | foods (generic) | same name as a more authoritative food: 35; kcal does not match protein/fat/carbs: 24 | foodstruct.com, per 100 g; minerals in grams. |
| `raw_nutritions/healthy_eating_dataset.csv` | 2,000 | 0 | - | synthetic data: 2,000 | Generated: random meal names x cuisine x diet ('Kid Pasta, Indian, Keto'). |
| `raw_nutritions/healthy_foods_database.csv` | 9,028 | 4,470 | foods | same name as a more authoritative food: 3,302; kcal does not match protein/fat/carbs: 842; value out of range: 342; missing kcal/protein/fat/carbs: 43; protein+fat+carbs over 100 g per 100 g: 20; sugar above carbs: 9 | USDA-style names, per 100 g. |
| `raw_nutritions/menu.csv` | 260 | 121 | dishes | no gram weight for the serving: 139 | McDonald's menu; serving weight in 'Serving Size'. |
| `raw_nutritions/nutrients_csvfile.csv` | 335 | 112 | foods | missing kcal/protein/fat/carbs: 144; same name as a more authoritative food: 57; kcal does not match protein/fat/carbs: 16; value out of range: 5; protein+fat+carbs over 100 g per 100 g: 1 | Per household measure with grams; converted to per 100 g. |
| `raw_nutritions/nutrition (1).csv` | 505 | 101 | dishes (Food-101 labels) | other portion sizes of the same dish (same per-100 g): 404 | 101 Food-101 dish labels at 5 portion weights; one dish per label at the middle portion. |
| `raw_nutritions/nutrition (2).csv` | 8,789 | 8,689 | foods (names for USDA SR28) | no unambiguous ABBREV.csv match (name not used): 100 | USDA SR28 with long names; used to name ABBREV.csv rows. Same data as nutrition.xlsx. Named 8689 of 8790 SR28 foods; the rest keep the expanded short name. |
| `raw_nutritions/nutrition.csv` | 1,346 | 1,261 | foods (Indonesian foods, per 100 g) | kcal does not match protein/fat/carbs: 63; same name as a more authoritative food: 11; protein+fat+carbs over 100 g per 100 g: 7; value out of range: 4 | Indonesian food table, per 100 g. |
| `raw_nutritions/nutrition.xlsx` | 8,789 | 0 | same as nutrition (2).csv | duplicate of nutrition (2).csv: 8,789 | Same 8789 USDA SR28 rows and names as nutrition (2).csv (checked row by row); not loaded twice. |
| `raw_nutritions/nutrition_values.csv` | 499 | 239 | dishes | no gram weight for the serving: 258; value out of range: 1; protein+fat+carbs over 100 g per 100 g: 1 | Fast-food chains with serving grams. |
| `raw_nutritions/nutritionalfacts_fruit_vegetables_seafood.csv` | 61 | 20 | foods (generic) | same name as a more authoritative food: 39; no gram weight for the serving: 2 | FDA raw fruit/vegetable/seafood labels; serving grams in the name. |
| `raw_nutritions/starbucks.csv` | 77 | 0 | - | no serving weight (per-100 g impossible): 77 | Starbucks food items per serving. |
| `raw_recipes/1_Recipe_csv.csv` | 62,126 | 0 | - | no servings (per-serving nutrition impossible): 62,126 | allrecipes.com, 62k: ingredient lines and directions. |
| `raw_recipes/Multi_Cuisine_Recipe_Dataset.csv` | 620 | 0 | - | no servings (per-serving nutrition impossible): 620 | 620 Indian/world recipes with amounts. |
| `raw_recipes/RAW_recipes.csv` | 231,637 | 222,705 | recipe metadata (food.com) | no food.com row with ingredient amounts: 8,932 | food.com: minutes, tags, per-serving calories. Ingredients without amounts. 222705 rows give minutes/tags/calories to recipes kept from the files with amounts. |
| `raw_recipes/Receipes from around the world.csv` | 161 | 0 | - | ingredients have no amounts: 161 | 153 recipes: ingredient names, servings, calories. |
| `raw_recipes/RecipeNLG_dataset.csv` | 2,231,142 | 0 | - | no servings (per-serving nutrition impossible): 2,231,142 | RecipeNLG (2.2M, Recipes1M + gathered sites). Same file as full_dataset.csv (byte-identical). Licensed for non-commercial research only. |
| `raw_recipes/Recipes.csv` | 918 | 0 | recipes (Reddit posts) | no ingredient list found in the post: 417; no servings: 413; ingredient not matched to a food: 77; ingredient amount not convertible to grams: 4; no ingredient lines: 3; over the 300 MB size budget (lower-ranked): 2; no instructions: 1; ingredient matched only by name similarity, no published calories to confirm: 1 | Free-text Reddit posts; ingredients = bullet list under an 'Ingredients' heading, servings from 'Serves/Servings: N'. |
| `raw_recipes/Recipes_2.csv` | 861 | 0 | recipes (Reddit posts) | no servings: 507; no ingredient list found in the post: 250; ingredient not matched to a food: 96; ingredient amount not convertible to grams: 4; no ingredient lines: 3; over the 300 MB size budget (lower-ranked): 1 | Free-text Reddit posts; ingredients = bullet list under an 'Ingredients' heading, servings from 'Serves/Servings: N'. |
| `raw_recipes/Recipes_3.csv` | 670 | 0 | recipes (Reddit posts) | no servings: 385; no ingredient list found in the post: 210; ingredient not matched to a food: 70; ingredient amount not convertible to grams: 4; ingredient matched only by name similarity, no published calories to confirm: 1 | Free-text Reddit posts; ingredients = bullet list under an 'Ingredients' heading, servings from 'Serves/Servings: N'. |
| `raw_recipes/baking.json` | 614 | 26 | recipes (BBC Good Food) | ingredient not matched to a food: 550; ingredient amount not convertible to grams: 29; duplicate of a recipe already kept: 8; empty ingredient line: 1 | Metric ingredient lines, serves, published kcal per serving. |
| `raw_recipes/christmas_recipes.csv` | 42 | 0 | recipes (BBC, Christmas) | ingredient not matched to a food: 35; over the 300 MB size budget (lower-ranked): 3; empty ingredient line: 2; ingredient amount not convertible to grams: 1; ingredient matched only by name similarity, no published calories to confirm: 1 | Servings '10 serving(s)'; no published nutrition. |
| `raw_recipes/food_recipes.csv` | 8,009 | 0 | - | ingredients have no amounts: 8,009 | archanaskitchen.com, 8k: ingredient names separated by '|'. |
| `raw_recipes/full_dataset.csv` | 2,231,142 | 0 | - | duplicate file (same MD5 as RecipeNLG_dataset.csv): 2,231,142 | Byte-identical copy of RecipeNLG_dataset.csv (same MD5). |
| `raw_recipes/health.json` | 626 | 13 | recipes (BBC Good Food) | ingredient not matched to a food: 562; ingredient amount not convertible to grams: 45; duplicate of a recipe already kept: 3; calories differ from the source's published value: 3 | Metric ingredient lines, serves, published kcal per serving. |
| `raw_recipes/recipes.csv` | 522,517 | 0 | same as recipes.parquet | duplicate of recipes.parquet: 522,517 | CSV export of recipes.parquet: same 522,517 RecipeIds (checked), not read twice. |
| `raw_recipes/recipes.json` | 12,190 | 0 | - | German text and no servings (the app is English-only for now): 12,190 | chefkoch.de, 12k recipes in German. |
| `raw_recipes/recipes.parquet` | 522,517 | 498,314 | recipe metadata (food.com) | no food.com row with ingredient amounts: 24,203 | food.com: total time, keywords, category, rating, published calories per serving. Ingredient amounts here have no units, so lines come from recipes_ingredients.csv / recipes_w_search_terms.csv. 498314 rows give metadata to recipes read from the files with amounts. |
| `raw_recipes/recipes_97.json` | 1,022 | 17 | recipes (BBC Good Food) | ingredient not matched to a food: 947; ingredient amount not convertible to grams: 43; duplicate of a recipe already kept: 8; calories differ from the source's published value: 4; calories per serving implausible: 2; implausible amount: 1 | Metric ingredient lines, serves, published kcal per serving. |
| `raw_recipes/recipes_99.csv` | 1,090 | 311 | recipes (allrecipes) | ingredient not matched to a food: 472; ingredient amount not convertible to grams: 84; calories differ from the source's published value: 79; duplicate of a recipe already kept: 76; over the 300 MB size budget (lower-ranked): 34; no servings: 29; calories per serving implausible: 3; no ingredient with nutrition: 1; implausible amount: 1 | Servings and per-serving fat/carbs/protein (kcal derived). |
| `raw_recipes/recipes_extended.csv` | 62,126 | 0 | - | no servings (per-serving nutrition impossible): 62,126 | Same 62k allrecipes rows as 1_Recipe_csv.csv plus derived labels. |
| `raw_recipes/recipes_ingredients.csv` | 500,471 | 163,235 | recipes (food.com) | ingredient not matched to a food: 231,862; calories differ from the source's published value: 35,776; ingredient amount not convertible to grams: 32,432; calories per serving implausible: 18,697; same food.com recipe as recipes_ingredients.csv: 7,841; over the 300 MB size budget (lower-ranked): 4,777; no servings: 2,378; duplicate of a recipe already kept: 1,523; implausible amount: 772; ingredient words imply an allergen the matched food lacks: 683; empty ingredient line: 439; no ingredient lines: 35; no ingredient with nutrition: 21 | food.com recipes with full ingredient lines, servings and serving weight. |
| `raw_recipes/recipes_w_search_terms.csv` | 494,963 | 2,492 | recipes (food.com) | same food.com recipe as recipes_ingredients.csv: 487,125; ingredient not matched to a food: 3,396; ingredient amount not convertible to grams: 718; calories differ from the source's published value: 654; calories per serving implausible: 421; duplicate of a recipe already kept: 51; over the 300 MB size budget (lower-ranked): 40; no ingredient lines: 18; implausible amount: 13; no servings: 12; ingredient words imply an allergen the matched food lacks: 11; no ingredient with nutrition: 6; empty ingredient line: 5; no instructions: 1 | food.com recipes with full ingredient lines, servings and serving weight. |

## Carried over from the development data

No raw file covers conditions, condition rules or medical docs (`raw_medical/` was not part of this build), so those rows are copied unchanged from `db/nutri_dummy.sql` and are still **development values**:

- condition_avoid: 'banana' -> 'Bananas, raw'
- condition_avoid: 'soy sauce' -> 'Soy sauce made from soy and wheat (shoyu)'
- condition_avoid: 'feta cheese' -> 'Cheese, feta'
- condition_avoid: 'salmon' -> 'Fish, salmon, Atlantic, farmed, raw'

## Licensing (data owner to confirm before release)

- USDA SR28 / FoodData Central: public domain (US government).
- NZ FOODfiles: © Plant & Food Research / Ministry of Health; check the FOODfiles licence terms.
- Open Food Facts: Open Database License (ODbL) — attribution and share-alike of the database.
- food.com, BBC Good Food, allrecipes, Reddit text: scraped content; copyright stays with the authors/sites. RecipeNLG (not used) is non-commercial research only.
