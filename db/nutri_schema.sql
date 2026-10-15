-- nutri.db data contract, schema_version 3 (2: micronutrients on foods and in recipe_nutrition; 3: foods.source,
-- micronutrients on dishes and products, dishes linked to foods and recipes). Shared by all profiles, read-only
-- on the phone, replaced as a whole file. Build with tool/build_nutri_db.py.
--
-- Rules:
--  * Nutrition is per 100 g. Recipe nutrition is never stored: see recipe_nutrition.
--  * ids are stable across releases: never renumber or reuse an id. Users' saved
--    recipes and logs point at them.
--  * Adding tables or columns needs no version bump (the app selects named columns).
--    Renaming, removing or changing meaning bumps meta.schema_version, and so does a
--    column a new app requires (2: the micronutrients), so the app reinstalls an older file.
--  * docs.embedding: float32 little-endian x 768, made with meta.embedding_model and
--    the prefix 'title: none | text: '. Chunks <= 512 tokens, <= ~50k docs.

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,   -- schema_version, embedding_model, built_at
  value TEXT NOT NULL
);

CREATE TABLE foods (
  id        INTEGER PRIMARY KEY,
  name      TEXT NOT NULL,
  kcal      REAL NOT NULL,
  protein_g REAL NOT NULL,
  fat_g     REAL NOT NULL,
  carbs_g   REAL NOT NULL,
  fiber_g   REAL,
  sugar_g   REAL,
  sodium_mg REAL,
  serving_g REAL,  -- one typical piece/portion ("2 eggs" = 2 x serving_g); NULL = unknown
  -- Micronutrients per 100 g; NULL = unknown (not zero).
  calcium_mg     REAL,
  iron_mg        REAL,
  magnesium_mg   REAL,
  potassium_mg   REAL,
  vitamin_c_mg   REAL,
  vitamin_d_ug   REAL,
  vitamin_b12_ug REAL,
  -- Where the row comes from. Authoritative (government tables): usda_sr28, usda_sr, usda_fdc_foundation,
  -- usda_fndds, nz_foodfiles; foodstruct is USDA-derived generic; the rest are smaller or branded datasets.
  source         TEXT NOT NULL DEFAULT ''
);
-- Plain-name lookups ("Banana", staples, filling past meals) without scanning every food.
CREATE INDEX foods_name ON foods (name COLLATE NOCASE);

CREATE TABLE recipes (
  id           INTEGER PRIMARY KEY,
  title        TEXT NOT NULL,
  instructions TEXT NOT NULL,
  servings     INTEGER NOT NULL DEFAULT 1 CHECK (servings > 0),
  minutes      INTEGER,
  tags         TEXT NOT NULL DEFAULT '',   -- comma-separated: 'dinner,vegan,quick'
  texture      TEXT CHECK (texture IN ('soft', 'pureed'))  -- NULL = regular
);

CREATE TABLE recipe_ingredients (
  recipe_id INTEGER NOT NULL REFERENCES recipes (id),
  food_id   INTEGER NOT NULL REFERENCES foods (id),
  grams     REAL NOT NULL CHECK (grams > 0),
  PRIMARY KEY (recipe_id, food_id)
);
-- "Recipes with this food" and the allergen filter look up by food.
CREATE INDEX recipe_ingredients_food ON recipe_ingredients (food_id);

-- Prepared / restaurant meals for camera logging. Either linked to a recipe
-- (nutrition computed from it) or with its own per-100 g values.
CREATE TABLE dishes (
  id        INTEGER PRIMARY KEY,
  name      TEXT NOT NULL,
  serving_g REAL NOT NULL CHECK (serving_g > 0),
  -- A recipe of the same name, to open and rate. Its nutrition is used only when the dish has none (kcal NULL).
  recipe_id INTEGER REFERENCES recipes (id),
  kcal      REAL,
  protein_g REAL,
  fat_g     REAL,
  carbs_g   REAL,
  fiber_g   REAL,
  sugar_g   REAL,
  sodium_mg REAL,
  -- Micronutrients per 100 g: the chain's label where it gives them, else the USDA FNDDS food in food_id.
  calcium_mg     REAL,
  iron_mg        REAL,
  magnesium_mg   REAL,
  potassium_mg   REAL,
  vitamin_c_mg   REAL,
  vitamin_d_ug   REAL,
  vitamin_b12_ug REAL,
  food_id   INTEGER REFERENCES foods (id),  -- the matching generic food (USDA FNDDS); NULL = none close enough
  CHECK (recipe_id IS NOT NULL OR kcal IS NOT NULL)
);

CREATE TABLE products (
  barcode   TEXT PRIMARY KEY,
  name      TEXT NOT NULL,
  kcal      REAL NOT NULL,
  protein_g REAL NOT NULL,
  fat_g     REAL NOT NULL,
  carbs_g   REAL NOT NULL,
  fiber_g   REAL,
  sugar_g   REAL,
  sodium_mg REAL,
  -- Micronutrients per 100 g from the package label (Open Food Facts); NULL = not on the label.
  calcium_mg     REAL,
  iron_mg        REAL,
  magnesium_mg   REAL,
  potassium_mg   REAL,
  vitamin_c_mg   REAL,
  vitamin_d_ug   REAL,
  vitamin_b12_ug REAL
);

-- Recipe ingredient names in the app's other languages (db/food_names.tsv, tool/food_names.py).
-- Machine-translated with TranslateGemma unless reviewed; no row = show foods.name.
CREATE TABLE food_names (
  food_id INTEGER NOT NULL REFERENCES foods (id),
  lang    TEXT NOT NULL,    -- 'uk', 'de', 'fr'
  name    TEXT NOT NULL,
  PRIMARY KEY (food_id, lang)
) WITHOUT ROWID;

CREATE TABLE allergens (
  food_id  INTEGER NOT NULL REFERENCES foods (id),
  allergen TEXT NOT NULL,   -- lowercase: 'peanuts', 'milk', 'gluten', ...
  PRIMARY KEY (food_id, allergen)
);

CREATE TABLE conditions (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE   -- 'diabetes_t2', 'hypertension', 'als', ...
);

CREATE TABLE condition_rules (
  condition_id INTEGER NOT NULL REFERENCES conditions (id),
  nutrient     TEXT NOT NULL CHECK (nutrient IN
    ('kcal', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g', 'sugar_g', 'sodium_mg')),
  max_per_day  REAL NOT NULL,
  note         TEXT,
  PRIMARY KEY (condition_id, nutrient)
);

-- Foods to avoid with a condition. Recipes containing one are never suggested
-- to a profile with that condition, exactly like allergens.
CREATE TABLE condition_avoid (
  condition_id INTEGER NOT NULL REFERENCES conditions (id),
  food_id      INTEGER NOT NULL REFERENCES foods (id),
  note         TEXT,
  PRIMARY KEY (condition_id, food_id)
);

CREATE TABLE docs (
  id        INTEGER PRIMARY KEY,
  source    TEXT NOT NULL,   -- citation shown to the user
  text      TEXT NOT NULL,
  embedding BLOB
);

-- Per-serving nutrition, the only place recipe numbers come from.
CREATE VIEW recipe_nutrition AS
SELECT r.id AS recipe_id,
       SUM(f.kcal      * ri.grams / 100) / r.servings AS kcal,
       SUM(f.protein_g * ri.grams / 100) / r.servings AS protein_g,
       SUM(f.fat_g     * ri.grams / 100) / r.servings AS fat_g,
       SUM(f.carbs_g   * ri.grams / 100) / r.servings AS carbs_g,
       SUM(f.fiber_g   * ri.grams / 100) / r.servings AS fiber_g,
       SUM(f.sugar_g   * ri.grams / 100) / r.servings AS sugar_g,
       SUM(f.sodium_mg * ri.grams / 100) / r.servings AS sodium_mg,
       -- Micronutrients: ingredients with unknown values add nothing, so these are at least values.
       SUM(f.calcium_mg * ri.grams / 100) / r.servings AS calcium_mg,
       SUM(f.iron_mg * ri.grams / 100) / r.servings AS iron_mg,
       SUM(f.magnesium_mg * ri.grams / 100) / r.servings AS magnesium_mg,
       SUM(f.potassium_mg * ri.grams / 100) / r.servings AS potassium_mg,
       SUM(f.vitamin_c_mg * ri.grams / 100) / r.servings AS vitamin_c_mg,
       SUM(f.vitamin_d_ug * ri.grams / 100) / r.servings AS vitamin_d_ug,
       SUM(f.vitamin_b12_ug * ri.grams / 100) / r.servings AS vitamin_b12_ug
FROM recipes r
JOIN recipe_ingredients ri ON ri.recipe_id = r.id
JOIN foods f ON f.id = ri.food_id
GROUP BY r.id;

-- Keyword search. External-content tables: the builder runs 'rebuild' after loading.
CREATE VIRTUAL TABLE foods_fts    USING fts5 (name, content = 'foods', content_rowid = 'id');
CREATE VIRTUAL TABLE recipes_fts  USING fts5 (title, tags, content = 'recipes', content_rowid = 'id');
CREATE VIRTUAL TABLE dishes_fts   USING fts5 (name, content = 'dishes', content_rowid = 'id');
CREATE VIRTUAL TABLE docs_fts     USING fts5 (text, content = 'docs', content_rowid = 'id');
CREATE VIRTUAL TABLE products_fts USING fts5 (name, barcode UNINDEXED, content = 'products');
