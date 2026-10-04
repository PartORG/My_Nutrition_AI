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
];

Database openUserDb(String path) {
  final db = sqlite3.open(path)..execute('PRAGMA foreign_keys = ON');
  migrate(db, userDbMigrations);
  return db;
}
