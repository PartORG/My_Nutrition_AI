import 'package:sqlite3/sqlite3.dart';

import 'migrate.dart';

/// `profiles/<id>/user.db` — one profile's private data. Append-only steps.
/// Times are unix milliseconds. Logged nutrition is a snapshot taken at log
/// time, so history never changes when nutri.db is replaced.
const userDbMigrations = <String>[
  // v1
  '''
  CREATE TABLE chat_messages (
    id         INTEGER PRIMARY KEY,
    role       TEXT NOT NULL CHECK (role IN ('user', 'model', 'tool')),
    text       TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );
  CREATE TABLE memory_facts (
    id            INTEGER PRIMARY KEY,
    text          TEXT NOT NULL,
    source_msg_id INTEGER REFERENCES chat_messages (id) ON DELETE SET NULL,
    created_at    INTEGER NOT NULL
  );
  CREATE TABLE user_allergens (
    allergen TEXT PRIMARY KEY,   -- lowercase, matches nutri.db allergens.allergen
    added_at INTEGER NOT NULL
  );
  CREATE TABLE saved_recipes (
    recipe_id INTEGER PRIMARY KEY,   -- nutri.db recipes.id (ids are stable across releases)
    title     TEXT NOT NULL,         -- kept so the list survives a removed recipe
    saved_at  INTEGER NOT NULL
  );
  CREATE TABLE meal_log (
    id          INTEGER PRIMARY KEY,
    eaten_at    INTEGER NOT NULL,
    meal_type   TEXT CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    description TEXT NOT NULL,
    grams       REAL,
    kcal        REAL NOT NULL,
    protein_g   REAL NOT NULL,
    fat_g       REAL NOT NULL,
    carbs_g     REAL NOT NULL,
    fiber_g     REAL,
    sugar_g     REAL,
    sodium_mg   REAL,
    estimated   INTEGER NOT NULL DEFAULT 0   -- 1 = show as ≈ (camera dish)
  );
  CREATE INDEX meal_log_eaten_at ON meal_log (eaten_at);
  CREATE TABLE symptoms (
    id        INTEGER PRIMARY KEY,
    logged_at INTEGER NOT NULL,
    symptom   TEXT NOT NULL,
    severity  INTEGER CHECK (severity BETWEEN 1 AND 5)
  );
  CREATE TABLE readings (
    id        INTEGER PRIMARY KEY,
    logged_at INTEGER NOT NULL,
    kind      TEXT NOT NULL CHECK (kind IN ('glucose', 'blood_pressure', 'weight')),
    value     REAL NOT NULL,   -- glucose, systolic, or weight
    value2    REAL,            -- diastolic
    unit      TEXT NOT NULL    -- 'mg/dL', 'mmol/L', 'mmHg', 'kg', 'lb'
  );
  ''',
  // v2 (M3): body data for goals, manual target overrides. Stored metric.
  '''
  CREATE TABLE body (
    id         INTEGER PRIMARY KEY CHECK (id = 1),
    sex        TEXT CHECK (sex IN ('female', 'male', 'other')),
    birth_year INTEGER,
    height_cm  REAL,
    weight_kg  REAL,
    activity   TEXT CHECK (activity IN ('sedentary', 'light', 'moderate', 'active', 'very_active')),
    goal       TEXT CHECK (goal IN ('lose', 'maintain', 'gain')),
    units      TEXT NOT NULL DEFAULT 'metric' CHECK (units IN ('metric', 'imperial')),
    updated_at INTEGER NOT NULL
  );
  CREATE TABLE goal_overrides (
    nutrient TEXT PRIMARY KEY CHECK (nutrient IN
      ('kcal', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g', 'sugar_g', 'sodium_mg')),
    value    REAL NOT NULL CHECK (value > 0)
  );
  ''',
  // v3 (M3): reminders the user turned on; no row = off, at the suggested time.
  '''
  CREATE TABLE reminders (
    slot    TEXT PRIMARY KEY CHECK (slot IN ('breakfast', 'lunch', 'dinner', 'evening')),
    enabled INTEGER NOT NULL,
    hour    INTEGER NOT NULL CHECK (hour BETWEEN 0 AND 23),
    minute  INTEGER NOT NULL CHECK (minute BETWEEN 0 AND 59)
  );
  ''',
  // v4 (M5): the profile's conditions (nutri.db conditions.id; name kept like saved_recipes.title).
  '''
  CREATE TABLE user_conditions (
    condition_id INTEGER PRIMARY KEY,
    name         TEXT NOT NULL,
    added_at     INTEGER NOT NULL
  );
  ''',
  // v5 (M6): camera scans as one-line texts for episodic memory. Photos are never stored.
  '''
  CREATE TABLE scans (
    id         INTEGER PRIMARY KEY,
    scanned_at INTEGER NOT NULL,
    mode       TEXT NOT NULL CHECK (mode IN ('photo', 'live', 'barcode')),
    text       TEXT NOT NULL   -- what the user kept on the review screen: 'banana, broccoli'
  );
  ''',
  // v6: which recipe a logged meal was (to open it again), and the user's 1-5 stars,
  // which recipe search uses (2 or fewer = never suggested again).
  '''
  ALTER TABLE meal_log ADD COLUMN recipe_id INTEGER;   -- nutri.db recipes.id; NULL = not a recipe
  CREATE TABLE recipe_ratings (
    recipe_id INTEGER PRIMARY KEY,
    stars     INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
    rated_at  INTEGER NOT NULL
  );
  ''',
  // v7: water, fasting, and per-profile preferences (water goal, fasting on).
  '''
  CREATE TABLE water_log (
    id       INTEGER PRIMARY KEY,
    drunk_at INTEGER NOT NULL,
    ml       REAL NOT NULL CHECK (ml > 0 AND ml <= 5000)
  );
  CREATE INDEX water_log_drunk_at ON water_log (drunk_at);
  CREATE TABLE fasts (
    id           INTEGER PRIMARY KEY,
    started_at   INTEGER NOT NULL,
    ended_at     INTEGER,           -- NULL = running
    target_hours INTEGER NOT NULL CHECK (target_hours BETWEEN 8 AND 72)
  );
  CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  ''',
];

Database openUserDb(String path) {
  final db = sqlite3.open(path)..execute('PRAGMA foreign_keys = ON');
  migrate(db, userDbMigrations);
  return db;
}
