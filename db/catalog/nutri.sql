-- nutri.db, catalogue v4 (docs/PLAN.md "Catalogue v4"): generic foods and recipes. Bundled, read-only on the phone,
-- replaced as a whole file. Built by tool/catalog (write stage).
--
-- Rules:
--  * Nutrients per 100 g (recipe_nutrition: per serving). NULL = unknown, never 0 for unknown.
--  * The NUTRIENTS marker expands to one REAL column per row of db/catalog/nutrients.tsv, in its order
--    (tool/catalog/schema.py).
--  * `borrowed` / `estimated`: comma-separated nutrient keys whose value was not measured for this row
--    (borrowed = the same food in another table; estimated = from similar foods). The rest are measured.
--  * ids are new in v4 and stable from here on: a rebuild keeps the id of a row from the same source code.

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,   -- schema_version (4), data_version, built_at, embedding_model
  value TEXT NOT NULL
);

-- Every dataset a row comes from, with what its licence allows (DATA_SOURCES.md has the per-file report).
CREATE TABLE sources (
  id            TEXT PRIMARY KEY,   -- 'usda_sr28', 'ciqual', 'cnf', 'foodcom', ...
  name          TEXT NOT NULL,
  licence       TEXT NOT NULL,      -- 'public domain', 'CC BY 4.0', 'scraped (owner exception)', ...
  url           TEXT,
  authoritative INTEGER NOT NULL DEFAULT 0   -- 1 = a government food composition table
);

CREATE TABLE foods (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,          -- as the source names it, tidied: "Bananas, raw"
  common_name TEXT NOT NULL,          -- the everyday name, lower case: "banana"
  is_default  INTEGER NOT NULL DEFAULT 0,  -- 1 = the plain form people mean by common_name (one per common_name)
  category    TEXT NOT NULL DEFAULT 'food' CHECK (category IN ('food', 'dish')),
  state       TEXT,                   -- 'raw', 'cooked', 'dried', 'canned', ...; NULL = not stated
  source_id   TEXT NOT NULL REFERENCES sources (id),
  source_code TEXT,                   -- the row's id in its source (USDA NDB number, CIQUAL code, ...)
  serving_g   REAL,                   -- one typical piece / portion ("2 eggs" = 2 × serving_g); NULL = unknown
  serving     TEXT,                   -- what serving_g is: "1 medium (118 g)"
  /*NUTRIENTS*/,
  borrowed    TEXT NOT NULL DEFAULT '',
  estimated   TEXT NOT NULL DEFAULT ''
);
CREATE INDEX foods_common ON foods (common_name, is_default DESC);
CREATE UNIQUE INDEX foods_one_default ON foods (common_name) WHERE is_default = 1;

-- What people call a food, in the app's languages: "banana", "bananas", "банан", "Banane" → the default banana.
-- Replaces v3's food_names and the app's staples map.
CREATE TABLE food_aliases (
  alias   TEXT NOT NULL COLLATE NOCASE,
  lang    TEXT NOT NULL CHECK (lang IN ('en', 'uk', 'de', 'fr')),
  food_id INTEGER NOT NULL REFERENCES foods (id),
  PRIMARY KEY (alias, lang, food_id)
) WITHOUT ROWID;

-- A food's name in another language: the translation of its everyday name (the default's alias in that language),
-- so "Butter, salted" in a recipe shows as the Ukrainian for "butter". One per food and language.
CREATE VIEW food_names AS
SELECT f.id AS food_id, a.lang, MIN(a.alias) AS name
FROM foods f
JOIN foods d ON d.common_name = f.common_name AND d.is_default = 1
JOIN food_aliases a ON a.food_id = d.id AND a.lang != 'en'
GROUP BY f.id, a.lang;

CREATE TABLE food_allergens (
  food_id  INTEGER NOT NULL REFERENCES foods (id),
  allergen TEXT NOT NULL,             -- lower case: 'peanuts', 'milk', 'gluten', ...
  PRIMARY KEY (food_id, allergen)
) WITHOUT ROWID;
CREATE INDEX food_allergens_allergen ON food_allergens (allergen);

CREATE TABLE recipes (
  id            INTEGER PRIMARY KEY,
  lang          TEXT NOT NULL DEFAULT 'en',   -- the language it was written in
  title         TEXT NOT NULL,                -- as written
  title_en      TEXT NOT NULL,                -- = title for English recipes
  servings      INTEGER NOT NULL CHECK (servings > 0),
  serving_g     REAL,                         -- weight of one serving as cooked, when the source gives it
  minutes       INTEGER,
  texture       TEXT CHECK (texture IN ('soft', 'pureed')),  -- NULL = regular
  rating        REAL,                         -- the source's average stars, 0-5
  reviews       INTEGER,
  published_kcal REAL,                        -- the source's kcal per serving, kept to check ours
  source_id     TEXT NOT NULL REFERENCES sources (id),
  url           TEXT
);

-- One row per line of the recipe, in order: a food may appear twice ("butter" for the dough and for the pan).
-- food_id NULL: a line shown but left out of nutrition ("water", "salt to taste").
CREATE TABLE recipe_ingredients (
  id        INTEGER PRIMARY KEY,
  recipe_id INTEGER NOT NULL REFERENCES recipes (id),
  position  INTEGER NOT NULL,
  food_id   INTEGER REFERENCES foods (id),
  grams     REAL NOT NULL CHECK (grams >= 0),   -- 0: "salt to taste" and similar
  line      TEXT NOT NULL,                      -- as written: "2 large eggs, beaten"
  line_en   TEXT,                               -- NULL = line is English
  UNIQUE (recipe_id, position)
);
CREATE INDEX recipe_ingredients_food ON recipe_ingredients (food_id);

CREATE TABLE recipe_steps (
  recipe_id INTEGER NOT NULL REFERENCES recipes (id),
  position  INTEGER NOT NULL,
  text      TEXT NOT NULL,
  text_en   TEXT,                               -- NULL = text is English
  PRIMARY KEY (recipe_id, position)
) WITHOUT ROWID;

-- Fixed tags only (tool/catalog: TAGS): meals ('breakfast', 'lunch', 'dinner', 'snack', 'dessert', 'drink'),
-- diets ('vegan', 'vegetarian', 'pescatarian', 'gluten-free', 'dairy-free'), 'quick', 'high-protein', cuisines.
CREATE TABLE recipe_tags (
  recipe_id INTEGER NOT NULL REFERENCES recipes (id),
  tag       TEXT NOT NULL,
  PRIMARY KEY (tag, recipe_id)
) WITHOUT ROWID;
CREATE INDEX recipe_tags_recipe ON recipe_tags (recipe_id);  -- a recipe's tags (recipe_info) without a full scan

-- Per serving, from the ingredient lines and the foods. Built as a view; write.py stores it as a table (~140 MB).
-- known: per nutrient, how many lines with a food and grams > 0 had a value, as "key:n/m" pairs ("iodine_ug:7/9");
-- a nutrient every line knows is left out. The RECIPE_NUTRITION marker expands to the view (tool/catalog/schema.py).
/*RECIPE_NUTRITION*/;

-- A recipe as the app shows it: its steps as numbered lines (one step: just its text), its tags comma-separated.
CREATE VIEW recipe_info AS
SELECT r.*,
       (SELECT CASE WHEN count(*) = 1 THEN max(COALESCE(s.text_en, s.text))
                    ELSE group_concat(s.position || '. ' || COALESCE(s.text_en, s.text), char(10)) END
          FROM (SELECT * FROM recipe_steps WHERE recipe_id = r.id ORDER BY position) s) AS instructions,
       (SELECT group_concat(tag, ',') FROM recipe_tags WHERE recipe_id = r.id) AS tags
FROM recipes r;

-- Keyword search. External-content tables: the builder runs 'rebuild' after loading.
CREATE VIRTUAL TABLE foods_fts   USING fts5 (name, common_name, content = 'foods', content_rowid = 'id');
-- Recipes by title and tag ("vegan dinner"): indexed from the recipe_info view, which joins the tags.
CREATE VIRTUAL TABLE recipes_fts USING fts5 (title, tags, content = 'recipe_info', content_rowid = 'id');
