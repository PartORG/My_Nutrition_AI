-- health.db, catalogue v4 (docs/PLAN.md "Catalogue v4", decisions 6 and 16): reference intakes, condition rules and
-- quoted health passages. Bundled, read-only on the phone, built by tool/catalog with nutri.db (food ids refer to
-- that nutri.db build; meta.nutri_built_at must match nutri.db's built_at).
--
-- Rules:
--  * Every row names its source; nothing is generated. Passages are quoted as published, never rewritten.
--  * Condition rules are advisory: the app warns and the assistant mentions them, nothing is blocked.
--  * nutrient columns hold a key of db/catalog/nutrients.tsv.

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,   -- schema_version (1), built_at, nutri_built_at, embedding_model
  value TEXT NOT NULL
);

CREATE TABLE sources (
  id      TEXT PRIMARY KEY,   -- 'nasem_dri', 'efsa_drv', 'who', 'nih_ods', 'medquad', ...
  name    TEXT NOT NULL,
  licence TEXT NOT NULL,
  url     TEXT
);

-- Daily intakes per person: the user's own row replaces the app's fixed targets.
CREATE TABLE reference_values (
  nutrient   TEXT NOT NULL,
  sex        TEXT NOT NULL CHECK (sex IN ('female', 'male', 'any')),
  age_from   REAL NOT NULL,        -- years, inclusive (0.5 = 6 months)
  age_to     REAL NOT NULL,        -- years, exclusive
  life_stage TEXT NOT NULL DEFAULT '' CHECK (life_stage IN ('', 'pregnancy', 'lactation')),
  kind       TEXT NOT NULL CHECK (kind IN ('rda', 'ai', 'ul', 'amdr_min', 'amdr_max')),  -- amdr: % of energy
  amount     REAL NOT NULL,        -- in the nutrient's unit (amdr: percent)
  source_id  TEXT NOT NULL REFERENCES sources (id),
  PRIMARY KEY (nutrient, sex, age_from, life_stage, kind, source_id)
) WITHOUT ROWID;

CREATE TABLE conditions (
  id        INTEGER PRIMARY KEY,
  key       TEXT NOT NULL UNIQUE,  -- 'diabetes_t2', 'hypertension', 'celiac', 'ckd', 'pregnancy', ...
  name      TEXT NOT NULL,
  summary   TEXT NOT NULL,         -- one quoted sentence for the conditions screen
  source_id TEXT NOT NULL REFERENCES sources (id)
);

CREATE TABLE condition_rules (
  condition_id INTEGER NOT NULL REFERENCES conditions (id),
  nutrient     TEXT NOT NULL,
  min_per_day  REAL,               -- NULL = no lower limit
  max_per_day  REAL,               -- NULL = no upper limit
  note         TEXT,
  source_id    TEXT NOT NULL REFERENCES sources (id),
  CHECK (min_per_day IS NOT NULL OR max_per_day IS NOT NULL),
  PRIMARY KEY (condition_id, nutrient)
) WITHOUT ROWID;

-- avoid: never in suggestions or plans (like an allergen); limit: shown with a note; prefer: a small boost in ideas.
CREATE TABLE condition_foods (
  condition_id INTEGER NOT NULL REFERENCES conditions (id),
  food_id      INTEGER NOT NULL,   -- nutri.db foods.id
  effect       TEXT NOT NULL CHECK (effect IN ('avoid', 'limit', 'prefer')),
  note         TEXT,
  source_id    TEXT NOT NULL REFERENCES sources (id),
  PRIMARY KEY (condition_id, food_id)
) WITHOUT ROWID;

-- Guideline passages and Q&A answers, quoted with their source; condition_info answers from these.
CREATE TABLE docs (
  id           INTEGER PRIMARY KEY,
  kind         TEXT NOT NULL CHECK (kind IN ('guideline', 'qa')),
  condition_id INTEGER REFERENCES conditions (id),   -- NULL = general
  question     TEXT,                                 -- qa only
  text         TEXT NOT NULL,                        -- as published, ≤ 512 tokens per chunk
  source_id    TEXT NOT NULL REFERENCES sources (id),
  url          TEXT
);

-- meta.embedding_model, prefix 'title: none | text: ', float32 little-endian × 768.
-- shortcut: float32 is ~3 KB a doc (~150 MB for 50k); quantize to int8 if health.db + nutri.db pass 500 MB.
CREATE TABLE doc_embeddings (
  doc_id    INTEGER PRIMARY KEY REFERENCES docs (id),
  embedding BLOB NOT NULL
);

CREATE VIRTUAL TABLE docs_fts USING fts5 (question, text, content = 'docs', content_rowid = 'id');
